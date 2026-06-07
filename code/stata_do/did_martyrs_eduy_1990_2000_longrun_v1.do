*******************************************************
* Long-run DID using Census 1990 and 2000 (v1)
* Treatment: native-place martyr intensity (1931-1945)
* Intensity variants:
*   1) ln_martyr_native
*   2) ln_martyr_per100k_pop82
*   3) ln_martyr_per100k_prewar82
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

*******************************************************
* 0) Build treatment at county level
*******************************************************
import delimited "${proj}/data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts_clean_county_fallback.csv", clear varnames(1)

capture confirm string variable place_id
if _rc == 0 {
    gen str24 place_id_s = trim(place_id)
}
else {
    tostring place_id, gen(place_id_s) format(%18.0f) force
    replace place_id_s = trim(place_id_s)
}

destring martyr_count, replace force
replace martyr_count = 0 if missing(martyr_count)
gen str6 county6 = substr(place_id_s, 1, 6)
keep if regexm(county6, "^[0-9]{6}$")
collapse (sum) martyr_count, by(county6)
tempfile martyr_county
save `martyr_county'

use countyid_curr6 birthyr wt_sum using "${proj}/data/temp/did_1982_county_birthyr_martyr_hybrid_v3.dta", clear
capture confirm string variable countyid_curr6
if _rc == 0 {
    gen str6 county6 = substr(trim(countyid_curr6), 1, 6)
}
else {
    tostring countyid_curr6, gen(county6) format(%06.0f) force
}
destring birthyr wt_sum, replace force
collapse (sum) pop82_total=wt_sum, by(county6)
tempfile pop82_total
save `pop82_total'

use countyid_curr6 birthyr wt_sum using "${proj}/data/temp/did_1982_county_birthyr_martyr_hybrid_v3.dta", clear
capture confirm string variable countyid_curr6
if _rc == 0 {
    gen str6 county6 = substr(trim(countyid_curr6), 1, 6)
}
else {
    tostring countyid_curr6, gen(county6) format(%06.0f) force
}
destring birthyr wt_sum, replace force
keep if birthyr <= 1930
collapse (sum) pop82_prewar=wt_sum, by(county6)
merge 1:1 county6 using `pop82_total', nogen
replace pop82_prewar = 0 if missing(pop82_prewar)
tempfile pop82_county
save `pop82_county'

use `pop82_county', clear
merge 1:1 county6 using `martyr_county', keep(1 3) nogen
replace martyr_count = 0 if missing(martyr_count)

gen ln_martyr_native = ln(1 + martyr_count)
gen martyr_per100k_pop82 = .
replace martyr_per100k_pop82 = martyr_count / pop82_total * 100000 if pop82_total > 0
gen ln_martyr_per100k_pop82 = .
replace ln_martyr_per100k_pop82 = ln(1 + martyr_per100k_pop82) if martyr_per100k_pop82 < .

gen martyr_per100k_prewar82 = .
replace martyr_per100k_prewar82 = martyr_count / pop82_prewar * 100000 if pop82_prewar > 0
gen ln_martyr_per100k_prewar82 = .
replace ln_martyr_per100k_prewar82 = ln(1 + martyr_per100k_prewar82) if martyr_per100k_prewar82 < .

rename county6 geoid
tempfile treat_county
save `treat_county'

*******************************************************
* 1) Build treatment at prefecture level for 1990
*******************************************************
use `treat_county', clear
rename geoid county6
gen prov = real(substr(county6, 1, 2))
gen pref2 = real(substr(county6, 3, 2))
gen str5 geoid = string(prov, "%02.0f") + cond(inlist(prov, 11, 12, 31), "000", string(pref2, "%03.0f"))

collapse (sum) martyr_count pop82_total pop82_prewar, by(geoid)
gen ln_martyr_native = ln(1 + martyr_count)
gen martyr_per100k_pop82 = .
replace martyr_per100k_pop82 = martyr_count / pop82_total * 100000 if pop82_total > 0
gen ln_martyr_per100k_pop82 = .
replace ln_martyr_per100k_pop82 = ln(1 + martyr_per100k_pop82) if martyr_per100k_pop82 < .
gen martyr_per100k_prewar82 = .
replace martyr_per100k_prewar82 = martyr_count / pop82_prewar * 100000 if pop82_prewar > 0
gen ln_martyr_per100k_prewar82 = .
replace ln_martyr_per100k_prewar82 = ln(1 + martyr_per100k_prewar82) if martyr_per100k_prewar82 < .

tempfile treat_pref
save `treat_pref'

*******************************************************
* 2) County code dictionary for current map
*******************************************************
import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
keep GBCounty
destring GBCounty, replace force
drop if missing(GBCounty)
gen str6 county_curr6 = string(GBCounty, "%06.0f")
keep county_curr6
duplicates drop county_curr6, force
tempfile curr_county_dict
save `curr_county_dict'

