*******************************************************
* Raw individual-level functional-form robustness
* Outcome: yedu
* Estimators: reghdfe / ppmlhdfe
* Treatment forms: ln and IHS
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/raw/census/census1990.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"
global control "minority"
global c1982 "${proj}/data/temp/census_1982_mainvars_v1.dta"
if !fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta") global c1982 "${proj}/data/temp/census_1982_cleaned.dta"
global c1990 "${proj}/data/temp/census_1990_mainvars_v1.dta"
if !fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta") global c1990 "${proj}/data/raw/census/census1990.dta"
global c2000 "${proj}/data/temp/census_2000_mainvars_v1.dta"
if !fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta") global c2000 "${proj}/data/raw/census/census2000.dta"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfe
if _rc != 0 ssc install reghdfe, replace
capture which ppmlhdfe
if _rc != 0 ssc install ppmlhdfe, replace

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
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'
global cw1982_tmp "`cw1982'"

capture program drop _resolve_old6_map
program define _resolve_old6_map
    gen str6 county_curr6 = ""
    replace county_curr6 = "310101" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"

    tempfile left
    save `left'
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    drop county_curr6
    rename curr_res county_curr6
    save `left', replace

    use `left', clear
    rename county_curr6 curr_res
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace curr_res = curr_dict if curr_res=="" & curr_dict!=""
    drop curr_dict
    rename curr_res county_curr6

    gen str6 muni6 = substr(old6,1,2) + "01" + substr(old6,5,2) ///
        if inlist(substr(old6,1,2),"11","12","31") & substr(old6,3,2)=="00" & county_curr6==""

    tempfile muni_exact
    preserve
        keep if muni6!="" & county_curr6==""
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
    restore

    merge 1:1 old6 using `muni_exact', keep(master match) nogen
    replace county_curr6 = curr_from_muni_exact if county_curr6=="" & curr_from_muni_exact!=""
    drop curr_from_muni_exact
    drop muni6
end

*******************************************************
* treatment
*******************************************************
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile treat
save `treat'

*******************************************************
* mapping files for 1990 / 2000
*******************************************************
use county using "$c1990", clear
drop if missing(county)
gen str6 old6 = string(county, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map1990
save `map1990'

use uid using "$c2000", clear
drop if missing(uid)
gen str6 old6 = string(uid, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map2000
save `map2000'

*******************************************************
* helper: prepare one wave individual data
*******************************************************
capture program drop _prep_wave_data
program define _prep_wave_data, rclass
    syntax , WAVE(integer) HI(integer)

    if `wave' == 1982 {
        use countyid birthyr eduy sex ethniccn using "$c1982", clear
        drop if missing(countyid) | missing(birthyr) | missing(eduy)
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen female = (sex==2) if !missing(sex)
        gen minority = (ethniccn!=1) if !missing(ethniccn)
    }

    if `wave' == 1990 {
        use county age_c age educ sex race using "$c1990", clear
        drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
        gen str6 old6 = string(county, "%06.0f")
        merge m:1 old6 using "$map1990", keep(master match) nogen
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
        gen female = (sex==2) if !missing(sex)
        gen minority = (race!=1) if !missing(race)
    }

    if `wave' == 2000 {
        use uid birthyr eduyr sex race using "$c2000", clear
        drop if missing(uid) | missing(birthyr) | missing(eduyr)
        gen str6 old6 = string(uid, "%06.0f")
        merge m:1 old6 using "$map2000", keep(master match) nogen
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen eduy = eduyr
        gen female = (sex==2) if !missing(sex)
        gen minority = (race!=1) if !missing(race)
    }

    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    drop if missing(eduy)
    keep if inrange(eduy,0,25)

    merge m:1 countyid_curr6 using "$treat", keep(master match) nogen
    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    gen ihs_martyr_per100k_1953 = asinh(martyr_per100k_1953)
    egen county_num = group(countyid_curr6)
end

