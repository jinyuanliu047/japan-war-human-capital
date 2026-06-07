/*  ================================================================
    EXPANDED: Historical controls + Long March/Korea
    - Both IHS(rate) AND Dummy specs
    - LM/Korea uses IHS-transformed per-capita rate (consistent with main)
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 "${proj}/data/raw/census/census1990.dta"
global c2000 "${proj}/data/raw/census/census2000.dta"
global outdir "${proj}/paper/assets/tables"

*--------------------------------------------------------------
* county dictionary + crosswalk (same boilerplate)
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
* treatment + all controls
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
merge 1:1 countyid_curr6 using "${proj}/data/temp/county_controls_full_v1.dta", keep(master match) nogen
merge 1:1 countyid_curr6 using "${proj}/data/temp/revolutionary_proxy_controls_v1.dta", keep(master match) nogen

/* generate ln versions */
gen ln_victims_cr = ln(1 + victims_cr) if !missing(victims_cr)
gen ln_grain_output = ln(1 + grain_output) if !missing(grain_output)

/* IHS transforms for LM/Korea (consistent with main treatment) */
gen ihs_longmarch = ln(longmarch_martyr_per100k + sqrt(longmarch_martyr_per100k^2 + 1)) if !missing(longmarch_martyr_per100k)
gen ihs_korea     = ln(korea_war_martyr_per100k + sqrt(korea_war_martyr_per100k^2 + 1)) if !missing(korea_war_martyr_per100k)

/* fill missing controls with 0 */
foreach v in sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 ihs_longmarch ihs_korea {
    capture replace `v' = 0 if missing(`v')
}

tempfile treat
save `treat'
global treat_tmp "`treat'"

*--------------------------------------------------------------
* mapping
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
*  Load each wave
*==============================================================
use countyid birthyr eduy ethniccn using "$c1982", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen minority = (ethniccn != 1) if !missing(ethniccn)
keep if inrange(birthyr, 1920, 1956)
rename county_curr6 countyid_curr6
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 1
tempfile w1982
save `w1982'

use county age_c age educ race using "$c1990", clear
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
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 2
tempfile w1990
save `w1990'

use uid birthyr eduyr race using "$c2000", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
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
bysort county_num birth_i wave: gen cohort_n = _N
gen ln_cohort_n = ln(cohort_n)

gen post1940 = (birth_i >= 1940)
gen drop1939 = (birth_i == 1939)

di "=== POOLED N = " _N " ==="

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*##############################################################
*  PART 1: HISTORICAL CONTROLS - EXPANDED (IHS + Dummy)
*##############################################################
di ""
di "========================================"
di "  PART 1: Historical Controls (IHS + Dummy)"
di "========================================"

local controls "sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64"

