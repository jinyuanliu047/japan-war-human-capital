/*  ================================================================
    Comprehensive pooled regressions:
    - Cutoffs: 1940 and 1946
    - Treatments: dummy, IHS(count), IHS(per100k), raw count std
    - Models: OLS, PPML
    - Controls: with/without county×cohort population
    - eduy: 1% winsorised
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

*--------------------------------------------------------------
* resolve program
*--------------------------------------------------------------
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

/* IHS transformations */
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

/* dummy: above median count */
summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)

/* dummy: above median rate */
summ martyr_per100k_1953, detail
gen d_rate_high = (martyr_per100k_1953 > r(p50)) if !missing(martyr_per100k_1953)

/* tercile */
xtile count_tercile = martyr_count, nq(3)

/* std count (winsorised p99) */
summ martyr_count, detail
gen count_w = min(martyr_count, r(p99))
summ count_w
gen count_std = (count_w - r(mean)) / r(sd)

/* std rate (winsorised p99) */
summ martyr_per100k_1953, detail
gen rate_w = min(martyr_per100k_1953, r(p99))
summ rate_w
gen rate_std = (rate_w - r(mean)) / r(sd)

/* ln pop for control */
gen ln_pop53 = ln(pop_1953) if pop_1953 > 0

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
*  Load each wave (keep ALL birth years for both cutoffs)
*==============================================================

* ---- 1982 ----
di "=== Loading 1982 ==="
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
di "1982 N = " _N

* ---- 1990 ----
di "=== Loading 1990 ==="
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
di "1990 N = " _N

* ---- 2000 ----
di "=== Loading 2000 ==="
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
di "2000 N = " _N

*==============================================================
*  Pool & winsorize
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'
egen county_num = group(countyid_curr6)

di "=== Pooled N (before winsorize) = " _N

/* 1% winsorize eduy */
summ eduy, detail
scalar eduy_p1  = r(p1)
scalar eduy_p99 = r(p99)
di "eduy: p1 = " eduy_p1 "  p99 = " eduy_p99
replace eduy = eduy_p1  if eduy < eduy_p1
replace eduy = eduy_p99 if eduy > eduy_p99 & !missing(eduy)

/* county × cohort cell size */
bysort countyid_curr6 birth_i wave: gen cohort_n = _N
gen ln_cohort_n = ln(cohort_n)

/* eduy + 1 for PPML (needs positive) */
gen eduy_pp = eduy + 1

di "=== Pooled N = " _N
tab wave

*==============================================================
*  Helper: run spec and store
*==============================================================
/* We'll store results in a CSV manually */

tempname fh
file open `fh' using "${outdir}/pooled_comprehensive_results_v1.csv", write replace
file write `fh' "cutoff,treatment,model,cohort_ctrl,b,se,p,N" _n

