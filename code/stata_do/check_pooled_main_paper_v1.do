/*  ================================================================
    Main paper results: pooled 1982+1990+2000
    Treatment: IHS(rate), IHS(count), Dummy(count), Dummy(rate)
    Both cutoffs: 1940 and 1946
    Output: publication-quality .tex tables
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
* county dictionary + crosswalk
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
local median_count = r(p50)
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
summ martyr_per100k_1953, detail
local median_rate = r(p50)
gen d_rate_high = (martyr_per100k_1953 > r(p50)) if !missing(martyr_per100k_1953)

rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
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

/* cohort cell size */
bysort county_num birth_i wave: gen cohort_n = _N
gen ln_cohort_n = ln(cohort_n)

di "=== POOLED N = " _N " ==="

/* count counties & obs for each sample */
preserve
    collapse (first) d_count_high d_rate_high, by(countyid_curr6)
    count
    local n_counties_all = r(N)
    count if d_count_high != .
    local n_counties_count = r(N)
    count if d_rate_high != .
    local n_counties_rate = r(N)
restore

count
local n_count_sample = r(N)
count if !missing(d_rate_high)
local n_rate_sample = r(N)

*==============================================================
*  Helper: stars
*==============================================================
capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01 {
        return local star "***"
    }
    else if `pval' < 0.05 {
        return local star "**"
    }
    else if `pval' < 0.10 {
        return local star "*"
    }
    else {
        return local star ""
    }
end

*==============================================================
*  REGRESSIONS: Cutoff 1940 (main) and 1946 (robustness)
*  Columns:
*    (1) Dummy count
*    (2) Dummy count + cohort ctrl
*    (3) Dummy rate
*    (4) IHS(count)
*    (5) IHS(count) + cohort ctrl
*    (6) IHS(rate)
*    (7) ln(per100k) - reference
*==============================================================

