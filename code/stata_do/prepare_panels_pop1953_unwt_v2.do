*******************************************************
* Prepare 1982/1990/2000 county-birthyear panels
* - unweighted education mean at micro level
* - treatment denominator uses county pop_1953
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

*******************************************************
* 0) Current county dictionary + 1982 crosswalk
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
* helper block: resolve old6 -> county_curr6
*******************************************************
capture program drop _resolve_old6_map
program define _resolve_old6_map
    * expects data in memory with var old6 (str6), unique old6 rows
    * outputs vars: old6 county_curr6 route
    gen str6 county_curr6 = ""
    gen str30 route = "unmatched"

    * manual successor
    replace county_curr6 = "310101" if old6=="310103"
    replace route = "manual_successor" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace route = "manual_successor" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace route = "manual_successor" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"
    replace route = "manual_successor" if old6=="110010"

    * exact current code
    tempfile left
    save `left'
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6 route_final)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    replace route = "crosswalk_1982" if county_curr6!="" & route=="unmatched"
    drop county_curr6
    drop route_final
    rename curr_res county_curr6
    save `left', replace

    use `left', clear
    rename county_curr6 curr_res
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace curr_res = curr_dict if curr_res=="" & curr_dict!=""
    replace route = "exact_code" if curr_dict!="" & route=="unmatched"
    drop curr_dict
    rename curr_res county_curr6

    * municipality recode for still-unmatched
    gen str6 muni6 = substr(old6,1,2) + "01" + substr(old6,5,2) ///
        if inlist(substr(old6,1,2),"11","12","31") & substr(old6,3,2)=="00" & county_curr6==""

    tempfile mbase
    save `mbase'
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

    * muni -> exact current
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

    * muni -> 1982 crosswalk
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
* 1) Build martyr map (county current 6-digit)
*******************************************************
import delimited "${proj}/data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts_clean_county_fallback.csv", clear varnames(1) stringcols(_all)
gen str6 old6 = substr(place_id,1,6)
keep if regexm(old6, "^[0-9]{6}$")
destring martyr_count, replace force
collapse (sum) martyr_count, by(old6)
tempfile martyr_raw
save `martyr_raw'

use `martyr_raw', clear
_resolve_old6_map
tempfile martyr_map_codes
save `martyr_map_codes'

preserve
    gen one = 1
    collapse (sum) n_codes=one, by(route)
    gsort -n_codes route
    export delimited using "${proj}/data/temp/martyr_code_routes_v2.csv", replace
restore

preserve
    keep if county_curr6==""
    keep old6 route
    rename old6 code6
    export delimited using "${proj}/data/temp/martyr_code_unmatched_v2.csv", replace
restore

merge 1:1 old6 using `martyr_raw', nogen
keep if county_curr6!=""
collapse (sum) martyr_count_1931_1945=martyr_count, by(county_curr6)
tempfile martyr_by_curr
save `martyr_by_curr'

*******************************************************
* 2) Build 1953 population map (county current 6-digit)
*******************************************************
use "${proj}/data/raw/census/1953年县级人口数量.dta", clear
gen str6 old6 = string(county_code, "%06.0f")
keep if regexm(old6, "^[0-9]{6}$")
destring pop_1953, replace force
keep if pop_1953>0 & pop_1953<.
collapse (sum) pop_1953, by(old6)
tempfile pop_raw
save `pop_raw'

use `pop_raw', clear
_resolve_old6_map
tempfile pop_map_codes
save `pop_map_codes'

preserve
    gen one = 1
    collapse (sum) n_codes=one, by(route)
    gsort -n_codes route
    export delimited using "${proj}/data/temp/pop1953_code_routes_v2.csv", replace
restore

preserve
    keep if county_curr6==""
    keep old6 route
    rename old6 code6
    export delimited using "${proj}/data/temp/pop1953_code_unmatched_v2.csv", replace
restore

merge 1:1 old6 using `pop_raw', nogen
keep if county_curr6!=""
collapse (sum) pop_1953, by(county_curr6)
tempfile pop_by_curr
save `pop_by_curr'