/* ---- Panel A: IHS(rate) treatment ---- */
di "=== IHS(rate) Baseline ==="
ppmlhdfe eduy c.ihs_rate##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_ihs_base = _b[1.post1940#c.ihs_rate]
local se_ihs_base = _se[1.post1940#c.ihs_rate]
local p_ihs_base = 2*ttail(e(df_r), abs(`b_ihs_base'/`se_ihs_base'))
local n_ihs_base = e(N)

local col = 0
foreach ctrl of local controls {
    local col = `col' + 1
    di "=== IHS + `ctrl' ==="
    ppmlhdfe eduy c.ihs_rate##ib0.post1940 c.`ctrl'##ib0.post1940 minority i.wave if !drop1939, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_ihs_`col' = _b[1.post1940#c.ihs_rate]
    local se_ihs_`col' = _se[1.post1940#c.ihs_rate]
    local p_ihs_`col' = 2*ttail(e(df_r), abs(`b_ihs_`col''/`se_ihs_`col''))
    local n_ihs_`col' = e(N)
}

di "=== IHS + All five ==="
ppmlhdfe eduy c.ihs_rate##ib0.post1940 ///
    c.sdy_density##ib0.post1940 c.ins_famine##ib0.post1940 ///
    c.ln_victims_cr##ib0.post1940 c.ln_grain_output##ib0.post1940 ///
    c.urbanratio64##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_ihs_all = _b[1.post1940#c.ihs_rate]
local se_ihs_all = _se[1.post1940#c.ihs_rate]
local p_ihs_all = 2*ttail(e(df_r), abs(`b_ihs_all'/`se_ihs_all'))
local n_ihs_all = e(N)

/* ---- Panel B: Dummy treatment ---- */
di "=== Dummy Baseline ==="
ppmlhdfe eduy i.d_count_high##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_dum_base = _b[1.d_count_high#1.post1940]
local se_dum_base = _se[1.d_count_high#1.post1940]
local p_dum_base = 2*ttail(e(df_r), abs(`b_dum_base'/`se_dum_base'))
local n_dum_base = e(N)

local col = 0
foreach ctrl of local controls {
    local col = `col' + 1
    di "=== Dummy + `ctrl' ==="
    ppmlhdfe eduy i.d_count_high##ib0.post1940 c.`ctrl'##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_dum_`col' = _b[1.d_count_high#1.post1940]
    local se_dum_`col' = _se[1.d_count_high#1.post1940]
    local p_dum_`col' = 2*ttail(e(df_r), abs(`b_dum_`col''/`se_dum_`col''))
    local n_dum_`col' = e(N)
}

di "=== Dummy + All five ==="
ppmlhdfe eduy i.d_count_high##ib0.post1940 ///
    c.sdy_density##ib0.post1940 c.ins_famine##ib0.post1940 ///
    c.ln_victims_cr##ib0.post1940 c.ln_grain_output##ib0.post1940 ///
    c.urbanratio64##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_dum_all = _b[1.d_count_high#1.post1940]
local se_dum_all = _se[1.d_count_high#1.post1940]
local p_dum_all = 2*ttail(e(df_r), abs(`b_dum_all'/`se_dum_all'))
local n_dum_all = e(N)

/* Output historical controls table (2-panel: IHS + Dummy) */
tempname fh
file open `fh' using "${outdir}/pooled_ppml_historical_controls_expanded_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{7}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}\\" _n
file write `fh' "            &Baseline&+SDY&+Famine&+CR victims&+Grain&+Urban&+All five\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{8}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
_stars `p_ihs_base'
file write `fh' "Post $\times$ IHS(rate)&" %9.4f (`b_ihs_base') "\sym{`r(star)'}"
forvalues j = 1/5 {
    _stars `p_ihs_`j''
    file write `fh' "&" %9.4f (`b_ihs_`j'') "\sym{`r(star)'}"
}
_stars `p_ihs_all'
file write `fh' "&" %9.4f (`b_ihs_all') "\sym{`r(star)'}\\" _n
file write `fh' "            &(" %7.4f (`se_ihs_base') ")"
forvalues j = 1/5 {
    file write `fh' "&(" %7.4f (`se_ihs_`j'') ")"
}
file write `fh' "&(" %7.4f (`se_ihs_all') ")\\[0.5em]" _n
file write `fh' "\multicolumn{8}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
_stars `p_dum_base'
file write `fh' "Post $\times$ High count&" %9.4f (`b_dum_base') "\sym{`r(star)'}"
forvalues j = 1/5 {
    _stars `p_dum_`j''
    file write `fh' "&" %9.4f (`b_dum_`j'') "\sym{`r(star)'}"
}
_stars `p_dum_all'
file write `fh' "&" %9.4f (`b_dum_all') "\sym{`r(star)'}\\" _n
file write `fh' "            &(" %7.4f (`se_dum_base') ")"
forvalues j = 1/5 {
    file write `fh' "&(" %7.4f (`se_dum_`j'') ")"
}
file write `fh' "&(" %7.4f (`se_dum_all') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Historical control&None&SDY density&Famine&CR victims&Grain output&Urban ratio&All five\\" _n
file write `fh' "Cohort size control&     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_ihs_base')
forvalues j = 1/5 {
    file write `fh' "&" %12.0fc (`n_ihs_`j'')
}
file write `fh' "&" %12.0fc (`n_ihs_all') "\\" _n
file write `fh' "Obs (Dummy)&" %12.0fc (`n_dum_base')
forvalues j = 1/5 {
    file write `fh' "&" %12.0fc (`n_dum_`j'')
}
file write `fh' "&" %12.0fc (`n_dum_all') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Historical controls expanded table saved ==="

*##############################################################
*  PART 2: LONG MARCH + KOREAN WAR (IHS treatment for all)
*##############################################################
di ""
di "========================================"
di "  PART 2: Long March / Korean War (expanded)"
di "========================================"

