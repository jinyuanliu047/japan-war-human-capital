*******************************************************
* Main individual-level robustness: IHS(yedu) and PPML(yedu)
* Mirrors the raw individual baseline design.
* Y variants:
*   1) yedu
*   2) asinh(yedu)
*   3) ppmlhdfe with yedu
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/raw/census/census1990.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

global control "minority"
global c1982 "${proj}/data/temp/census_1982_cleaned.dta"
if fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta") global c1982 "${proj}/data/temp/census_1982_mainvars_v1.dta"

global c1990 "${proj}/data/raw/census/census1990.dta"
if fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta") global c1990 "${proj}/data/temp/census_1990_mainvars_v1.dta"

global c2000 "${proj}/data/raw/census/census2000.dta"
if fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta") global c2000 "${proj}/data/temp/census_2000_mainvars_v1.dta"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

capture which ppmlhdfe
if _rc != 0 ssc install ppmlhdfe, replace

*******************************************************
* County dictionary and crosswalks
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
replace old6 = substr("000000" + old6, strlen("000000" + old6) - 5, 6)
replace county_curr6 = subinstr(county_curr6, ".0", "", .)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6) - 5, 6)
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

*******************************************************
* Treatment
*******************************************************
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

*******************************************************
* Raw map for 1990 and 2000
*******************************************************
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

import delimited "${proj}/data/temp/countyid_2000_to_current_routes_v1.csv", clear varnames(1) stringcols(_all)
rename county_old6 old6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile map2000
save `map2000'
global map2000_tmp "`map2000'"

*******************************************************
* Wave prep helper
*******************************************************
capture program drop _prep_individual_wave
program define _prep_individual_wave
    syntax , WAVE(integer) HI(integer)

    if `wave' == 1982 {
        use countyid birthyr eduy ethniccn using "$c1982", clear
        drop if missing(countyid) | missing(birthyr) | missing(eduy)
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
        keep if county_curr6!=""
        gen birth_i = floor(birthyr)
        gen minority = (ethniccn!=1) if !missing(ethniccn)
        keep if inrange(birth_i, 1920, `hi')
        keep if inrange(eduy, 0, 25)
        drop if birth_i == 1939
        gen post = birth_i >= 1940
        gen yedu = eduy
        merge m:1 county_curr6 using "$treat_tmp", keep(master match) nogen
    }
    else if `wave' == 1990 {
        use county age_c age educ race using "$c1990", clear
        drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
        gen str6 old6 = string(county, "%06.0f")
        merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
        keep if county_curr6!=""
        gen birthyr = 1000 + age_c*100 + age
        gen birth_i = floor(birthyr)
        gen yedu = .
        replace yedu = 0  if educ==1
        replace yedu = 6  if educ==2
        replace yedu = 9  if educ==3
        replace yedu = 12 if inlist(educ,4,5)
        replace yedu = 15 if educ==6
        replace yedu = 16 if educ==7
        gen minority = (race!=1) if !missing(race)
        keep if inrange(birth_i, 1920, `hi')
        keep if inrange(yedu, 0, 25)
        drop if birth_i == 1939
        gen post = birth_i >= 1940
        merge m:1 county_curr6 using "$treat_tmp", keep(master match) nogen
    }
    else if `wave' == 2000 {
        use uid birthyr eduyr race using "$c2000", clear
        drop if missing(uid) | missing(birthyr) | missing(eduyr)
        gen str6 old6 = string(uid, "%06.0f")
        merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
        keep if county_curr6!=""
        gen birth_i = floor(birthyr)
        gen yedu = eduyr
        gen minority = (race!=1) if !missing(race)
        keep if inrange(birth_i, 1920, `hi')
        keep if inrange(yedu, 0, 25)
        drop if birth_i == 1939
        gen post = birth_i >= 1940
        merge m:1 county_curr6 using "$treat_tmp", keep(master match) nogen
    }
    else {
        display as error "Unsupported wave: `wave'"
        exit 198
    }

    egen county_num = group(county_curr6)
    egen tag_county = tag(county_num)
    gen yedu_ihs = asinh(yedu)
    sort county_num birth_i
end

