clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

tempname memhold
postfile `memhold' str30 stage double obs counties birth_min birth_max using "${proj}/result/table/mapping_1990_audit_v1_tmp.dta", replace

capture program drop _post_stage
program define _post_stage
    syntax , STAGE(string) COUNTYVAR(name) BIRTHVAR(name)
    quietly count
    local obs = r(N)
    quietly summarize `birthvar', meanonly
    local bmin = r(min)
    local bmax = r(max)
    preserve
        keep `countyvar'
        drop if missing(`countyvar')
        duplicates drop `countyvar', force
        quietly count
        local counties = r(N)
    restore
    post `memhold' ("`stage'") (`obs') (`counties') (`bmin') (`bmax')
end

use countyid year_birth yedu han_ethn using "${proj}/data/raw/census_1990_clean.dta", clear
drop if missing(countyid) | missing(year_birth) | missing(yedu)
rename countyid countyid_1990
gen birth_i = floor(year_birth)
keep if inrange(birth_i, 1920, 1968)
drop if birth_i == 1939
_post_stage, stage("clean_loaded") countyvar(countyid_1990) birthvar(birth_i)

use countyid region1990 using "${proj}/data/raw/census_1990_county_char.dta", clear
drop if missing(countyid) | missing(region1990)
rename countyid countyid_1990
gen str6 countyid_curr6 = string(region1990, "%06.0f")
keep countyid_1990 countyid_curr6
duplicates drop countyid_1990, force
tempfile map1990
save `map1990'

use countyid year_birth yedu han_ethn using "${proj}/data/raw/census_1990_clean.dta", clear
drop if missing(countyid) | missing(year_birth) | missing(yedu)
rename countyid countyid_1990
gen birth_i = floor(year_birth)
keep if inrange(birth_i, 1920, 1968)
drop if birth_i == 1939
merge m:1 countyid_1990 using `map1990', keep(master match) nogen
drop if countyid_curr6==""
_post_stage, stage("mapped_curr6") countyvar(countyid_curr6) birthvar(birth_i)

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
drop if countyid_curr6=="" | countyid_curr6=="000000"
duplicates drop countyid_curr6, force
tempfile treat
save `treat'

use countyid year_birth yedu han_ethn using "${proj}/data/raw/census_1990_clean.dta", clear
drop if missing(countyid) | missing(year_birth) | missing(yedu)
rename countyid countyid_1990
gen birth_i = floor(year_birth)
keep if inrange(birth_i, 1920, 1968)
drop if birth_i == 1939
merge m:1 countyid_1990 using `map1990', keep(master match) nogen
drop if countyid_curr6==""
merge m:1 countyid_curr6 using `treat', keep(master match) nogen
_post_stage, stage("matched_treat") countyvar(countyid_curr6) birthvar(birth_i)

use "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta", clear
gen birth_i = floor(birthyr)
keep if inrange(birth_i, 1920, 1968)
drop if birth_i == 1939
_post_stage, stage("existing_did_panel") countyvar(countyid_curr6) birthvar(birth_i)

use "${proj}/data/temp/county_y_panel_1990_v5.dta", clear
keep if inrange(birth_i, 1920, 1968)
drop if birth_i == 1939
_post_stage, stage("existing_y_panel_v5") countyvar(countyid_curr6) birthvar(birth_i)

postclose `memhold'
use "${proj}/result/table/mapping_1990_audit_v1_tmp.dta", clear
export delimited using "${proj}/result/table/mapping_1990_audit_v1.csv", replace
save "${proj}/result/table/mapping_1990_audit_v1.dta", replace
erase "${proj}/result/table/mapping_1990_audit_v1_tmp.dta"
list, clean noobs
exit, clear
