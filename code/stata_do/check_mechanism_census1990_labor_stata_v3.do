*******************************************************
* Census 1990 raw labor force / occupation outcomes
* Pure Stata build to avoid raw-file Python I/O bottleneck
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "male minority rural"
global raw1990 "${proj}/data/raw/census/census1990.dta"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfe
if _rc != 0 {
    di as error "reghdfe not found"
    exit 198
}

*******************************************************
* county dictionary and 1982 crosswalk
*******************************************************
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
    replace route = "municipality_then_exact" if county_curr6==curr_from_muni_exact & curr_from_muni_exact!=""
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

*******************************************************
* treatment and 1990 old->current map
*******************************************************
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
duplicates drop countyid_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

use county using "$raw1990", clear
drop if missing(county)
gen str6 old6 = string(county, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6 route
drop if county_curr6==""
tempfile map1990
save `map1990'
global map1990_tmp "`map1990'"

use county age_c age sex race regstatu occu unemp_st using "$raw1990", clear
drop if missing(county) | missing(age_c) | missing(age)

gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using "$map1990_tmp", keep(master match) nogen keepusing(county_curr6 route)
keep if county_curr6!=""

gen birth_i = 1000 + age_c*100 + age
keep if inrange(birth_i, 1920, 1968)
drop if birth_i == 1939

merge m:1 county_curr6 using "$treat_tmp", keep(master match) nogen
rename county_curr6 countyid_curr6

gen post = birth_i >= 1940
gen male = (sex == 1) if inlist(sex, 1, 2)
gen minority = (race != 1) if !missing(race)
gen rural = (regstatu == 1) if inrange(regstatu, 1, 5)

gen employed = (occu > 0) if !missing(occu)
gen in_labor_force = (occu > 0 | unemp_st == 5) if !missing(occu) | !missing(unemp_st)
gen white_collar = inrange(occu, 11, 399) if employed == 1
gen manual = inrange(occu, 601, 999) if employed == 1
gen nonagri = !inrange(occu, 401, 599) if employed == 1

egen county_num = group(countyid_curr6)

tempfile labor1990_main
save `labor1990_main', replace
global labor1990_tmp "`labor1990_main'"

preserve
    keep birth_i post employed in_labor_force white_collar manual nonagri route
    gen one = 1
    collapse (count) n_obs=one (sum) post employed in_labor_force white_collar manual nonagri, by(route)
    export delimited using "${proj}/data/temp/census1990_labor_build_audit_v3.csv", replace
restore

capture program drop _run_one
program define _run_one, rclass
    syntax , YVAR(name) MODEL(name)
    use "$labor1990_tmp", clear
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male, minority, rural)
    local n = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male, minority, rural) & post == 0
    local n_pre = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male, minority, rural) & post == 1
    local n_post = r(N)
    quietly reghdfe `yvar' c.ln_martyr_per100k_1953##ib0.post $control ///
        if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male, minority, rural), ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar N_sample = `n'
    estadd scalar N_pre = `n_pre'
    estadd scalar N_post = `n_post'
    return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))
    return scalar n = `n'
    return scalar n_pre = `n_pre'
    return scalar n_post = `n_post'
end

eststo clear
tempfile summary
clear
set obs 0
gen str20 outcome = ""
gen b = .
gen se = .
gen p = .
gen n = .
gen n_pre = .
gen n_post = .
save `summary', replace

local outcomes in_labor_force employed nonagri white_collar manual
local models ""

foreach y of local outcomes {
    local m = "m_`y'"
    quietly _run_one, yvar(`y') model(`m')
    local models "`models' `m'"
    use `summary', clear
    local row = _N + 1
    set obs `row'
    replace outcome = "`y'" in `row'
    replace b = r(b) in `row'
    replace se = r(se) in `row'
    replace p = r(p) in `row'
    replace n = r(n) in `row'
    replace n_pre = r(n_pre) in `row'
    replace n_post = r(n_post) in `row'
    save `summary', replace
}

use `summary', clear
export delimited using "${proj}/result/table/mechanism_census1990_labor_reghdfejl_summary_v3.csv", replace
save "${proj}/result/table/mechanism_census1990_labor_reghdfejl_summary_v3.dta", replace

esttab `models' using "${proj}/result/table/mechanism_census1990_labor_reghdfejl_v3.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/mechanism_census1990_labor_reghdfejl_v3.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