*******************************************************
* wave-specific models
*******************************************************
tempfile summary
clear
set obs 0
gen str4 wave = ""
gen str8 estimator = ""
gen str6 xform = ""
gen double b = .
gen double se = .
gen double p = .
gen double n_obs = .
gen double n_counties = .
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978

    quietly _prep_wave_data, wave(`w') hi(`hi')
    quietly areg yedu c.ln_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) vce(cluster county_num)
    estimates store olsln`w'
    estadd local Estimator "OLS"
    estadd local XForm "ln"
    estadd scalar N_counties = e(N_clust)
    local b1 = _b[1.post#c.ln_martyr_per100k_1953]
    local se1 = _se[1.post#c.ln_martyr_per100k_1953]
    local p1 = 2*ttail(e(df_r), abs(`b1'/`se1'))
    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace estimator = "OLS" in `n'
    replace xform = "ln" in `n'
    replace b = `b1' in `n'
    replace se = `se1' in `n'
    replace p = `p1' in `n'
    replace n_obs = e(N) in `n'
    replace n_counties = e(N_clust) in `n'
    save `summary', replace

    quietly _prep_wave_data, wave(`w') hi(`hi')
    quietly areg yedu c.ihs_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) vce(cluster county_num)
    estimates store olsihs`w'
    estadd local Estimator "OLS"
    estadd local XForm "ihs"
    estadd scalar N_counties = e(N_clust)
    local b2 = _b[1.post#c.ihs_martyr_per100k_1953]
    local se2 = _se[1.post#c.ihs_martyr_per100k_1953]
    local p2 = 2*ttail(e(df_r), abs(`b2'/`se2'))
    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace estimator = "OLS" in `n'
    replace xform = "ihs" in `n'
    replace b = `b2' in `n'
    replace se = `se2' in `n'
    replace p = `p2' in `n'
    replace n_obs = e(N) in `n'
    replace n_counties = e(N_clust) in `n'
    save `summary', replace

    quietly _prep_wave_data, wave(`w') hi(`hi')
    quietly ppmlhdfe yedu c.ln_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) cluster(county_num)
    estimates store ppmlln`w'
    estadd local Estimator "PPML"
    estadd local XForm "ln"
    estadd scalar N_counties = e(N_clust)
    local b3 = _b[1.post#c.ln_martyr_per100k_1953]
    local se3 = _se[1.post#c.ln_martyr_per100k_1953]
    local p3 = 2*normal(-abs(`b3'/`se3'))
    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace estimator = "PPML" in `n'
    replace xform = "ln" in `n'
    replace b = `b3' in `n'
    replace se = `se3' in `n'
    replace p = `p3' in `n'
    replace n_obs = e(N) in `n'
    replace n_counties = e(N_clust) in `n'
    save `summary', replace

    quietly _prep_wave_data, wave(`w') hi(`hi')
    quietly ppmlhdfe yedu c.ihs_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) cluster(county_num)
    estimates store ppmlihs`w'
    estadd local Estimator "PPML"
    estadd local XForm "ihs"
    estadd scalar N_counties = e(N_clust)
    local b4 = _b[1.post#c.ihs_martyr_per100k_1953]
    local se4 = _se[1.post#c.ihs_martyr_per100k_1953]
    local p4 = 2*normal(-abs(`b4'/`se4'))
    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace estimator = "PPML" in `n'
    replace xform = "ihs" in `n'
    replace b = `b4' in `n'
    replace se = `se4' in `n'
    replace p = `p4' in `n'
    replace n_obs = e(N) in `n'
    replace n_counties = e(N_clust) in `n'
    save `summary', replace

    if "`w'" == "1982" {
        esttab olsln1982 olsihs1982 ppmlln1982 ppmlihs1982 using "${proj}/result/table/main_individual_ihs_ppml_raw_1982_v1.tex", ///
            replace booktabs nonotes ///
            keep(1.post#c.ln_martyr_per100k_1953 1.post#c.ihs_martyr_per100k_1953) ///
            coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure" 1.post#c.ihs_martyr_per100k_1953 "Post × War exposure") ///
            mtitles("OLS ln" "OLS IHS" "PPML ln" "PPML IHS") ///
            stats(Estimator XForm N_counties N r2 ar2, ///
                labels("Estimator" "X transformation" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
            se star(* 0.1 ** 0.05 *** 0.01)
    }
    if "`w'" == "1990" {
        esttab olsln1990 olsihs1990 ppmlln1990 ppmlihs1990 using "${proj}/result/table/main_individual_ihs_ppml_raw_1990_v1.tex", ///
            replace booktabs nonotes ///
            keep(1.post#c.ln_martyr_per100k_1953 1.post#c.ihs_martyr_per100k_1953) ///
            coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure" 1.post#c.ihs_martyr_per100k_1953 "Post × War exposure") ///
            mtitles("OLS ln" "OLS IHS" "PPML ln" "PPML IHS") ///
            stats(Estimator XForm N_counties N r2 ar2, ///
                labels("Estimator" "X transformation" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
            se star(* 0.1 ** 0.05 *** 0.01)
    }
    if "`w'" == "2000" {
        esttab olsln2000 olsihs2000 ppmlln2000 ppmlihs2000 using "${proj}/result/table/main_individual_ihs_ppml_raw_2000_v1.tex", ///
            replace booktabs nonotes ///
            keep(1.post#c.ln_martyr_per100k_1953 1.post#c.ihs_martyr_per100k_1953) ///
            coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure" 1.post#c.ihs_martyr_per100k_1953 "Post × War exposure") ///
            mtitles("OLS ln" "OLS IHS" "PPML ln" "PPML IHS") ///
            stats(Estimator XForm N_counties N r2 ar2, ///
                labels("Estimator" "X transformation" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
            se star(* 0.1 ** 0.05 *** 0.01)
    }
}

use `summary', clear
export delimited using "${proj}/result/table/main_individual_ihs_ppml_raw_summary_v1.csv", replace
save "${proj}/result/table/main_individual_ihs_ppml_raw_summary_v1.dta", replace

exit, clear