foreach cutoff in 1940 1946 {
    local dropyr = `cutoff' - 1
    capture drop post drop_yr
    gen post = (birth_i >= `cutoff')
    gen byte drop_yr = (birth_i == `dropyr')

    /* (1) Dummy count */
    di "=== Cutoff `cutoff': (1) Dummy count ==="
    reghdfejl eduy i.d_count_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_1_`cutoff'  = _b[1.d_count_high#1.post]
    local se_1_`cutoff' = _se[1.d_count_high#1.post]
    local p_1_`cutoff'  = 2*ttail(e(df_r), abs(`b_1_`cutoff''/`se_1_`cutoff''))
    local n_1_`cutoff'  = e(N)
    local r2_1_`cutoff' = e(r2)
    local nc_1_`cutoff' = e(N_clust)

    /* (2) Dummy count + cohort ctrl */
    di "=== Cutoff `cutoff': (2) Dummy count + cohort ==="
    reghdfejl eduy i.d_count_high##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_2_`cutoff'  = _b[1.d_count_high#1.post]
    local se_2_`cutoff' = _se[1.d_count_high#1.post]
    local p_2_`cutoff'  = 2*ttail(e(df_r), abs(`b_2_`cutoff''/`se_2_`cutoff''))
    local n_2_`cutoff'  = e(N)
    local r2_2_`cutoff' = e(r2)

    /* (3) Dummy rate */
    di "=== Cutoff `cutoff': (3) Dummy rate ==="
    reghdfejl eduy i.d_rate_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_3_`cutoff'  = _b[1.d_rate_high#1.post]
    local se_3_`cutoff' = _se[1.d_rate_high#1.post]
    local p_3_`cutoff'  = 2*ttail(e(df_r), abs(`b_3_`cutoff''/`se_3_`cutoff''))
    local n_3_`cutoff'  = e(N)
    local r2_3_`cutoff' = e(r2)

    /* (4) IHS count */
    di "=== Cutoff `cutoff': (4) IHS count ==="
    reghdfejl eduy c.ihs_count##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_4_`cutoff'  = _b[1.post#c.ihs_count]
    local se_4_`cutoff' = _se[1.post#c.ihs_count]
    local p_4_`cutoff'  = 2*ttail(e(df_r), abs(`b_4_`cutoff''/`se_4_`cutoff''))
    local n_4_`cutoff'  = e(N)
    local r2_4_`cutoff' = e(r2)

    /* (5) IHS count + cohort ctrl */
    di "=== Cutoff `cutoff': (5) IHS count + cohort ==="
    reghdfejl eduy c.ihs_count##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_5_`cutoff'  = _b[1.post#c.ihs_count]
    local se_5_`cutoff' = _se[1.post#c.ihs_count]
    local p_5_`cutoff'  = 2*ttail(e(df_r), abs(`b_5_`cutoff''/`se_5_`cutoff''))
    local n_5_`cutoff'  = e(N)
    local r2_5_`cutoff' = e(r2)

    /* (6) IHS rate */
    di "=== Cutoff `cutoff': (6) IHS rate ==="
    reghdfejl eduy c.ihs_rate##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_6_`cutoff'  = _b[1.post#c.ihs_rate]
    local se_6_`cutoff' = _se[1.post#c.ihs_rate]
    local p_6_`cutoff'  = 2*ttail(e(df_r), abs(`b_6_`cutoff''/`se_6_`cutoff''))
    local n_6_`cutoff'  = e(N)
    local r2_6_`cutoff' = e(r2)

    /* (7) ln per100k reference */
    di "=== Cutoff `cutoff': (7) ln per100k ref ==="
    reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_7_`cutoff'  = _b[1.post#c.ln_martyr_per100k_1953]
    local se_7_`cutoff' = _se[1.post#c.ln_martyr_per100k_1953]
    local p_7_`cutoff'  = 2*ttail(e(df_r), abs(`b_7_`cutoff''/`se_7_`cutoff''))
    local n_7_`cutoff'  = e(N)
    local r2_7_`cutoff' = e(r2)

    drop post drop_yr
}

*==============================================================
*  Output Table: Cutoff 1940 (main baseline)
*==============================================================

foreach cutoff in 1940 1946 {

    /* compute stars */
    forvalues c = 1/7 {
        _stars `p_`c'_`cutoff''
        local s_`c'_`cutoff' "`r(star)'"
    }

    local suffix = cond(`cutoff'==1940, "main", "robust1946")

    tempname fh
    file open `fh' using "${outdir}/pooled_baseline_`suffix'_v1.tex", write replace

    file write `fh' "{" _n
    file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
    file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{7}{c}}" _n
    file write `fh' "\toprule" _n
    file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}\\" _n
    file write `fh' "            &\multicolumn{3}{c}{Binary (above median)}&\multicolumn{3}{c}{Inverse hyperbolic sine}&\multicolumn{1}{c}{Log}\\" _n
    file write `fh' "            \cmidrule(lr){2-4}\cmidrule(lr){5-7}\cmidrule(lr){8-8}" _n

    /* Row: Dummy count */
    file write `fh' "Post $\times$ High count&" ///
        %12.4f (`b_1_`cutoff'') "\sym{`s_1_`cutoff''}&" ///
        %12.4f (`b_2_`cutoff'') "\sym{`s_2_`cutoff''}&" ///
        "            &            &            &            &            \\" _n
    file write `fh' "            &" ///
        "(" %7.4f (`se_1_`cutoff'') ")&" ///
        "(" %7.4f (`se_2_`cutoff'') ")&" ///
        "            &            &            &            &            \\" _n

    /* Row: Dummy rate */
    file write `fh' "Post $\times$ High rate&" ///
        "            &            &" ///
        %12.4f (`b_3_`cutoff'') "\sym{`s_3_`cutoff''}&" ///
        "            &            &            &            \\" _n
    file write `fh' "            &" ///
        "            &            &" ///
        "(" %7.4f (`se_3_`cutoff'') ")&" ///
        "            &            &            &            \\[0.3em]" _n

    /* Row: IHS count */
    file write `fh' "Post $\times$ IHS(count)&" ///
        "            &            &            &" ///
        %12.4f (`b_4_`cutoff'') "\sym{`s_4_`cutoff''}&" ///
        %12.4f (`b_5_`cutoff'') "\sym{`s_5_`cutoff''}&" ///
        "            &            \\" _n
    file write `fh' "            &" ///
        "            &            &            &" ///
        "(" %7.4f (`se_4_`cutoff'') ")&" ///
        "(" %7.4f (`se_5_`cutoff'') ")&" ///
        "            &            \\" _n

    /* Row: IHS rate */
    file write `fh' "Post $\times$ IHS(rate)&" ///
        "            &            &            &" ///
        "            &            &" ///
        %12.4f (`b_6_`cutoff'') "\sym{`s_6_`cutoff''}&" ///
        "            \\" _n
    file write `fh' "            &" ///
        "            &            &            &" ///
        "            &            &" ///
        "(" %7.4f (`se_6_`cutoff'') ")&" ///
        "            \\[0.3em]" _n

    /* Row: ln reference */
    file write `fh' "Post $\times$ $\ln$(per 100k)&" ///
        "            &            &            &" ///
        "            &            &            &" ///
        %12.4f (`b_7_`cutoff'') "\sym{`s_7_`cutoff''}\\" _n
    file write `fh' "            &" ///
        "            &            &            &" ///
        "            &            &            &" ///
        "(" %7.4f (`se_7_`cutoff'') ")\\" _n

    /* Footer */
    file write `fh' "\midrule" _n
    file write `fh' "Cohort size control&" ///
        "            &     Yes         &            &" ///
        "            &     Yes         &            &            \\" _n
    file write `fh' "Minority control&" ///
        "     Yes         &     Yes         &     Yes         &" ///
        "     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "County FE   &" ///
        "     Yes         &     Yes         &     Yes         &" ///
        "     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "Cohort FE   &" ///
        "     Yes         &     Yes         &     Yes         &" ///
        "     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "Wave FE     &" ///
        "     Yes         &     Yes         &     Yes         &" ///
        "     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "Cohort window&" ///
        " [1920, 1956] & [1920, 1956] & [1920, 1956] &" ///
        " [1920, 1956] & [1920, 1956] & [1920, 1956] & [1920, 1956] \\" _n
    file write `fh' "Treatment start&" ///
        "     `cutoff'         &     `cutoff'         &     `cutoff'         &" ///
        "     `cutoff'         &     `cutoff'         &     `cutoff'         &     `cutoff'         \\" _n
    file write `fh' "Observations&" ///
        %12.0fc (`n_1_`cutoff'') "&" ///
        %12.0fc (`n_2_`cutoff'') "&" ///
        %12.0fc (`n_3_`cutoff'') "&" ///
        %12.0fc (`n_4_`cutoff'') "&" ///
        %12.0fc (`n_5_`cutoff'') "&" ///
        %12.0fc (`n_6_`cutoff'') "&" ///
        %12.0fc (`n_7_`cutoff'') "\\" _n
    file write `fh' "R-squared   &" ///
        %12.3f (`r2_1_`cutoff'') "&" ///
        %12.3f (`r2_2_`cutoff'') "&" ///
        %12.3f (`r2_3_`cutoff'') "&" ///
        %12.3f (`r2_4_`cutoff'') "&" ///
        %12.3f (`r2_5_`cutoff'') "&" ///
        %12.3f (`r2_6_`cutoff'') "&" ///
        %12.3f (`r2_7_`cutoff'') "\\" _n
    file write `fh' "Counties    &" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "\\" _n
    file write `fh' "\bottomrule" _n
    file write `fh' "\end{tabular*}" _n
    file write `fh' "}" _n

    file close `fh'

    di "=== Table saved: pooled_baseline_`suffix'_v1.tex ==="
}

