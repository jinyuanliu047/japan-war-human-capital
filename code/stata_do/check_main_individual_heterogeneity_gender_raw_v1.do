*******************************************************
* Individual-level heterogeneity
* Gender: male vs female (1982/1990/2000)
* Raw census chain, cutoff 1940
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

*******************************************************
* helper: resolve old6 -> county_curr6
*******************************************************
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
program define _prep_wave_data
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
    egen county_num = group(countyid_curr6)
end

eststo clear
tempfile gsum
clear
set obs 0
gen str6 wave = ""
gen str12 subgroup = ""
gen double b = .
gen double se = .
gen double p = .
gen double n_obs = .
gen double n_counties = .
save `gsum', replace

local gmodels ""
foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978

    quietly _prep_wave_data, wave(`w') hi(`hi')

    quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control if female==0, absorb(county_num birth_i) vce(cluster county_num)
    estimates store g`w'_male
    estadd local Group "Male"
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar N_counties = e(N_clust)
    local gmodels "`gmodels' g`w'_male"

    local b = _b[1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    use `gsum', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace subgroup = "male" in `n'
    replace b = `b' in `n'
    replace se = `se' in `n'
    replace p = `p' in `n'
    replace n_obs = e(N) in `n'
    replace n_counties = e(N_clust) in `n'
    save `gsum', replace

    quietly _prep_wave_data, wave(`w') hi(`hi')
    quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control if female==1, absorb(county_num birth_i) vce(cluster county_num)
    estimates store g`w'_female
    estadd local Group "Female"
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar N_counties = e(N_clust)
    local gmodels "`gmodels' g`w'_female"

    local b = _b[1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    use `gsum', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace subgroup = "female" in `n'
    replace b = `b' in `n'
    replace se = `se' in `n'
    replace p = `p' in `n'
    replace n_obs = e(N) in `n'
    replace n_counties = e(N_clust) in `n'
    save `gsum', replace
}

use `gsum', clear
export delimited using "${proj}/result/table/main_individual_heterogeneity_gender_raw_v1.csv", replace
save "${proj}/result/table/main_individual_heterogeneity_gender_raw_v1.dta", replace

esttab g1982_male g1982_female g1990_male g1990_female g2000_male g2000_female ///
    using "${proj}/result/table/main_individual_heterogeneity_gender_raw_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 Male" "1982 Female" "1990 Male" "1990 Female" "2000 Male" "2000 Female") ///
    stats(Controls County_FE Cohort_FE N_counties N r2 ar2, ///
        labels("Minority control" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab g1982_male g1982_female g1990_male g1990_female g2000_male g2000_female ///
    using "${proj}/result/table/main_individual_heterogeneity_gender_raw_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 Male" "1982 Female" "1990 Male" "1990 Female" "2000 Male" "2000 Female") ///
    stats(Controls County_FE Cohort_FE N_counties N r2 ar2, ///
        labels("Minority control" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
