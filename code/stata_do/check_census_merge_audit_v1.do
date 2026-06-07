clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
local p1982 = cond(fileexists("/tmp/census_1982_cleaned_full.dta"), "/tmp/census_1982_cleaned_full.dta", "${proj}/data/temp/census_1982_cleaned.dta")
local p1990 = cond(fileexists("/tmp/census_1990_clean_full.dta"), "/tmp/census_1990_clean_full.dta", "${proj}/data/raw/census_1990_clean.dta")
local p2000 = cond(fileexists("/tmp/census2000_full.dta"), "/tmp/census2000_full.dta", "${proj}/data/raw/census/census2000.dta")

tempname memhold
postfile `memhold' str8 wave str12 sample long raw_obs long matched_obs long final_obs long raw_codes long matched_codes long final_codes using "${proj}/result/table/census_merge_audit_v1_tmp.dta", replace

* 1982
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

use countyid birthyr eduy using "`p1982'", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
keep if inrange(birthyr, 1920, 1960)
drop if floor(birthyr) == 1939
count
local raw_obs_82 = r(N)
quietly levelsof old6, local(c82)
local raw_codes_82 : word count `c82'
merge m:1 old6 using `cw1982'
count if _merge==3
local matched_obs_82 = r(N)
quietly levelsof county_curr6 if _merge==3, local(k82)
local matched_codes_82 : word count `k82'
keep if _merge==3
merge m:1 county_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", keep(master match) nogen keepusing(ln_martyr_per100k_1953)
count
local final_obs_82 = r(N)
quietly levelsof county_curr6, local(f82)
local final_codes_82 : word count `f82'
post `memhold' ("1982") ("indiv1940") (`raw_obs_82') (`matched_obs_82') (`final_obs_82') (`raw_codes_82') (`matched_codes_82') (`final_codes_82')

* 1990
use countyid year_birth yedu using "`p1990'", clear
drop if missing(countyid) | missing(year_birth) | missing(yedu)
rename countyid countyid_1990
keep if inrange(year_birth, 1920, 1968)
drop if floor(year_birth) == 1939
count
local raw_obs_90 = r(N)
quietly levelsof countyid_1990, local(c90)
local raw_codes_90 : word count `c90'
merge m:1 countyid_1990 using "${proj}/data/raw/census_1990_county_char.dta", keep(master match) nogen keepusing(region1990)
gen str6 county_curr6 = string(region1990, "%06.0f")
count
local matched_obs_90 = r(N)
quietly levelsof county_curr6, local(k90)
local matched_codes_90 : word count `k90'
merge m:1 county_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", keep(master match) nogen keepusing(ln_martyr_per100k_1953)
count
local final_obs_90 = r(N)
quietly levelsof county_curr6, local(f90)
local final_codes_90 : word count `f90'
post `memhold' ("1990") ("indiv1940") (`raw_obs_90') (`matched_obs_90') (`final_obs_90') (`raw_codes_90') (`matched_codes_90') (`final_codes_90')

* 2000
import delimited "${proj}/data/temp/countyid_2000_to_current_routes_v1.csv", clear varnames(1) stringcols(_all)
rename county_old6 old6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile map2000
save `map2000'

use uid birthyr eduyr using "`p2000'", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
keep if inrange(birthyr, 1920, 1978)
drop if floor(birthyr) == 1939
count
local raw_obs_00 = r(N)
quietly levelsof old6, local(c00)
local raw_codes_00 : word count `c00'
merge m:1 old6 using `map2000'
count if _merge==3
local matched_obs_00 = r(N)
quietly levelsof county_curr6 if _merge==3, local(k00)
local matched_codes_00 : word count `k00'
keep if _merge==3
merge m:1 county_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", keep(master match) nogen keepusing(ln_martyr_per100k_1953)
count
local final_obs_00 = r(N)
quietly levelsof county_curr6, local(f00)
local final_codes_00 : word count `f00'
post `memhold' ("2000") ("indiv1940") (`raw_obs_00') (`matched_obs_00') (`final_obs_00') (`raw_codes_00') (`matched_codes_00') (`final_codes_00')

postclose `memhold'
use "${proj}/result/table/census_merge_audit_v1_tmp.dta", clear
export delimited using "${proj}/result/table/census_merge_audit_v1.csv", replace
erase "${proj}/result/table/census_merge_audit_v1_tmp.dta"