*******************************************************
* 3) Census 2000 panel (county level)
*******************************************************
use uid birthyr eduyr using "${proj}/data/raw/census/census2000.dta", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
keep if inrange(birthyr, 1900, 1965)
keep if inrange(eduyr, 0, 25)

gen str6 county_old6 = string(uid, "%06.0f")
gen str6 county_curr6 = county_old6
replace county_curr6 = "310101" if county_old6 == "310103"
replace county_curr6 = "310106" if county_old6 == "310108"
replace county_curr6 = "310115" if county_old6 == "310119"
replace county_curr6 = "110110" if county_old6 == "110010"
replace county_curr6 = substr(county_old6,1,2) + "01" + substr(county_old6,5,2) ///
    if inlist(substr(county_old6,1,2), "11", "12", "31") & substr(county_old6,3,2) == "00"

merge m:1 county_curr6 using `curr_county_dict'

preserve
keep county_old6 county_curr6 _merge
bys county_old6: keep if _n == 1
gen str30 route = "unmatched"
replace route = "matched_currcode" if _merge == 3
export delimited using "${proj}/data/temp/countyid_2000_to_current_routes_v1.csv", replace
keep if route == "unmatched"
export delimited using "${proj}/data/temp/countyid_2000_to_current_unmatched_v1.csv", replace
restore

keep if _merge == 3
drop _merge

gen wt = 1
gen eduy_w = eduyr * wt
collapse (count) n_obs=eduyr (sum) wt_sum=wt eduy_wsum=eduy_w, by(county_curr6 birthyr)
rename county_curr6 geoid
gen eduy_wmean = eduy_wsum / wt_sum

merge m:1 geoid using `treat_county', keep(1 3) nogen
replace martyr_count = 0 if missing(martyr_count)
replace ln_martyr_native = 0 if missing(ln_martyr_native)

gen postwar_birth_wide = inrange(birthyr, 1946, 1960)
gen sample_postwar_birth_wide = inrange(birthyr, 1931, 1960)
gen postwar_schentry_wide = inrange(birthyr, 1943, 1960)
gen sample_postwar_schentry_wide = inrange(birthyr, 1928, 1960)

order geoid birthyr n_obs wt_sum eduy_wsum eduy_wmean martyr_count ln_martyr_native ///
    martyr_per100k_pop82 ln_martyr_per100k_pop82 martyr_per100k_prewar82 ln_martyr_per100k_prewar82
sort geoid birthyr

export delimited using "${proj}/data/temp/did_2000_county_birthyr_martyr_longrun_v1.csv", replace
save "${proj}/data/temp/did_2000_county_birthyr_martyr_longrun_v1.dta", replace

*******************************************************
* 4) Census 1990 panel (prefecture level)
*******************************************************
use geo2_cn1990 birthyr perwt edattaind educcn using "${proj}/data/raw/census/Census1990#11835947.dta", clear
drop if missing(geo2_cn1990) | missing(birthyr) | missing(perwt)
keep if inrange(birthyr, 1900, 1965)
keep if perwt > 0

gen eduy = .
replace eduy = 2  if edattaind == 100
replace eduy = 0  if edattaind == 110
replace eduy = 3  if edattaind == 120
replace eduy = 4  if edattaind == 130
replace eduy = 5  if edattaind == 211
replace eduy = 6  if edattaind == 212
replace eduy = 9  if inlist(edattaind, 221, 222)
replace eduy = 12 if inlist(edattaind, 311, 320, 321)
replace eduy = 14 if inlist(edattaind, 312, 322)
replace eduy = 16 if edattaind == 400

replace eduy = 0  if missing(eduy) & educcn == 0
replace eduy = 3  if missing(eduy) & inlist(educcn, 10, 11, 12)
replace eduy = 6  if missing(eduy) & educcn == 13
replace eduy = 4  if missing(eduy) & educcn == 19
replace eduy = 8  if missing(eduy) & inlist(educcn, 20, 21, 22, 24, 29)
replace eduy = 9  if missing(eduy) & educcn == 23
replace eduy = 11 if missing(eduy) & inlist(educcn, 30, 31, 32, 34, 35, 36, 38, 39)
replace eduy = 12 if missing(eduy) & inlist(educcn, 33, 37)
replace eduy = 13 if missing(eduy) & inlist(educcn, 41, 42, 61)
replace eduy = 14 if missing(eduy) & inlist(educcn, 40, 43, 44, 58, 60, 62)
replace eduy = 15 if missing(eduy) & educcn == 51
replace eduy = 16 if missing(eduy) & inlist(educcn, 50, 52)

drop if missing(eduy)
keep if inrange(eduy, 0, 25)

gen str5 geoid = string(geo2_cn1990, "%05.0f")
gen eduy_w = eduy * perwt
collapse (count) n_obs=eduy (sum) wt_sum=perwt eduy_wsum=eduy_w, by(geoid birthyr)
gen eduy_wmean = eduy_wsum / wt_sum

