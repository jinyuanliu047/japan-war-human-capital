*******************************************************
* Summary statistics for main individual census samples
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/raw/census/census1990.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace

local c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
local c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
local c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")

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
    capture merge 1:1 old6 using `muni_exact', keep(master match) nogen
    capture replace county_curr6 = curr_from_muni_exact if county_curr6=="" & curr_from_muni_exact!=""
    capture drop curr_from_muni_exact muni6
end

*******************************************************
* treatment and maps
*******************************************************
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile treat
save `treat'

use county age_c age educ using "`c1990'", clear
drop if missing(county)
gen str6 old6 = string(county, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map1990
save `map1990'

import delimited "${proj}/data/temp/countyid_2000_to_current_routes_v1.csv", clear varnames(1) stringcols(_all)
rename county_old6 old6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile map2000
save `map2000'

*******************************************************
* 1982
*******************************************************
use countyid birthyr eduy ethniccn using "`c1982'", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using `cw1982', keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen birth_i = floor(birthyr)
gen minority = (ethniccn!=1) if !missing(ethniccn)
keep if inrange(birth_i, 1920, 1960)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1939
gen post = birth_i >= 1940
merge m:1 county_curr6 using `treat', keep(master match) nogen
egen county_num = group(county_curr6)
egen tag1982 = tag(county_num)
count if tag1982==1
local ncounty1982 = r(N)
drop tag1982
label var eduy "Years of education"
    label var minority "Minority"
    label var post "Post-war cohort"
    label var ln_martyr_per100k_1953 "Log war exposure"
    quietly count if !missing(eduy, minority, post, ln_martyr_per100k_1953)
    local nobs1982 = r(N)
    quietly summarize eduy, meanonly
    local mean1982 = r(mean)
    estpost summarize eduy minority post ln_martyr_per100k_1953
    eststo s1982
    estadd scalar Observations = `nobs1982'
    estadd scalar Counties = `ncounty1982'

*******************************************************
* 1990
*******************************************************
use county age_c age educ race using "`c1990'", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using `map1990', keep(master match) nogen
keep if county_curr6!=""
gen birthyr = 1000 + age_c*100 + age
gen birth_i = floor(birthyr)
gen eduy = .
replace eduy = 0  if educ==1
replace eduy = 6  if educ==2
replace eduy = 9  if educ==3
replace eduy = 12 if inlist(educ,4,5)
replace eduy = 15 if educ==6
replace eduy = 16 if educ==7
gen minority = (race!=1) if !missing(race)
keep if inrange(birth_i, 1920, 1968)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1939
gen post = birth_i >= 1940
merge m:1 county_curr6 using `treat', keep(master match) nogen
egen county_num = group(county_curr6)
egen tag1990 = tag(county_num)
count if tag1990==1
local ncounty1990 = r(N)
drop tag1990
label var eduy "Years of education"
    label var minority "Minority"
    label var post "Post-war cohort"
    label var ln_martyr_per100k_1953 "Log war exposure"
    quietly count if !missing(eduy, minority, post, ln_martyr_per100k_1953)
    local nobs1990 = r(N)
    quietly summarize eduy, meanonly
    local mean1990 = r(mean)
    estpost summarize eduy minority post ln_martyr_per100k_1953
    eststo s1990
    estadd scalar Observations = `nobs1990'
    estadd scalar Counties = `ncounty1990'

*******************************************************
* 2000
*******************************************************
use uid birthyr eduyr race using "`c2000'", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using `map2000', keep(master match) nogen
keep if county_curr6!=""
gen birth_i = floor(birthyr)
gen eduy = eduyr
gen minority = (race!=1) if !missing(race)
keep if inrange(birth_i, 1920, 1978)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1939
gen post = birth_i >= 1940
merge m:1 county_curr6 using `treat', keep(master match) nogen
egen county_num = group(county_curr6)
egen tag2000 = tag(county_num)
count if tag2000==1
local ncounty2000 = r(N)
drop tag2000
label var eduy "Years of education"
    label var minority "Minority"
    label var post "Post-war cohort"
    label var ln_martyr_per100k_1953 "Log war exposure"
    quietly count if !missing(eduy, minority, post, ln_martyr_per100k_1953)
    local nobs2000 = r(N)
    quietly summarize eduy, meanonly
    local mean2000 = r(mean)
    estpost summarize eduy minority post ln_martyr_per100k_1953
    eststo s2000
    estadd scalar Observations = `nobs2000'
    estadd scalar Counties = `ncounty2000'

*******************************************************
* table
*******************************************************
esttab s1982 s1990 s2000 using "${proj}/result/table/summary_statistics_main_v1.tex", ///
    replace booktabs nonotes label ///
    cells("mean(fmt(3)) sd(par fmt(3))") ///
    mtitles("1982" "1990" "2000") ///
    stats(Observations Counties, labels("Observations" "Counties"))

esttab s1982 s1990 s2000 using "${proj}/result/table/summary_statistics_main_v1.rtf", ///
    replace label ///
    cells("mean(fmt(3)) sd(par fmt(3))") ///
    mtitles("1982" "1990" "2000") ///
    stats(Observations Counties, labels("Observations" "Counties"))

*******************************************************
* simple summary figure
*******************************************************
preserve
    use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
    keep countyid_curr6 ln_martyr_per100k_1953
    drop if missing(ln_martyr_per100k_1953)
    histogram ln_martyr_per100k_1953, color(navy%40) lcolor(navy) ///
        xtitle("Log war exposure") ytitle("Counties") ///
        title("A. County war-exposure distribution", size(medsmall)) ///
        name(g1, replace)
restore

clear
set obs 3
gen str4 wave = ""
gen mean_yedu = .
replace wave = "1982" in 1
replace wave = "1990" in 2
replace wave = "2000" in 3
replace mean_yedu = `mean1982' in 1
replace mean_yedu = `mean1990' in 2
replace mean_yedu = `mean2000' in 3
graph bar mean_yedu, over(wave) bar(1, color(maroon%70)) ///
    ytitle("Mean years of education") ///
    title("B. Mean education by census wave", size(medsmall)) ///
    name(g2, replace)
graph combine g1 g2, cols(2) graphregion(color(white)) name(gall, replace)
graph export "${proj}/result/figure/summary_statistics_main_v1.pdf", replace
graph export "${proj}/result/figure/summary_statistics_main_v1.png", replace width(2400)

exit, clear