*******************************************************
* 3) Treatment table
*******************************************************
use `pop_by_curr', clear
merge 1:1 county_curr6 using `martyr_by_curr'
replace martyr_count_1931_1945 = 0 if missing(martyr_count_1931_1945)
gen ln_martyr_raw = ln(1 + martyr_count_1931_1945)
gen martyr_per100k_1953 = .
replace martyr_per100k_1953 = martyr_count_1931_1945 / pop_1953 * 100000 if pop_1953>0
gen ln_martyr_per100k_1953 = .
replace ln_martyr_per100k_1953 = ln(1 + martyr_per100k_1953) if martyr_per100k_1953<.
rename county_curr6 countyid_curr6
save "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", replace
export delimited using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.csv", replace
tempfile treat
save `treat'

*******************************************************
* 4) 1982 panel (unweighted)
*******************************************************
use countyid birthyr eduy using "${proj}/data/temp/census_1982_cleaned.dta", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
keep if inrange(birthyr,1880,1982)
keep if inrange(eduy,0,25)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using `cw1982', keep(master match) nogen keepusing(county_curr6 route_final)

preserve
    keep if missing(county_curr6)
    if _N>0 {
        keep old6
        duplicates drop old6, force
        gen route = "unmatched"
        rename old6 code6
    }
    else {
        clear
        set obs 0
        gen str6 code6 = ""
        gen str20 route = ""
    }
    export delimited using "${proj}/data/temp/census1982_old6_unmatched_v2.csv", replace
restore

keep if county_curr6!=""
rename county_curr6 countyid_curr6
collapse (count) n_obs=eduy (sum) eduy_sum=eduy, by(countyid_curr6 birthyr)
gen eduy_mean = eduy_sum / n_obs
merge m:1 countyid_curr6 using `treat', keep(master match) nogen
sort countyid_curr6 birthyr
save "${proj}/data/temp/did_1982_county_birthyr_pop1953_unwt_v2.dta", replace
export delimited using "${proj}/data/temp/did_1982_county_birthyr_pop1953_unwt_v2.csv", replace

*******************************************************
* 5) 1990 panel (new census1990.dta, county-level)
*******************************************************
use county age_c age educ using "${proj}/data/raw/census/census1990.dta", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
duplicates drop old6, force
keep old6
_resolve_old6_map
tempfile map1990
save `map1990'

preserve
    gen one = 1
    collapse (sum) n_codes=one, by(route)
    gsort -n_codes route
    export delimited using "${proj}/data/temp/census1990_code_routes_v2.csv", replace
restore

use county age_c age educ using "${proj}/data/raw/census/census1990.dta", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using `map1990', keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""

* birth year reconstruction from two-digit year and century marker.
gen birthyr = 1000 + age_c*100 + age

* education-code to years (assumption based on code ordering).
gen eduy = .
replace eduy = 0  if educ==1
replace eduy = 6  if educ==2
replace eduy = 9  if educ==3
replace eduy = 12 if inlist(educ,4,5)
replace eduy = 15 if educ==6
replace eduy = 16 if educ==7

drop if missing(birthyr) | missing(eduy)
keep if inrange(birthyr,1880,1990)
keep if inrange(eduy,0,25)

rename county_curr6 countyid_curr6
collapse (count) n_obs=eduy (sum) eduy_sum=eduy, by(countyid_curr6 birthyr)
gen eduy_mean = eduy_sum / n_obs
merge m:1 countyid_curr6 using `treat', keep(master match) nogen
sort countyid_curr6 birthyr
save "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta", replace
export delimited using "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.csv", replace

*******************************************************
* 6) 2000 panel (county-level)
*******************************************************
use uid birthyr eduyr using "${proj}/data/raw/census/census2000.dta", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
duplicates drop old6, force
keep old6
_resolve_old6_map
tempfile map2000
save `map2000'

preserve
    gen one = 1
    collapse (sum) n_codes=one, by(route)
    gsort -n_codes route
    export delimited using "${proj}/data/temp/census2000_code_routes_v2.csv", replace
restore

use uid birthyr eduyr using "${proj}/data/raw/census/census2000.dta", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using `map2000', keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""

gen eduy = eduyr
drop if missing(eduy)
keep if inrange(birthyr,1880,2000)
keep if inrange(eduy,0,25)

rename county_curr6 countyid_curr6
collapse (count) n_obs=eduy (sum) eduy_sum=eduy, by(countyid_curr6 birthyr)
gen eduy_mean = eduy_sum / n_obs
merge m:1 countyid_curr6 using `treat', keep(master match) nogen
sort countyid_curr6 birthyr
save "${proj}/data/temp/did_2000_county_birthyr_pop1953_unwt_v2.dta", replace
export delimited using "${proj}/data/temp/did_2000_county_birthyr_pop1953_unwt_v2.csv", replace
