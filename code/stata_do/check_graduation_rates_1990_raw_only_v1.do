*******************************************************
* 1990 completion-rate regressions
* Raw individual county route, no micro-equivalent panel
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/raw/census/census1990.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

global census1990 "${proj}/data/raw/census/census1990.dta"
if fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta") global census1990 "${proj}/data/temp/census_1990_mainvars_v1.dta"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

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

    merge 1:1 old6 using `muni_exact', keep(master match) nogen update replace
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

use county using "$census1990", clear
drop if missing(county)
gen str6 old6 = string(county, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map1990
save `map1990'

use county age_c age educ using "$census1990", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using `map1990', keep(master match) nogen
keep if county_curr6!=""
gen birthyr = 1000 + age_c*100 + age
gen birth_i = floor(birthyr)
gen eduy_clean = .
replace eduy_clean = 0  if educ==1
replace eduy_clean = 6  if educ==2
replace eduy_clean = 9  if educ==3
replace eduy_clean = 12 if inlist(educ,4,5)
replace eduy_clean = 15 if educ==6
replace eduy_clean = 16 if educ==7
keep if inrange(birth_i, 1920, 1968)
keep if inrange(eduy_clean, 0, 25)
drop if birth_i == 1939

gen total_n = 1
gen primary_num = (eduy_clean >= 6)
gen junior_num = (eduy_clean >= 9)
gen senior_num = (eduy_clean >= 12)
gen college_num = (eduy_clean >= 15)
collapse (sum) total_n primary_num junior_num senior_num college_num, by(county_curr6 birth_i)
rename county_curr6 countyid_curr6

merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", keep(master match) nogen keepusing(ln_martyr_per100k_1953)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)

foreach cutoff in 1940 1946 {
    preserve
    gen postcut = birth_i >= `cutoff'
    drop if birth_i == (`cutoff' - 1)
    gen primary_rate = primary_num / total_n
    gen junior_rate = junior_num / total_n
    gen senior_rate = senior_num / total_n
    gen college_rate = college_num / total_n

    quietly reghdfe primary_rate c.ln_martyr_per100k_1953##ib0.postcut [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store p1
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "`cutoff'"

    quietly reghdfe junior_rate c.ln_martyr_per100k_1953##ib0.postcut [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store p2
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "`cutoff'"

    quietly reghdfe senior_rate c.ln_martyr_per100k_1953##ib0.postcut [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store p3
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "`cutoff'"

    quietly reghdfe college_rate c.ln_martyr_per100k_1953##ib0.postcut [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store p4
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "`cutoff'"

    local outstub "${proj}/result/table/graduation_rates_1990_cutoff`cutoff'_raw_v4"
    esttab p1 p2 p3 p4 using "`outstub'.tex", ///
        replace booktabs nonotes ///
        keep(1.postcut#c.ln_martyr_per100k_1953) ///
        coeflabels(1.postcut#c.ln_martyr_per100k_1953 "Post × War exposure") ///
        mtitles("Primary" "Junior high" "Senior high" "College") ///
        stats(County_FE Cohort_FE Cutoff N r2 ar2, ///
            labels("County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
        se star(* 0.1 ** 0.05 *** 0.01)

    esttab p1 p2 p3 p4 using "`outstub'.rtf", ///
        replace ///
        keep(1.postcut#c.ln_martyr_per100k_1953) ///
        coeflabels(1.postcut#c.ln_martyr_per100k_1953 "Post × War exposure") ///
        mtitles("Primary" "Junior high" "Senior high" "College") ///
        stats(County_FE Cohort_FE Cutoff N r2 ar2, ///
            labels("County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
        se star(* 0.1 ** 0.05 *** 0.01)

    tempfile tmp
    postfile sumhold str4 wave str5 cutoff double b se p n_obs using `tmp', replace
    estimates restore p1
    post sumhold ("1990") ("`cutoff'") (_b[1.postcut#c.ln_martyr_per100k_1953]) (_se[1.postcut#c.ln_martyr_per100k_1953]) ///
        (2*ttail(e(df_r), abs(_b[1.postcut#c.ln_martyr_per100k_1953]/_se[1.postcut#c.ln_martyr_per100k_1953]))) (e(N))
    postclose sumhold
    use `tmp', clear
    export delimited using "`outstub'.csv", replace
    restore
}

exit, clear