*******************************************************
* Run models
*******************************************************
capture postutil clear
tempfile summary
postfile sumhold str4 wave str12 model str12 outcome double b se p long n_obs n_counties double r2 ar2 pr2 using `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'" == "1990" local hi = 1968
    if "`w'" == "2000" local hi = 1978

    quietly _prep_individual_wave, wave(`w') hi(`hi')

    local est1 = "olsy`w'"
    local est2 = "olsi`w'"
    local est3 = "ppml`w'"

    quietly reghdfe yedu c.ln_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) vce(cluster county_num)
    estimates store `est1'
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar r2 = e(r2)
    estadd scalar ar2 = e(r2_a)
    capture scalar pr2 = e(r2_p)
    if _rc != 0 scalar pr2 = .
    estadd scalar pr2 = pr2
    quietly lincom 1.post#c.ln_martyr_per100k_1953
    local b1 = r(estimate)
    local se1 = r(se)
    local p1 = 2*ttail(e(df_r), abs(r(estimate)/r(se)))
    quietly count if e(sample)
    local nobs1 = r(N)
    quietly count if e(sample) & tag_county==1
    local ncounty1 = r(N)
    post sumhold ("`w'") ("ols") ("yedu") (`b1') (`se1') (`p1') (`nobs1') (`ncounty1') (e(r2)) (e(r2_a)) (pr2)

    quietly reghdfe yedu_ihs c.ln_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) vce(cluster county_num)
    estimates store `est2'
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar r2 = e(r2)
    estadd scalar ar2 = e(r2_a)
    scalar pr2 = .
    estadd scalar pr2 = pr2
    quietly lincom 1.post#c.ln_martyr_per100k_1953
    local b2 = r(estimate)
    local se2 = r(se)
    local p2 = 2*ttail(e(df_r), abs(r(estimate)/r(se)))
    quietly count if e(sample)
    local nobs2 = r(N)
    quietly count if e(sample) & tag_county==1
    local ncounty2 = r(N)
    post sumhold ("`w'") ("ols") ("asinh_yedu") (`b2') (`se2') (`p2') (`nobs2') (`ncounty2') (e(r2)) (e(r2_a)) (.)

    capture noisily ppmlhdfe yedu c.ln_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) cluster(county_num)
    if _rc == 0 {
        estimates store `est3'
        estadd local Controls "Y"
        estadd local County_FE "Y"
        estadd local Cohort_FE "Y"
        scalar pr2 = .
        capture scalar pr2 = e(r2_p)
        if _rc != 0 scalar pr2 = .
        estadd scalar r2 = .
        estadd scalar ar2 = .
        estadd scalar pr2 = pr2
        quietly lincom 1.post#c.ln_martyr_per100k_1953
        local b3 = r(estimate)
        local se3 = r(se)
        local p3 = 2*normal(-abs(r(estimate)/r(se)))
        quietly count if e(sample)
        local nobs3 = r(N)
        quietly count if e(sample) & tag_county==1
        local ncounty3 = r(N)
        post sumhold ("`w'") ("ppml") ("yedu") (`b3') (`se3') (`p3') (`nobs3') (`ncounty3') (.) (.) (pr2)
    }
    else {
        display as error "PPML failed for wave `w' (rc=`_rc'); storing missing values."
        post sumhold ("`w'") ("ppml") ("yedu") (.) (.) (.) (.) (.) (.) (.) (.)
    }

    esttab `est1' `est2' `est3' using "${proj}/result/table/main_individual_ihs_ppml_`w'_v1.tex", ///
        replace ///
        booktabs ///
        nonotes ///
        keep(1.post#c.ln_martyr_per100k_1953) ///
        coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
        mtitles("OLS yedu" "OLS asinh(yedu)" "PPML yedu") ///
        stats(Controls County_FE Cohort_FE N r2 ar2 pr2, ///
            labels("Individual controls" "County FE" "Cohort FE" "Observations" "R-squared" "Adj. R-squared" "Pseudo R-squared")) ///
        se star(* 0.1 ** 0.05 *** 0.01)
}

postclose sumhold
use `summary', clear
sort wave model
export delimited using "${proj}/result/table/main_individual_ihs_ppml_v1_summary.csv", replace
save "${proj}/result/table/main_individual_ihs_ppml_v1_summary.dta", replace

exit, clear
