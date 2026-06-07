/*  ================================================================
    ALL remaining regressions: pooled 1982+1990+2000
    1. Historical controls (one-by-one)
    2. Long March / Korean War robustness
    3. Heterogeneity: gender, base education, clan, treaty port
    4. Illiteracy
    5. Completion rates (primary, junior high)
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")
global outdir "${proj}/paper/assets/tables"

*--------------------------------------------------------------
* county dictionary + crosswalk (same as before)
*--------------------------------------------------------------
import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
keep GBCounty
destring GBCounty, replace force
drop if missing(GBCounty)
gen str6 county_curr6 = string(GBCounty, "%06.0f")
gen str6 old6 = county_curr6
gen str6 curr_dict = county_curr6
keep old6 curr_dict
duplicates drop old6, force
tempfile county_dict
save `county_dict'
global county_dict_tmp "`county_dict'"

import delimited "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", clear varnames(1) stringcols(_all)
rename countyid_old6 old6
rename countyid_curr6_final county_curr6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = subinstr(county_curr6, ".0", "", .)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6 route_final
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'
global cw1982_tmp "`cw1982'"

capture program drop _resolve_old6_map
program define _resolve_old6_map
    gen str6 county_curr6 = ""
    gen str30 route = "unmatched"
    replace county_curr6 = "310101" if old6=="310103"
    replace route = "manual_successor" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace route = "manual_successor" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace route = "manual_successor" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"
    replace route = "manual_successor" if old6=="110010"
    tempfile left
    save `left'
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6 route_final)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    replace route = "crosswalk_1982" if county_curr6!="" & route=="unmatched"
    drop county_curr6 route_final
    rename curr_res county_curr6
    save `left', replace
    use `left', clear
    rename county_curr6 curr_res
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace curr_res = curr_dict if curr_res=="" & curr_dict!=""
    replace route = "exact_code" if curr_dict!="" & route=="unmatched"
    drop curr_dict
    rename curr_res county_curr6
    gen str6 muni6 = substr(old6,1,2) + "01" + substr(old6,5,2) ///
        if inlist(substr(old6,1,2),"11","12","31") & substr(old6,3,2)=="00" & county_curr6==""
    tempfile muni_exact
    tempfile muni_cw
    preserve
        keep old6
        keep if 0
        gen str6 curr_from_muni_exact = ""
        save `muni_exact', replace
    restore
    preserve
        keep old6
        keep if 0
        gen str6 curr_from_muni_cw = ""
        save `muni_cw', replace
    restore
    preserve
        keep if muni6!="" & county_curr6==""
        count
        if r(N)>0 {
            keep old6 muni6
            rename muni6 old6_muni
            rename old6 old6_orig
            rename old6_muni old6
            merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
            keep if curr_dict!=""
            drop old6
            rename old6_orig old6
            rename curr_dict curr_from_muni_exact
            keep old6 curr_from_muni_exact
            save `muni_exact', replace
        }
    restore
    merge 1:1 old6 using `muni_exact', keep(master match) nogen
    replace county_curr6 = curr_from_muni_exact if county_curr6=="" & curr_from_muni_exact!=""
    replace route = "municipality_geo3_recode" if county_curr6==curr_from_muni_exact & curr_from_muni_exact!=""
    drop curr_from_muni_exact
    preserve
        keep if muni6!="" & county_curr6==""
        count
        if r(N)>0 {
            keep old6 muni6
            rename muni6 old6_muni
            rename old6 old6_orig
            rename old6_muni old6
            merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
            keep if county_curr6!=""
            drop old6
            rename old6_orig old6
            rename county_curr6 curr_from_muni_cw
            keep old6 curr_from_muni_cw
            save `muni_cw', replace
        }
    restore
    merge 1:1 old6 using `muni_cw', keep(master match) nogen
    replace county_curr6 = curr_from_muni_cw if county_curr6=="" & curr_from_muni_cw!=""
    replace route = "municipality_then_crosswalk_1982" if county_curr6==curr_from_muni_cw & curr_from_muni_cw!=""
    drop curr_from_muni_cw muni6
end

*--------------------------------------------------------------
* treatment
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw pop_1953

gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)

rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force

/* merge historical controls */
rename county_curr6 countyid_curr6
capture {
    merge 1:1 countyid_curr6 using "${proj}/data/temp/county_controls_full_v1.dta", keep(master match) nogen
}
capture {
    merge 1:1 countyid_curr6 using "${proj}/data/temp/revolutionary_proxy_controls_v1.dta", keep(master match) nogen
}

