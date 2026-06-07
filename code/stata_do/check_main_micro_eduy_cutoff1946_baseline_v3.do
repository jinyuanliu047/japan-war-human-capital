clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
local p1982 = cond(fileexists("/tmp/census_1982_cleaned_full.dta"), "/tmp/census_1982_cleaned_full.dta", "${proj}/data/temp/census_1982_cleaned.dta")
local p1990 = cond(fileexists("/tmp/census_1990_clean_full.dta"), "/tmp/census_1990_clean_full.dta", "${proj}/data/raw/census_1990_clean.dta")
local p2000 = cond(fileexists("/tmp/census2000_full.dta"), "/tmp/census2000_full.dta", "${proj}/data/raw/census/census2000.dta")

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfejl
if _rc != 0 exit 198

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

use countyid region1990 using "${proj}/data/raw/census_1990_county_char.dta", clear
drop if missing(countyid) | missing(region1990)
rename countyid countyid_1990
gen str6 county_curr6 = string(region1990, "%06.0f")
keep countyid_1990 county_curr6
duplicates drop countyid_1990, force
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

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
drop if countyid_curr6=="" | countyid_curr6=="000000"
duplicates drop countyid_curr6, force
tempfile treat
save `treat'

*******************************************************
* Wave 1982
*******************************************************
use countyid birthyr eduy ethniccn using "`p1982'", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using `cw1982', keep(master match) nogen
keep if county_curr6!=""
gen birth_i = floor(birthyr)
gen minority = (ethniccn!=1) if !missing(ethniccn)
keep if inrange(birth_i, 1920, 1960)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1945
gen post = birth_i >= 1946
rename county_curr6 countyid_curr6
merge m:1 countyid_curr6 using `treat', keep(master match) nogen
egen county_num = group(countyid_curr6)
reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1982
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
quietly egen tag1982 = tag(county_num)
quietly count if tag1982==1
estadd scalar N_counties = r(N)
drop tag1982

*******************************************************
* Wave 1990
*******************************************************
use countyid year_birth yedu han_ethn using "`p1990'", clear
drop if missing(countyid) | missing(year_birth) | missing(yedu)
rename countyid countyid_1990
merge m:1 countyid_1990 using `map1990', keep(master match) nogen
keep if county_curr6!=""
gen birth_i = floor(year_birth)
gen eduy2 = yedu
gen minority = (han_ethn!=1) if !missing(han_ethn)
keep if inrange(birth_i, 1920, 1968)
keep if inrange(eduy2, 0, 25)
drop if birth_i == 1945
gen post = birth_i >= 1946
rename county_curr6 countyid_curr6
merge m:1 countyid_curr6 using `treat', keep(master match) nogen
egen county_num = group(countyid_curr6)
rename eduy2 eduy
reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1990
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
quietly egen tag1990 = tag(county_num)
quietly count if tag1990==1
estadd scalar N_counties = r(N)
drop tag1990

*******************************************************
* Wave 2000
*******************************************************
use uid birthyr eduyr race using "`p2000'", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
keep if inrange(birthyr, 1920, 1978)
drop if floor(birthyr) == 1945
merge m:1 old6 using `map2000', keep(master match) nogen
keep if county_curr6!=""
gen birth_i = floor(birthyr)
gen eduy = eduyr
gen minority = (race!=1) if !missing(race)
keep if inrange(eduy, 0, 25)
rename county_curr6 countyid_curr6
gen post = birth_i >= 1946
merge m:1 countyid_curr6 using `treat', keep(master match) nogen
egen county_num = group(countyid_curr6)
reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) vce(cluster county_num)
estimates store m2000
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
quietly egen tag2000 = tag(county_num)
quietly count if tag2000==1
estadd scalar N_counties = r(N)
drop tag2000

*******************************************************
* Export
*******************************************************
esttab m1982 m1990 m2000 using "${proj}/result/table/main_micro_eduy_cutoff1946_baseline_v3.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982" "1990" "2000") ///
    stats(Controls County_FE Cohort_FE Cutoff N_counties N r2_a, ///
        labels("Individual controls" "County FE" "Cohort FE" "Treatment start" "Counties" "Observations" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

esttab m1982 m1990 m2000 using "${proj}/result/table/main_micro_eduy_cutoff1946_baseline_v3.tex", ///
    replace booktabs nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982" "1990" "2000") ///
    stats(Controls County_FE Cohort_FE Cutoff N_counties N r2_a, ///
        labels("Individual controls" "County FE" "Cohort FE" "Treatment start" "Counties" "Observations" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' str4 wave double b se p N N_counties using "${proj}/result/table/main_micro_eduy_cutoff1946_baseline_v3_tmp.dta", replace

estimates restore m1982
post `memhold' ("1982") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_counties))

estimates restore m1990
post `memhold' ("1990") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_counties))

estimates restore m2000
post `memhold' ("2000") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_counties))

postclose `memhold'
use "${proj}/result/table/main_micro_eduy_cutoff1946_baseline_v3_tmp.dta", clear
export delimited using "${proj}/result/table/main_micro_eduy_cutoff1946_baseline_v3.csv", replace
erase "${proj}/result/table/main_micro_eduy_cutoff1946_baseline_v3_tmp.dta"