/* (1) IHS(rate) baseline */
ppmlhdfe eduy c.ihs_rate##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_i1 = _b[1.post1940#c.ihs_rate]
local se_i1 = _se[1.post1940#c.ihs_rate]
local p_i1 = 2*ttail(e(df_r), abs(`b_i1'/`se_i1'))
local n_i1 = e(N)

/* (2) IHS + Long March (IHS) */
ppmlhdfe eduy c.ihs_rate##ib0.post1940 c.ihs_longmarch##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_i2 = _b[1.post1940#c.ihs_rate]
local se_i2 = _se[1.post1940#c.ihs_rate]
local p_i2 = 2*ttail(e(df_r), abs(`b_i2'/`se_i2'))
local n_i2 = e(N)

/* (3) IHS + Korea (IHS) */
ppmlhdfe eduy c.ihs_rate##ib0.post1940 c.ihs_korea##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_i3 = _b[1.post1940#c.ihs_rate]
local se_i3 = _se[1.post1940#c.ihs_rate]
local p_i3 = 2*ttail(e(df_r), abs(`b_i3'/`se_i3'))
local n_i3 = e(N)

/* (4) IHS + Both */
ppmlhdfe eduy c.ihs_rate##ib0.post1940 c.ihs_longmarch##ib0.post1940 ///
    c.ihs_korea##ib0.post1940 minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_i4 = _b[1.post1940#c.ihs_rate]
local se_i4 = _se[1.post1940#c.ihs_rate]
local p_i4 = 2*ttail(e(df_r), abs(`b_i4'/`se_i4'))
local n_i4 = e(N)

/* (5) Dummy baseline */
ppmlhdfe eduy i.d_count_high##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_d1 = _b[1.d_count_high#1.post1940]
local se_d1 = _se[1.d_count_high#1.post1940]
local p_d1 = 2*ttail(e(df_r), abs(`b_d1'/`se_d1'))
local n_d1 = e(N)

/* (6) Dummy + Long March */
ppmlhdfe eduy i.d_count_high##ib0.post1940 c.ihs_longmarch##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_d2 = _b[1.d_count_high#1.post1940]
local se_d2 = _se[1.d_count_high#1.post1940]
local p_d2 = 2*ttail(e(df_r), abs(`b_d2'/`se_d2'))
local n_d2 = e(N)

/* (7) Dummy + Korea */
ppmlhdfe eduy i.d_count_high##ib0.post1940 c.ihs_korea##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_d3 = _b[1.d_count_high#1.post1940]
local se_d3 = _se[1.d_count_high#1.post1940]
local p_d3 = 2*ttail(e(df_r), abs(`b_d3'/`se_d3'))
local n_d3 = e(N)

/* (8) Dummy + Both */
ppmlhdfe eduy i.d_count_high##ib0.post1940 c.ihs_longmarch##ib0.post1940 ///
    c.ihs_korea##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_d4 = _b[1.d_count_high#1.post1940]
local se_d4 = _se[1.d_count_high#1.post1940]
local p_d4 = 2*ttail(e(df_r), abs(`b_d4'/`se_d4'))
local n_d4 = e(N)

di "IHS:  base=" %8.4f `b_i1' "  +LM=" %8.4f `b_i2' "  +Korea=" %8.4f `b_i3' "  +Both=" %8.4f `b_i4'
di "Dum:  base=" %8.4f `b_d1' "  +LM=" %8.4f `b_d2' "  +Korea=" %8.4f `b_d3' "  +Both=" %8.4f `b_d4'

/* Output LM/Korea table (2-panel) */
tempname fh
file open `fh' using "${outdir}/pooled_ppml_longmarch_korea_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}\\" _n
file write `fh' "            &Baseline&+Long March&+Korean War&+Both\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
forvalues j = 1/4 {
    _stars `p_i`j''
    local si`j' "`r(star)'"
}
file write `fh' "Post $\times$ IHS(rate)&" %9.4f (`b_i1') "\sym{`si1'}&" %9.4f (`b_i2') "\sym{`si2'}&" %9.4f (`b_i3') "\sym{`si3'}&" %9.4f (`b_i4') "\sym{`si4'}\\" _n
file write `fh' "            &(" %7.4f (`se_i1') ")&(" %7.4f (`se_i2') ")&(" %7.4f (`se_i3') ")&(" %7.4f (`se_i4') ")\\[0.5em]" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
forvalues j = 1/4 {
    _stars `p_d`j''
    local sd`j' "`r(star)'"
}
file write `fh' "Post $\times$ High count&" %9.4f (`b_d1') "\sym{`sd1'}&" %9.4f (`b_d2') "\sym{`sd2'}&" %9.4f (`b_d3') "\sym{`sd3'}&" %9.4f (`b_d4') "\sym{`sd4'}\\" _n
file write `fh' "            &(" %7.4f (`se_d1') ")&(" %7.4f (`se_d2') ")&(" %7.4f (`se_d3') ")&(" %7.4f (`se_d4') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Long March control (IHS)&            &     Yes         &            &     Yes         \\" _n
file write `fh' "Korean War control (IHS)&            &            &     Yes         &     Yes         \\" _n
file write `fh' "Cohort size control&     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_i1') "&" %12.0fc (`n_i2') "&" %12.0fc (`n_i3') "&" %12.0fc (`n_i4') "\\" _n
file write `fh' "Obs (Dummy)&" %12.0fc (`n_d1') "&" %12.0fc (`n_d2') "&" %12.0fc (`n_d3') "&" %12.0fc (`n_d4') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Long March/Korea expanded table saved ==="

di ""
di "========================================="
di "  EXPANDED HISTORICAL + LM/K COMPLETE"
di "========================================="

exit, clear
