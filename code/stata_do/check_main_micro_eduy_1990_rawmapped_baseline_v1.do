clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which areg
if _rc != 0 exit 198

use countyid region1990 using "${proj}/data/raw/census_1990_county_char.dta", clear
drop if missing(countyid) | missing(region1990)
gen str6 old6 = string(countyid, "%06.0f")
gen str6 countyid_curr6 = string(region1990, "%06.0f")
keep old6 countyid_curr6
duplicates drop old6, force
tempfile map1990
save `map1990'

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
drop if countyid_curr6=="" | countyid_curr6=="000000"
duplicates drop countyid_curr6, force
tempfile treat
save `treat'

use county age_c age educ race using "${proj}/data/raw/census/census1990.dta", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using `map1990', keep(master match) nogen
keep if countyid_curr6!=""

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
drop if birth_i == 1939
keep if inrange(eduy, 0, 25)
merge m:1 countyid_curr6 using `treat', keep(master match) nogen

egen county_num = group(countyid_curr6)
gen post = birth_i >= 1940

quietly count
local N = r(N)
quietly egen tagc = tag(county_num)
quietly count if tagc==1
local N_counties = r(N)
drop tagc

areg eduy c.ln_martyr_per100k_1953##ib0.post i.birth_i minority, absorb(county_num) vce(cluster county_num)
estimates store m1
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"
estadd scalar N_counties = `N_counties'

esttab m1 using "${proj}/result/table/main_micro_eduy_1990_rawmapped_baseline_v1.tex", ///
    replace booktabs nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    stats(Controls County_FE Cohort_FE Cutoff N_counties N r2_a, ///
    labels("Individual controls" "County FE" "Cohort FE" "Treatment start" "Counties" "Observations" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' double b se p N N_counties using "${proj}/result/table/main_micro_eduy_1990_rawmapped_baseline_v1_tmp.dta", replace
post `memhold' (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) ///
    (`N') (`N_counties')
postclose `memhold'
use "${proj}/result/table/main_micro_eduy_1990_rawmapped_baseline_v1_tmp.dta", clear
export delimited using "${proj}/result/table/main_micro_eduy_1990_rawmapped_baseline_v1.csv", replace
erase "${proj}/result/table/main_micro_eduy_1990_rawmapped_baseline_v1_tmp.dta"
exit, clear