*==============================================================
*  Loop over cutoffs
*==============================================================
foreach cutoff in 1940 1946 {

    /* define post and drop year */
    capture drop post drop_yr
    gen post = (birth_i >= `cutoff')
    local dropyr = `cutoff' - 1
    gen byte drop_yr = (birth_i == `dropyr')

    di ""
    di "###################################################"
    di "  CUTOFF = `cutoff'  (drop `dropyr')"
    di "###################################################"

    /* ---- 1. Dummy (count > median), OLS ---- */
    di "=== `cutoff': Dummy count, OLS ==="
    reghdfejl eduy i.d_count_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',dummy_count,OLS,no,`b',`se',`p',`n'" _n

    /* ---- 1b. Dummy + cohort_n control ---- */
    di "=== `cutoff': Dummy count + cohort ctrl, OLS ==="
    reghdfejl eduy i.d_count_high##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',dummy_count,OLS,yes,`b',`se',`p',`n'" _n

    /* ---- 2. Dummy (rate > median), OLS ---- */
    di "=== `cutoff': Dummy rate, OLS ==="
    reghdfejl eduy i.d_rate_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.d_rate_high#1.post]
    local se = _se[1.d_rate_high#1.post]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',dummy_rate,OLS,no,`b',`se',`p',`n'" _n

    /* ---- 3. IHS(count), OLS ---- */
    di "=== `cutoff': IHS count, OLS ==="
    reghdfejl eduy c.ihs_count##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.ihs_count]
    local se = _se[1.post#c.ihs_count]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',ihs_count,OLS,no,`b',`se',`p',`n'" _n

    /* ---- 3b. IHS(count) + cohort ctrl ---- */
    di "=== `cutoff': IHS count + cohort ctrl, OLS ==="
    reghdfejl eduy c.ihs_count##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.ihs_count]
    local se = _se[1.post#c.ihs_count]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',ihs_count,OLS,yes,`b',`se',`p',`n'" _n

    /* ---- 4. IHS(rate), OLS ---- */
    di "=== `cutoff': IHS rate, OLS ==="
    reghdfejl eduy c.ihs_rate##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.ihs_rate]
    local se = _se[1.post#c.ihs_rate]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',ihs_rate,OLS,no,`b',`se',`p',`n'" _n

    /* ---- 4b. IHS(rate) + cohort ctrl ---- */
    di "=== `cutoff': IHS rate + cohort ctrl, OLS ==="
    reghdfejl eduy c.ihs_rate##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.ihs_rate]
    local se = _se[1.post#c.ihs_rate]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',ihs_rate,OLS,yes,`b',`se',`p',`n'" _n

    /* ---- 5. Std count, OLS ---- */
    di "=== `cutoff': Std count, OLS ==="
    reghdfejl eduy c.count_std##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.count_std]
    local se = _se[1.post#c.count_std]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',std_count,OLS,no,`b',`se',`p',`n'" _n

    /* ---- 5b. Std count + cohort ctrl ---- */
    di "=== `cutoff': Std count + cohort ctrl, OLS ==="
    reghdfejl eduy c.count_std##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.count_std]
    local se = _se[1.post#c.count_std]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',std_count,OLS,yes,`b',`se',`p',`n'" _n

    /* ---- 6. Std rate, OLS ---- */
    di "=== `cutoff': Std rate, OLS ==="
    reghdfejl eduy c.rate_std##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.rate_std]
    local se = _se[1.post#c.rate_std]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',std_rate,OLS,no,`b',`se',`p',`n'" _n

    /* ---- 6b. Std rate + cohort ctrl ---- */
    di "=== `cutoff': Std rate + cohort ctrl, OLS ==="
    reghdfejl eduy c.rate_std##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.rate_std]
    local se = _se[1.post#c.rate_std]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',std_rate,OLS,yes,`b',`se',`p',`n'" _n

    /* ---- 7. ln per100k reference ---- */
    di "=== `cutoff': ln per100k (reference), OLS ==="
    reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',ln_per100k,OLS,no,`b',`se',`p',`n'" _n

    /* ---- 8. ln raw count ---- */
    di "=== `cutoff': ln raw count, OLS ==="
    reghdfejl eduy c.ln_martyr_raw##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.ln_martyr_raw]
    local se = _se[1.post#c.ln_martyr_raw]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',ln_count,OLS,no,`b',`se',`p',`n'" _n

    /* ---- 8b. ln raw count + ln pop53 + cohort ctrl ---- */
    di "=== `cutoff': ln count + ln pop + cohort ctrl, OLS ==="
    reghdfejl eduy c.ln_martyr_raw##ib0.post c.ln_pop53##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.post#c.ln_martyr_raw]
    local se = _se[1.post#c.ln_martyr_raw]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    file write `fh' "`cutoff',ln_count,OLS,pop+cohort,`b',`se',`p',`n'" _n

    /* ---- 9. Tercile, OLS ---- */
    di "=== `cutoff': Tercile, OLS ==="
    reghdfejl eduy i.count_tercile##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local bT2 = _b[2.count_tercile#1.post]
    local seT2 = _se[2.count_tercile#1.post]
    local pT2 = 2*ttail(e(df_r), abs(`bT2'/`seT2'))
    local bT3 = _b[3.count_tercile#1.post]
    local seT3 = _se[3.count_tercile#1.post]
    local pT3 = 2*ttail(e(df_r), abs(`bT3'/`seT3'))
    local n = e(N)
    file write `fh' "`cutoff',tercile_T2,OLS,no,`bT2',`seT2',`pT2',`n'" _n
    file write `fh' "`cutoff',tercile_T3,OLS,no,`bT3',`seT3',`pT3',`n'" _n

    /* ---- 10. PPML: dummy ---- */
    di "=== `cutoff': Dummy count, PPML ==="
    capture {
        ppmlhdfe eduy_pp i.d_count_high##ib0.post minority i.wave if !drop_yr, ///
            absorb(county_num birth_i) vce(cluster county_num)
        local b = _b[1.d_count_high#1.post]
        local se = _se[1.d_count_high#1.post]
        local p = 2*normal(-abs(`b'/`se'))
        local n = e(N)
        file write `fh' "`cutoff',dummy_count,PPML,no,`b',`se',`p',`n'" _n
    }
    if _rc {
        di "PPML dummy failed, trying poisson"
        capture noisily poisson eduy_pp i.d_count_high##ib0.post minority i.wave i.county_num i.birth_i if !drop_yr, vce(cluster county_num)
        if !_rc {
            local b = _b[1.d_count_high#1.post]
            local se = _se[1.d_count_high#1.post]
            local p = 2*normal(-abs(`b'/`se'))
            local n = e(N)
            file write `fh' "`cutoff',dummy_count,PPML,no,`b',`se',`p',`n'" _n
        }
    }

    /* ---- 11. PPML: IHS count ---- */
    di "=== `cutoff': IHS count, PPML ==="
    capture {
        ppmlhdfe eduy_pp c.ihs_count##ib0.post minority i.wave if !drop_yr, ///
            absorb(county_num birth_i) vce(cluster county_num)
        local b = _b[1.post#c.ihs_count]
        local se = _se[1.post#c.ihs_count]
        local p = 2*normal(-abs(`b'/`se'))
        local n = e(N)
        file write `fh' "`cutoff',ihs_count,PPML,no,`b',`se',`p',`n'" _n
    }
    if _rc {
        di "PPML IHS count failed"
    }

    /* ---- 12. PPML: ln per100k ---- */
    di "=== `cutoff': ln per100k, PPML ==="
    capture {
        ppmlhdfe eduy_pp c.ln_martyr_per100k_1953##ib0.post minority i.wave if !drop_yr, ///
            absorb(county_num birth_i) vce(cluster county_num)
        local b = _b[1.post#c.ln_martyr_per100k_1953]
        local se = _se[1.post#c.ln_martyr_per100k_1953]
        local p = 2*normal(-abs(`b'/`se'))
        local n = e(N)
        file write `fh' "`cutoff',ln_per100k,PPML,no,`b',`se',`p',`n'" _n
    }
    if _rc {
        di "PPML ln per100k failed"
    }

    drop post drop_yr
}

file close `fh'

*==============================================================
*  Display summary
*==============================================================
di ""
di "========================================="
di "  Results saved to CSV. Loading..."
di "========================================="

import delimited "${outdir}/pooled_comprehensive_results_v1.csv", clear varnames(1)
format b se p %9.4f
format n %12.0fc
list, separator(0) noobs abbreviate(20)

exit, clear