/* generate ln versions from raw variables */
gen ln_victims_cr = ln(1 + victims_cr) if !missing(victims_cr)
gen ln_grain_output = ln(1 + grain_output) if !missing(grain_output)

/* fill missing controls with 0 for robustness */
foreach v in sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 ln_longmarch_martyr_count ln_korea_war_martyr_count {
    capture replace `v' = 0 if missing(`v')
}

tempfile treat
save `treat'
global treat_tmp "`treat'"

*--------------------------------------------------------------
* mapping 1990/2000
*--------------------------------------------------------------
use county age_c age educ using "$c1990", clear
drop if missing(county)
gen str6 old6 = string(county, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map1990
save `map1990'
global map1990_tmp "`map1990'"

use uid birthyr eduyr using "$c2000", clear
drop if missing(uid)
gen str6 old6 = string(uid, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map2000
save `map2000'
global map2000_tmp "`map2000'"

*==============================================================
*  Load each wave (with sex where available)
*==============================================================
/* 1982: try to load sex */
capture confirm variable sex using "$c1982"
local has_sex_1982 = _rc == 0

use countyid birthyr eduy ethniccn using "$c1982", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen minority = (ethniccn != 1) if !missing(ethniccn)
gen male = .   /* 1982 mainvars may not have sex */
keep if inrange(birthyr, 1920, 1956)
rename county_curr6 countyid_curr6
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 1
tempfile w1982
save `w1982'

/* Load from raw 1990 file to get sex variable */
use county age_c age educ race sex using "${proj}/data/raw/census/census1990.dta", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birthyr = 1000 + age_c*100 + age
gen eduy = .
replace eduy = 0  if educ==1
replace eduy = 6  if educ==2
replace eduy = 9  if educ==3
replace eduy = 12 if inlist(educ,4,5)
replace eduy = 15 if educ==6
replace eduy = 16 if educ==7
gen minority = (race != 1) if !missing(race)
gen male = (sex == 1) if !missing(sex)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 2
tempfile w1990
save `w1990'

/* Load from raw 2000 file to get sex variable */
use uid birthyr eduyr race sex using "${proj}/data/raw/census/census2000.dta", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
gen male = (sex == 1) if !missing(sex)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 3
tempfile w2000
save `w2000'

*==============================================================
*  Pool & winsorize
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'

summ eduy, detail
scalar p1 = r(p1)
scalar p99 = r(p99)
replace eduy = p1 if eduy < p1
replace eduy = p99 if eduy > p99 & !missing(eduy)

encode countyid_curr6, gen(county_num)

/* cohort cell size */
bysort county_num birth_i wave: gen cohort_n = _N
gen ln_cohort_n = ln(cohort_n)

/* derived outcomes */
gen illiterate = (eduy == 0)
gen primary_complete = (eduy >= 6) if !missing(eduy)
gen juniorhigh_complete = (eduy >= 9) if !missing(eduy)

/* post indicators */
gen post1940 = (birth_i >= 1940)
gen drop1939 = (birth_i == 1939)
gen post1946 = (birth_i >= 1946)
gen drop1945 = (birth_i == 1945)

di "=== POOLED N = " _N " ==="

*--------------------------------------------------------------
* Stars helper
*--------------------------------------------------------------
capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*##############################################################
*  PART 1: HISTORICAL CONTROLS (one-by-one), cutoff 1940
*  Main treatment: IHS(rate)
*##############################################################
di ""
di "========================================"
di "  PART 1: Historical Controls"
di "========================================"

local controls "sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64"
local clabels `" "SDY density" "Famine" "CR victims" "Grain output" "Urban ratio" "'

/* baseline */
di "=== Baseline (no historical controls) ==="
reghdfejl eduy c.ihs_rate##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_base = _b[1.post1940#c.ihs_rate]
local se_base = _se[1.post1940#c.ihs_rate]
local p_base = 2*ttail(e(df_r), abs(`b_base'/`se_base'))
local n_base = e(N)

local col = 1
foreach ctrl of local controls {
    local col = `col' + 1
    di "=== + `ctrl' ==="
    reghdfejl eduy c.ihs_rate##ib0.post1940 c.`ctrl'##ib0.post1940 minority i.wave if !drop1939, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_`col' = _b[1.post1940#c.ihs_rate]
    local se_`col' = _se[1.post1940#c.ihs_rate]
    local p_`col' = 2*ttail(e(df_r), abs(`b_`col''/`se_`col''))
    local n_`col' = e(N)
    di "  beta=" %8.4f `b_`col'' "  se=" %8.4f `se_`col'' "  p=" %6.4f `p_`col''
}

/* all five */
di "=== + All five controls ==="
reghdfejl eduy c.ihs_rate##ib0.post1940 ///
    c.sdy_density##ib0.post1940 c.ins_famine##ib0.post1940 ///
    c.ln_victims_cr##ib0.post1940 c.ln_grain_output##ib0.post1940 ///
    c.urbanratio64##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_all5 = _b[1.post1940#c.ihs_rate]
local se_all5 = _se[1.post1940#c.ihs_rate]
local p_all5 = 2*ttail(e(df_r), abs(`b_all5'/`se_all5'))
local n_all5 = e(N)
di "  beta=" %8.4f `b_all5' "  se=" %8.4f `se_all5' "  p=" %6.4f `p_all5'

/* Output historical controls table */
_stars `p_base'
local s_base "`r(star)'"
tempname fh
file open `fh' using "${outdir}/pooled_historical_controls_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{7}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}\\" _n
file write `fh' "            &Baseline&+SDY&+Famine&+CR victims&+Grain&+Urban&+All five\\" _n
file write `fh' "\midrule" _n
file write `fh' "Post $\times$ IHS(rate)&" %10.4f (`b_base') "\sym{`s_base'}"
local col = 1
foreach ctrl of local controls {
    local col = `col' + 1
    _stars `p_`col''
    file write `fh' "&" %10.4f (`b_`col'') "\sym{`r(star)'}"
}
_stars `p_all5'
file write `fh' "&" %10.4f (`b_all5') "\sym{`r(star)'}\\" _n
file write `fh' "            &(" %7.4f (`se_base') ")"
local col = 1
foreach ctrl of local controls {
    local col = `col' + 1
    file write `fh' "&(" %7.4f (`se_`col'') ")"
}
file write `fh' "&(" %7.4f (`se_all5') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Historical control&None&SDY density&Famine&CR victims&Grain output&Urban ratio&All five\\" _n
file write `fh' "Observations&" %12.0fc (`n_base')
local col = 1
foreach ctrl of local controls {
    local col = `col' + 1
    file write `fh' "&" %12.0fc (`n_`col'')
}
file write `fh' "&" %12.0fc (`n_all5') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Historical controls table saved ==="

*##############################################################
*  PART 2: LONG MARCH + KOREAN WAR ROBUSTNESS
*##############################################################
di ""
di "========================================"
di "  PART 2: Long March / Korean War"
di "========================================"

/* (1) baseline */
di "=== LM/Korea: Baseline ==="
reghdfejl eduy c.ihs_rate##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_lm1 = _b[1.post1940#c.ihs_rate]
local se_lm1 = _se[1.post1940#c.ihs_rate]
local p_lm1 = 2*ttail(e(df_r), abs(`b_lm1'/`se_lm1'))
local n_lm1 = e(N)

/* (2) + Long March */
di "=== + Long March ==="
reghdfejl eduy c.ihs_rate##ib0.post1940 c.ln_longmarch_martyr_count##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_lm2 = _b[1.post1940#c.ihs_rate]
local se_lm2 = _se[1.post1940#c.ihs_rate]
local p_lm2 = 2*ttail(e(df_r), abs(`b_lm2'/`se_lm2'))
local n_lm2 = e(N)

/* (3) + Korean War */
di "=== + Korean War ==="
reghdfejl eduy c.ihs_rate##ib0.post1940 c.ln_korea_war_martyr_count##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_lm3 = _b[1.post1940#c.ihs_rate]
local se_lm3 = _se[1.post1940#c.ihs_rate]
local p_lm3 = 2*ttail(e(df_r), abs(`b_lm3'/`se_lm3'))
local n_lm3 = e(N)

/* (4) + Both */
di "=== + Both ==="
reghdfejl eduy c.ihs_rate##ib0.post1940 c.ln_longmarch_martyr_count##ib0.post1940 ///
    c.ln_korea_war_martyr_count##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_lm4 = _b[1.post1940#c.ihs_rate]
local se_lm4 = _se[1.post1940#c.ihs_rate]
local p_lm4 = 2*ttail(e(df_r), abs(`b_lm4'/`se_lm4'))
local n_lm4 = e(N)

di "Results: base=" %8.4f `b_lm1' "  +LM=" %8.4f `b_lm2' "  +Korea=" %8.4f `b_lm3' "  +Both=" %8.4f `b_lm4'

/* Output table */
tempname fh
file open `fh' using "${outdir}/pooled_longmarch_korea_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}\\" _n
file write `fh' "            &Baseline&+Long March&+Korean War&+Both\\" _n
file write `fh' "\midrule" _n
forvalues j = 1/4 {
    _stars `p_lm`j''
    local s`j' "`r(star)'"
}
file write `fh' "Post $\times$ IHS(rate)&" %10.4f (`b_lm1') "\sym{`s1'}&" %10.4f (`b_lm2') "\sym{`s2'}&" %10.4f (`b_lm3') "\sym{`s3'}&" %10.4f (`b_lm4') "\sym{`s4'}\\" _n
file write `fh' "            &(" %7.4f (`se_lm1') ")&(" %7.4f (`se_lm2') ")&(" %7.4f (`se_lm3') ")&(" %7.4f (`se_lm4') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Long March control&            &     Yes         &            &     Yes         \\" _n
file write `fh' "Korean War control&            &            &     Yes         &     Yes         \\" _n
file write `fh' "Observations&" %12.0fc (`n_lm1') "&" %12.0fc (`n_lm2') "&" %12.0fc (`n_lm3') "&" %12.0fc (`n_lm4') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Long March/Korea table saved ==="

*##############################################################
*  PART 3: COMPLETION RATES + ILLITERACY (pooled)
*##############################################################
di ""
di "========================================"
di "  PART 3: Completion & Illiteracy"
di "========================================"

foreach outcome in primary_complete juniorhigh_complete illiterate {
    foreach cutoff in 1940 1946 {
        local dropyr = `cutoff' - 1
        local postvar "post`cutoff'"
        local dropvar "drop`dropyr'"

        /* IHS rate */
        di "=== `outcome', cutoff `cutoff', IHS rate ==="
        reghdfejl `outcome' c.ihs_rate##ib0.`postvar' minority i.wave if !`dropvar', ///
            absorb(county_num birth_i) vce(cluster county_num)
        local b_`outcome'_ihs_`cutoff' = _b[1.`postvar'#c.ihs_rate]
        local se_`outcome'_ihs_`cutoff' = _se[1.`postvar'#c.ihs_rate]
        local p_`outcome'_ihs_`cutoff' = 2*ttail(e(df_r), abs(`b_`outcome'_ihs_`cutoff''/`se_`outcome'_ihs_`cutoff''))
        local n_`outcome'_ihs_`cutoff' = e(N)

        /* Dummy count */
        di "=== `outcome', cutoff `cutoff', dummy ==="
        reghdfejl `outcome' i.d_count_high##ib0.`postvar' minority i.wave if !`dropvar', ///
            absorb(county_num birth_i) vce(cluster county_num)
        local b_`outcome'_dum_`cutoff' = _b[1.d_count_high#1.`postvar']
        local se_`outcome'_dum_`cutoff' = _se[1.d_count_high#1.`postvar']
        local p_`outcome'_dum_`cutoff' = 2*ttail(e(df_r), abs(`b_`outcome'_dum_`cutoff''/`se_`outcome'_dum_`cutoff''))
        local n_`outcome'_dum_`cutoff' = e(N)

        di "  IHS: b=" %8.5f `b_`outcome'_ihs_`cutoff'' " p=" %6.4f `p_`outcome'_ihs_`cutoff''
        di "  Dum: b=" %8.5f `b_`outcome'_dum_`cutoff'' " p=" %6.4f `p_`outcome'_dum_`cutoff''
    }
}

/* Output completion & illiteracy table */
tempname fh
file open `fh' using "${outdir}/pooled_completion_illiteracy_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{Cutoff 1940}&\multicolumn{2}{c}{Cutoff 1946}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &Dummy&IHS(rate)&Dummy&IHS(rate)\\" _n
file write `fh' "\midrule" _n

foreach outcome in primary_complete juniorhigh_complete illiterate {
    if "`outcome'" == "primary_complete"    local olabel "Primary completion ($\geq$6 yrs)"
    if "`outcome'" == "juniorhigh_complete" local olabel "Junior high completion ($\geq$9 yrs)"
    if "`outcome'" == "illiterate"          local olabel "Illiteracy (0 yrs)"

    foreach cutoff in 1940 1946 {
        _stars `p_`outcome'_dum_`cutoff''
        local sd_`cutoff' "`r(star)'"
        _stars `p_`outcome'_ihs_`cutoff''
        local si_`cutoff' "`r(star)'"
    }

    file write `fh' "`olabel'&" ///
        %10.4f (`b_`outcome'_dum_1940') "\sym{`sd_1940'}&" ///
        %10.5f (`b_`outcome'_ihs_1940') "\sym{`si_1940'}&" ///
        %10.4f (`b_`outcome'_dum_1946') "\sym{`sd_1946'}&" ///
        %10.5f (`b_`outcome'_ihs_1946') "\sym{`si_1946'}\\" _n
    file write `fh' "            &(" %7.4f (`se_`outcome'_dum_1940') ")&(" %7.5f (`se_`outcome'_ihs_1940') ")&(" %7.4f (`se_`outcome'_dum_1946') ")&(" %7.5f (`se_`outcome'_ihs_1946') ")\\" _n
}

file write `fh' "\midrule" _n
file write `fh' "Observations&" %12.0fc (`n_primary_complete_dum_1940') "&" %12.0fc (`n_primary_complete_ihs_1940') "&" %12.0fc (`n_primary_complete_dum_1946') "&" %12.0fc (`n_primary_complete_ihs_1946') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Completion/Illiteracy table saved ==="

*##############################################################
*  PART 4: HETEROGENEITY - gender (1990+2000 only)
*##############################################################
di ""
di "========================================"
di "  PART 4: Gender Heterogeneity"
di "========================================"

foreach gen in 0 1 {
    if `gen' == 0 local glabel "Female"
    if `gen' == 1 local glabel "Male"

    di "=== Gender: `glabel', IHS rate, cutoff 1940 ==="
    reghdfejl eduy c.ihs_rate##ib0.post1940 minority i.wave if !drop1939 & male == `gen', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_g`gen'_ihs = _b[1.post1940#c.ihs_rate]
    local se_g`gen'_ihs = _se[1.post1940#c.ihs_rate]
    local p_g`gen'_ihs = 2*ttail(e(df_r), abs(`b_g`gen'_ihs'/`se_g`gen'_ihs'))
    local n_g`gen'_ihs = e(N)

    di "=== Gender: `glabel', Dummy, cutoff 1940 ==="
    reghdfejl eduy i.d_count_high##ib0.post1940 minority i.wave if !drop1939 & male == `gen', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_g`gen'_dum = _b[1.d_count_high#1.post1940]
    local se_g`gen'_dum = _se[1.d_count_high#1.post1940]
    local p_g`gen'_dum = 2*ttail(e(df_r), abs(`b_g`gen'_dum'/`se_g`gen'_dum'))
    local n_g`gen'_dum = e(N)

    di "  IHS: b=" %8.4f `b_g`gen'_ihs' " p=" %6.4f `p_g`gen'_ihs' " N=" `n_g`gen'_ihs'
    di "  Dum: b=" %8.4f `b_g`gen'_dum' " p=" %6.4f `p_g`gen'_dum' " N=" `n_g`gen'_dum'
}

/* Output gender table */
tempname fh
file open `fh' using "${outdir}/pooled_heterogeneity_gender_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{Female}&\multicolumn{2}{c}{Male}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &Dummy&IHS(rate)&Dummy&IHS(rate)\\" _n
file write `fh' "\midrule" _n
forvalues g = 0/1 {
    _stars `p_g`g'_dum'
    local sd`g' "`r(star)'"
    _stars `p_g`g'_ihs'
    local si`g' "`r(star)'"
}
file write `fh' "Post $\times$ Treatment&" ///
    %10.4f (`b_g0_dum') "\sym{`sd0'}&" %10.4f (`b_g0_ihs') "\sym{`si0'}&" ///
    %10.4f (`b_g1_dum') "\sym{`sd1'}&" %10.4f (`b_g1_ihs') "\sym{`si1'}\\" _n
file write `fh' "            &(" %7.4f (`se_g0_dum') ")&(" %7.4f (`se_g0_ihs') ")&(" %7.4f (`se_g1_dum') ")&(" %7.4f (`se_g1_ihs') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Observations&" %12.0fc (`n_g0_dum') "&" %12.0fc (`n_g0_ihs') "&" %12.0fc (`n_g1_dum') "&" %12.0fc (`n_g1_ihs') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Gender heterogeneity table saved ==="

*##############################################################
*  PART 5: Heterogeneity by base education (median split)
*##############################################################
di ""
di "========================================"
di "  PART 5: Base Education Heterogeneity"
di "========================================"

/* compute county-level pre-war education */
preserve
    keep if birth_i < 1940
    collapse (mean) pre_edu = eduy, by(countyid_curr6)
    summ pre_edu, detail
    gen high_base_edu = (pre_edu > r(p50))
    tempfile base_edu
    save `base_edu'
restore

merge m:1 countyid_curr6 using `base_edu', keep(master match) nogen

foreach be in 0 1 {
    if `be' == 0 local blabel "Low base education"
    if `be' == 1 local blabel "High base education"

    di "=== `blabel', IHS rate ==="
    reghdfejl eduy c.ihs_rate##ib0.post1940 minority i.wave if !drop1939 & high_base_edu == `be', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_be`be'_ihs = _b[1.post1940#c.ihs_rate]
    local se_be`be'_ihs = _se[1.post1940#c.ihs_rate]
    local p_be`be'_ihs = 2*ttail(e(df_r), abs(`b_be`be'_ihs'/`se_be`be'_ihs'))
    local n_be`be'_ihs = e(N)

    di "=== `blabel', Dummy ==="
    reghdfejl eduy i.d_count_high##ib0.post1940 minority i.wave if !drop1939 & high_base_edu == `be', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_be`be'_dum = _b[1.d_count_high#1.post1940]
    local se_be`be'_dum = _se[1.d_count_high#1.post1940]
    local p_be`be'_dum = 2*ttail(e(df_r), abs(`b_be`be'_dum'/`se_be`be'_dum'))
    local n_be`be'_dum = e(N)

    di "  IHS: b=" %8.4f `b_be`be'_ihs' " p=" %6.4f `p_be`be'_ihs'
    di "  Dum: b=" %8.4f `b_be`be'_dum' " p=" %6.4f `p_be`be'_dum'
}

/* Output base education table */
tempname fh
file open `fh' using "${outdir}/pooled_heterogeneity_baseedu_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{Low base education}&\multicolumn{2}{c}{High base education}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &Dummy&IHS(rate)&Dummy&IHS(rate)\\" _n
file write `fh' "\midrule" _n
forvalues b = 0/1 {
    _stars `p_be`b'_dum'
    local sd`b' "`r(star)'"
    _stars `p_be`b'_ihs'
    local si`b' "`r(star)'"
}
file write `fh' "Post $\times$ Treatment&" ///
    %10.4f (`b_be0_dum') "\sym{`sd0'}&" %10.4f (`b_be0_ihs') "\sym{`si0'}&" ///
    %10.4f (`b_be1_dum') "\sym{`sd1'}&" %10.4f (`b_be1_ihs') "\sym{`si1'}\\" _n
file write `fh' "            &(" %7.4f (`se_be0_dum') ")&(" %7.4f (`se_be0_ihs') ")&(" %7.4f (`se_be1_dum') ")&(" %7.4f (`se_be1_ihs') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Observations&" %12.0fc (`n_be0_dum') "&" %12.0fc (`n_be0_ihs') "&" %12.0fc (`n_be1_dum') "&" %12.0fc (`n_be1_ihs') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Base education heterogeneity table saved ==="

di ""
di "========================================="
di "  ALL REMAINING REGRESSIONS COMPLETE"
di "========================================="

exit, clear