merge m:1 geoid using `treat_pref', keep(1 3) nogen
replace martyr_count = 0 if missing(martyr_count)
replace ln_martyr_native = 0 if missing(ln_martyr_native)

gen postwar_birth_wide = inrange(birthyr, 1946, 1960)
gen sample_postwar_birth_wide = inrange(birthyr, 1931, 1960)
gen postwar_schentry_wide = inrange(birthyr, 1943, 1960)
gen sample_postwar_schentry_wide = inrange(birthyr, 1928, 1960)

order geoid birthyr n_obs wt_sum eduy_wsum eduy_wmean martyr_count ln_martyr_native ///
    martyr_per100k_pop82 ln_martyr_per100k_pop82 martyr_per100k_prewar82 ln_martyr_per100k_prewar82
sort geoid birthyr

export delimited using "${proj}/data/temp/did_1990_pref_birthyr_martyr_longrun_v1.csv", replace
save "${proj}/data/temp/did_1990_pref_birthyr_martyr_longrun_v1.dta", replace

*******************************************************
* 5) Regressions: 2000
*******************************************************
use "${proj}/data/temp/did_2000_county_birthyr_martyr_longrun_v1.dta", clear
egen geoid_num = group(geoid)
label var ln_martyr_native "ln(1+martyrs)"
label var ln_martyr_per100k_pop82 "ln(1+martyrs per 100k pop82)"
label var ln_martyr_per100k_prewar82 "ln(1+martyrs per 100k prewar82)"

eststo clear
preserve
keep if sample_postwar_schentry_wide == 1
reghdfe eduy_wmean c.ln_martyr_native##i.postwar_schentry_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y2000_s_lnraw
reghdfe eduy_wmean c.ln_martyr_per100k_pop82##i.postwar_schentry_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y2000_s_lnpop
reghdfe eduy_wmean c.ln_martyr_per100k_prewar82##i.postwar_schentry_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y2000_s_lnpre
restore

preserve
keep if sample_postwar_birth_wide == 1
reghdfe eduy_wmean c.ln_martyr_native##i.postwar_birth_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y2000_b_lnraw
reghdfe eduy_wmean c.ln_martyr_per100k_pop82##i.postwar_birth_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y2000_b_lnpop
reghdfe eduy_wmean c.ln_martyr_per100k_prewar82##i.postwar_birth_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y2000_b_lnpre
restore

esttab y2000_s_lnraw y2000_s_lnpop y2000_s_lnpre using "${proj}/result/table/did_longrun_2000_schoolentry_v1.txt", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) compress title("Census2000: school-entry postwar DID")
esttab y2000_b_lnraw y2000_b_lnpop y2000_b_lnpre using "${proj}/result/table/did_longrun_2000_birth_v1.txt", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) compress title("Census2000: postwar-birth DID")

*******************************************************
* 6) Regressions: 1990
*******************************************************
use "${proj}/data/temp/did_1990_pref_birthyr_martyr_longrun_v1.dta", clear
egen geoid_num = group(geoid)
label var ln_martyr_native "ln(1+martyrs)"
label var ln_martyr_per100k_pop82 "ln(1+martyrs per 100k pop82)"
label var ln_martyr_per100k_prewar82 "ln(1+martyrs per 100k prewar82)"

eststo clear
preserve
keep if sample_postwar_schentry_wide == 1
reghdfe eduy_wmean c.ln_martyr_native##i.postwar_schentry_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y1990_s_lnraw
reghdfe eduy_wmean c.ln_martyr_per100k_pop82##i.postwar_schentry_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y1990_s_lnpop
reghdfe eduy_wmean c.ln_martyr_per100k_prewar82##i.postwar_schentry_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y1990_s_lnpre
restore

preserve
keep if sample_postwar_birth_wide == 1
reghdfe eduy_wmean c.ln_martyr_native##i.postwar_birth_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y1990_b_lnraw
reghdfe eduy_wmean c.ln_martyr_per100k_pop82##i.postwar_birth_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y1990_b_lnpop
reghdfe eduy_wmean c.ln_martyr_per100k_prewar82##i.postwar_birth_wide [aw=wt_sum], absorb(geoid_num birthyr) vce(cluster geoid_num)
eststo y1990_b_lnpre
restore

esttab y1990_s_lnraw y1990_s_lnpop y1990_s_lnpre using "${proj}/result/table/did_longrun_1990_schoolentry_v1.txt", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) compress title("Census1990: school-entry postwar DID (prefecture level)")
esttab y1990_b_lnraw y1990_b_lnpop y1990_b_lnpre using "${proj}/result/table/did_longrun_1990_birth_v1.txt", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) compress title("Census1990: postwar-birth DID (prefecture level)")
