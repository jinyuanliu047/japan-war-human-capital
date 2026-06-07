*******************************************************
* Individual-level heterogeneity
* 1) Gender: male vs female (1982/1990/2000)
* 2) Urban-Rural: 1990/2000
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "minority"

capture which esttab
if _rc != 0 {
    ssc install estout, replace
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

*******************************************************
* helper: resolve old6 -> county_curr6
*******************************************************
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
* treatment
*******************************************************
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
duplicates drop countyid_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

*******************************************************
* mapping files for 1990 / 2000
*******************************************************
use county age_c age educ using "${proj}/data/raw/census/census1990.dta", clear
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

use uid birthyr eduyr using "${proj}/data/raw/census/census2000.dta", clear
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

*******************************************************
* helper: prepare one wave individual data
*******************************************************
capture program drop _prep_wave_data
program define _prep_wave_data
    syntax , WAVE(integer) HI(integer)

    if `wave' == 1982 {
        use countyid birthyr eduy sex ethniccn using "${proj}/data/temp/census_1982_cleaned.dta", clear
        drop if missing(countyid) | missing(birthyr) | missing(eduy)
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen female = (sex==2) if !missing(sex)
        gen minority = (ethniccn!=1) if !missing(ethniccn)
        gen urban_tag = .
        gen rural_tag = .
    }

    if `wave' == 1990 {
        use county age_c age educ sex race regstatu using "${proj}/data/raw/census/census1990.dta", clear
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

        gen female = (sex==2) if !missing(sex)
        gen minority = (race!=1) if !missing(race)
        * 1990 urban-rural coding follows regstatu split used in census tabulations
        gen urban_tag = inlist(regstatu,1,2) if !missing(regstatu)
        gen rural_tag = inlist(regstatu,3,4,5) if !missing(regstatu)
    }

    if `wave' == 2000 {
        use uid birthyr eduyr sex race urban rural using "${proj}/data/raw/census/census2000.dta", clear
        drop if missing(uid) | missing(birthyr) | missing(eduyr)
        gen str6 old6 = string(uid, "%06.0f")
        merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6

        gen eduy = eduyr
        gen female = (sex==2) if !missing(sex)
        gen minority = (race!=1) if !missing(race)
        gen urban_tag = (urban==1) if !missing(urban)
        gen rural_tag = (rural==1) if !missing(rural)
    }

    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    drop if missing(eduy)
    keep if inrange(eduy,0,25)

    merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen

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
gen b = .
gen se = .
gen p = .
save `gsum', replace

*******************************************************
* Gender heterogeneity: all three waves
*******************************************************
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
    save `gsum', replace

    quietly _prep_wave_data, wave(`w') hi(`hi')
    quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control if female==1, absorb(county_num birth_i) vce(cluster county_num)
    estimates store g`w'_female
    estadd local Group "Female"
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"

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
    save `gsum', replace
}

use `gsum', clear
export delimited using "${proj}/result/table/main_individual_heterogeneity_gender_summary_v1.csv", replace
save "${proj}/result/table/main_individual_heterogeneity_gender_summary_v1.dta", replace

esttab g1982_male g1982_female g1990_male g1990_female g2000_male g2000_female ///
    using "${proj}/result/table/main_individual_heterogeneity_gender_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab g1982_male g1982_female g1990_male g1990_female g2000_male g2000_female ///
    using "${proj}/result/table/main_individual_heterogeneity_gender_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Urban-rural heterogeneity: 1990 + 2000
*******************************************************

tempfile usum
clear
set obs 0
gen str6 wave = ""
gen str12 subgroup = ""
gen b = .
gen se = .
gen p = .
save `usum', replace

foreach w in 1990 2000 {
    local hi = 1968
    if "`w'"=="2000" local hi = 1978

    quietly _prep_wave_data, wave(`w') hi(`hi')
    quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post female minority if urban_tag==1, absorb(county_num birth_i) vce(cluster county_num)
    estimates store u`w'_urban
    estadd local Group "Urban"
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"

    local b = _b[1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    use `usum', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace subgroup = "urban" in `n'
    replace b = `b' in `n'
    replace se = `se' in `n'
    replace p = `p' in `n'
    save `usum', replace

    quietly _prep_wave_data, wave(`w') hi(`hi')
    quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post female minority if rural_tag==1, absorb(county_num birth_i) vce(cluster county_num)
    estimates store u`w'_rural
    estadd local Group "Rural"
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"

    local b = _b[1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    use `usum', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace subgroup = "rural" in `n'
    replace b = `b' in `n'
    replace se = `se' in `n'
    replace p = `p' in `n'
    save `usum', replace
}

use `usum', clear
export delimited using "${proj}/result/table/main_individual_heterogeneity_urbanrural_summary_v1.csv", replace
save "${proj}/result/table/main_individual_heterogeneity_urbanrural_summary_v1.dta", replace

esttab u1990_urban u1990_rural u2000_urban u2000_rural ///
    using "${proj}/result/table/main_individual_heterogeneity_urbanrural_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab u1990_urban u1990_rural u2000_urban u2000_rural ///
    using "${proj}/result/table/main_individual_heterogeneity_urbanrural_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
