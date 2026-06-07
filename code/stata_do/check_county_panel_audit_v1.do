clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture postutil clear
tempname memhold
postfile `memhold' str32 source str16 stage double obs old6_unique curr6_unique birth_min birth_max using "${proj}/result/table/county_panel_audit_v1_tmp.dta", replace

capture program drop _post_counts
program define _post_counts
    syntax , SOURCE(string) STAGE(string) [OLDVAR(name) CURRVAR(name) BIRTHVAR(name)]

    quietly count
    local obs = r(N)

    local oldn = .
    local currn = .
    local bmin = .
    local bmax = .

    if "`oldvar'" != "" {
        capture confirm variable `oldvar'
        if _rc == 0 {
            preserve
                keep `oldvar'
                drop if missing(`oldvar')
                duplicates drop `oldvar', force
                quietly count
                local oldn = r(N)
            restore
        }
    }

    if "`currvar'" != "" {
        capture confirm variable `currvar'
        if _rc == 0 {
            preserve
                keep `currvar'
                drop if missing(`currvar')
                duplicates drop `currvar', force
                quietly count
                local currn = r(N)
            restore
        }
    }

    if "`birthvar'" != "" {
        capture confirm variable `birthvar'
        if _rc == 0 {
            quietly summarize `birthvar', meanonly
            local bmin = r(min)
            local bmax = r(max)
        }
    }

    post `memhold' ("`source'") ("`stage'") (`obs') (`oldn') (`currn') (`bmin') (`bmax')
end

*******************************************************
* 1) Raw 1990 census route used by prepare_panels_pop1953_unwt_v2.do
*******************************************************
use county age_c age educ using "${proj}/data/raw/census/census1990.dta", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
gen birthyr = 1000 + age_c*100 + age
_post_counts, source("raw1990_county") stage("raw_loaded") oldvar(old6) birthvar(birthyr)

preserve
    keep old6
    duplicates drop old6, force

    tempfile county_dict
    import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
    keep GBCounty
    destring GBCounty, replace force
    drop if missing(GBCounty)
    gen str6 old6 = string(GBCounty, "%06.0f")
    gen str6 curr_dict = old6
    keep old6 curr_dict
    duplicates drop old6, force
    save `county_dict'

    tempfile cw1982
    import delimited "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", clear varnames(1) stringcols(_all)
    rename countyid_old6 old6
    rename countyid_curr6_final county_curr6
    replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
    replace county_curr6 = subinstr(county_curr6, ".0", "", .)
    replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
    keep old6 county_curr6
    drop if old6=="" | county_curr6==""
    duplicates drop old6, force
    save `cw1982'

    use county age_c age educ using "${proj}/data/raw/census/census1990.dta", clear
    drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
    gen str6 old6 = string(county, "%06.0f")
    gen birthyr = 1000 + age_c*100 + age
    keep old6 birthyr

    tempfile left
    save `left'

    preserve
        keep old6
        duplicates drop old6, force
        gen str6 county_curr6 = ""
        merge 1:1 old6 using `cw1982', keep(master match) nogen
        replace county_curr6 = county_curr6 if county_curr6!=""
        tempfile map1
        save `map1'
    restore

restore

use county age_c age educ using "${proj}/data/raw/census/census1990.dta", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
gen birthyr = 1000 + age_c*100 + age

tempfile map1990char
use countyid region1990 using "${proj}/data/raw/census_1990_county_char.dta", clear
drop if missing(countyid) | missing(region1990)
rename countyid code1990
gen str6 old6 = string(code1990, "%06.0f")
gen str6 county_curr6 = string(region1990, "%06.0f")
keep old6 county_curr6
duplicates drop old6, force
save `map1990char'

use county age_c age educ using "${proj}/data/raw/census/census1990.dta", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
gen birthyr = 1000 + age_c*100 + age
merge m:1 old6 using `map1990char', keep(master match) nogen
_post_counts, source("raw1990_county") stage("mapped_char") oldvar(old6) currvar(county_curr6) birthvar(birthyr)

*******************************************************
* 2) Clean 1990 census route used by many later scripts
*******************************************************
use countyid region1990 using "${proj}/data/raw/census_1990_county_char.dta", clear
drop if missing(countyid) | missing(region1990)
rename countyid countyid_1990
gen str6 county_curr6 = string(region1990, "%06.0f")
keep countyid_1990 county_curr6
duplicates drop countyid_1990, force
tempfile clean1990map
save `clean1990map'

use countyid year_birth yedu using "${proj}/data/raw/census_1990_clean.dta", clear
drop if missing(countyid) | missing(year_birth) | missing(yedu)
rename countyid countyid_1990
_post_counts, source("clean1990_micro") stage("raw_loaded") oldvar(countyid_1990) birthvar(year_birth)

merge m:1 countyid_1990 using `clean1990map', keep(master match) nogen
_post_counts, source("clean1990_micro") stage("mapped_char") oldvar(countyid_1990) currvar(county_curr6) birthvar(year_birth)

*******************************************************
* 3) Existing county panels
*******************************************************
use "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta", clear
_post_counts, source("did_1990_pop1953") stage("existing_panel") currvar(countyid_curr6) birthvar(birthyr)

use "${proj}/data/temp/county_y_panel_1990_v4.dta", clear
_post_counts, source("county_y_1990_v4") stage("existing_panel") currvar(countyid_curr6) birthvar(birth_i)

use "${proj}/data/temp/county_y_panel_1990_v5.dta", clear
_post_counts, source("county_y_1990_v5") stage("existing_panel") currvar(countyid_curr6) birthvar(birth_i)

*******************************************************
* 4) Export
*******************************************************
postclose `memhold'
use "${proj}/result/table/county_panel_audit_v1_tmp.dta", clear
sort source stage
export delimited using "${proj}/result/table/county_panel_audit_v1.csv", replace
save "${proj}/result/table/county_panel_audit_v1.dta", replace
erase "${proj}/result/table/county_panel_audit_v1_tmp.dta"

list, clean noobs
exit, clear