*==============================================================
*  Updated Summary Statistics table (pooled)
*==============================================================

/* Overall pooled stats */
summ eduy
local m_edu = r(mean)
local sd_edu = r(sd)
summ minority
local m_min = r(mean)
local sd_min = r(sd)
gen post1940 = (birth_i >= 1940)
summ post1940
local m_post = r(mean)
local sd_post = r(sd)
summ ihs_rate if !missing(ihs_rate)
local m_ihsr = r(mean)
local sd_ihsr = r(sd)
summ d_count_high if !missing(d_count_high)
local m_dum = r(mean)
local sd_dum = r(sd)
summ ihs_count
local m_ihsc = r(mean)
local sd_ihsc = r(sd)
summ ln_martyr_per100k_1953 if !missing(ln_martyr_per100k_1953)
local m_lnr = r(mean)
local sd_lnr = r(sd)

count
local n_all = r(N)

/* by wave */
forvalues w = 1/3 {
    summ eduy if wave == `w'
    local m_edu_`w' = r(mean)
    local sd_edu_`w' = r(sd)
    summ minority if wave == `w'
    local m_min_`w' = r(mean)
    local sd_min_`w' = r(sd)
    summ post1940 if wave == `w'
    local m_post_`w' = r(mean)
    local sd_post_`w' = r(sd)
    summ ihs_rate if wave == `w' & !missing(ihs_rate)
    local m_ihsr_`w' = r(mean)
    local sd_ihsr_`w' = r(sd)
    summ d_count_high if wave == `w' & !missing(d_count_high)
    local m_dum_`w' = r(mean)
    local sd_dum_`w' = r(sd)
    count if wave == `w'
    local n_`w' = r(N)
}

tempname fh
file open `fh' using "${outdir}/summary_statistics_pooled_v1.tex", write replace

file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{cc}}" _n
file write `fh' "\toprule" _n
file write `fh' "                    &\multicolumn{2}{c}{1982}&\multicolumn{2}{c}{1990}&\multicolumn{2}{c}{2000}&\multicolumn{2}{c}{Pooled}\\" _n
file write `fh' "                    &        mean&          sd&        mean&          sd&        mean&          sd&        mean&          sd\\" _n
file write `fh' "\midrule" _n
file write `fh' "Years of education  &" %12.3f (`m_edu_1') "&     (" %5.3f (`sd_edu_1') ")&" %12.3f (`m_edu_2') "&     (" %5.3f (`sd_edu_2') ")&" %12.3f (`m_edu_3') "&     (" %5.3f (`sd_edu_3') ")&" %12.3f (`m_edu') "&     (" %5.3f (`sd_edu') ")\\" _n
file write `fh' "Minority            &" %12.3f (`m_min_1') "&     (" %5.3f (`sd_min_1') ")&" %12.3f (`m_min_2') "&     (" %5.3f (`sd_min_2') ")&" %12.3f (`m_min_3') "&     (" %5.3f (`sd_min_3') ")&" %12.3f (`m_min') "&     (" %5.3f (`sd_min') ")\\" _n
file write `fh' "Post-war cohort     &" %12.3f (`m_post_1') "&     (" %5.3f (`sd_post_1') ")&" %12.3f (`m_post_2') "&     (" %5.3f (`sd_post_2') ")&" %12.3f (`m_post_3') "&     (" %5.3f (`sd_post_3') ")&" %12.3f (`m_post') "&     (" %5.3f (`sd_post') ")\\" _n
file write `fh' "IHS(martyrs/100k)   &" %12.3f (`m_ihsr_1') "&     (" %5.3f (`sd_ihsr_1') ")&" %12.3f (`m_ihsr_2') "&     (" %5.3f (`sd_ihsr_2') ")&" %12.3f (`m_ihsr_3') "&     (" %5.3f (`sd_ihsr_3') ")&" %12.3f (`m_ihsr') "&     (" %5.3f (`sd_ihsr') ")\\" _n
file write `fh' "High martyr county  &" %12.3f (`m_dum_1') "&     (" %5.3f (`sd_dum_1') ")&" %12.3f (`m_dum_2') "&     (" %5.3f (`sd_dum_2') ")&" %12.3f (`m_dum_3') "&     (" %5.3f (`sd_dum_3') ")&" %12.3f (`m_dum') "&     (" %5.3f (`sd_dum') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Observations        &  " %12.0fc (`n_1') "&            &  " %12.0fc (`n_2') "&            &  " %12.0fc (`n_3') "&            &  " %12.0fc (`n_all') "&            \\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n

file close `fh'

di ""
di "=== ALL TABLES SAVED ==="

exit, clear
