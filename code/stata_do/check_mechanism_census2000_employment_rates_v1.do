clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/raw/census/census2000.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

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
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile treat
save `treat'

use county birthyr sex race rural workst r211 using "${proj}/data/raw/census/census2000.dta", clear
drop if missing(county) | missing(birthyr) | missing(workst)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using `map2000', keep(master match) nogen
keep if county_curr6!=""

gen birth_i = floor(birthyr)
keep if inrange(birth_i, 1920, 1978)
drop if birth_i == 1939
gen post = birth_i >= 1940

gen male = (sex == 1) if !missing(sex)
gen minority = (race != 1) if !missing(race)
gen rural_i = (rural == 1) if !missing(rural)
gen person_n = 1

gen employed = 0 if !missing(workst)
replace employed = 1 if inlist(workst, 1, 2)

gen unemployed = 0 if !missing(workst)
replace unemployed = 1 if workst == 3

gen labor_force = 0 if !missing(workst)
replace labor_force = 1 if employed == 1 | unemployed == 1

collapse ///
    (sum) pop_n = person_n ///
    (sum) employed_n = employed ///
    (sum) unemployed_n = unemployed ///
    (sum) labor_force_n = labor_force ///
    (mean) male_share = male minority_share = minority rural_share = rural_i, ///
    by(county_curr6 birth_i post ln_martyr_per100k_1953)

replace pop_n = . if missing(county_curr6)
gen lfpr = labor_force_n / pop_n
gen emp_rate = employed_n / labor_force_n if labor_force_n > 0
gen unemp_rate = unemployed_n / labor_force_n if labor_force_n > 0

egen county_num = group(county_curr6)

reghdfejl lfpr c.ln_martyr_per100k_1953##ib0.post male_share minority_share rural_share [aw=pop_n], absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"

reghdfejl emp_rate c.ln_martyr_per100k_1953##ib0.post male_share minority_share rural_share [aw=labor_force_n] if labor_force_n > 0, absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"

reghdfejl unemp_rate c.ln_martyr_per100k_1953##ib0.post male_share minority_share rural_share [aw=labor_force_n] if labor_force_n > 0, absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"

tempname memhold
tempfile summarytmp
postfile `memhold' str20 outcome b se p n using `summarytmp', replace

est restore model1
post `memhold' ("lfpr") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N))
est restore model2
post `memhold' ("emp_rate") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N))
est restore model3
post `memhold' ("unemp_rate") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N))
postclose `memhold'

use `summarytmp', clear
save "${proj}/result/table/mechanism_census2000_employment_rates_summary_v1.dta", replace
export delimited using "${proj}/result/table/mechanism_census2000_employment_rates_summary_v1.csv", replace

esttab model1 model2 model3 using "${proj}/result/table/mechanism_census2000_employment_rates_v1.tex", ///
    replace booktabs nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    mtitles("Labor-force participation" "Employment rate" "Unemployment rate") ///
    scalar(Controls County_FE Cohort_FE) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 using "${proj}/result/table/mechanism_census2000_employment_rates_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    mtitles("Labor-force participation" "Employment rate" "Unemployment rate") ///
    scalar(Controls County_FE Cohort_FE) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

copy "${proj}/result/table/mechanism_census2000_employment_rates_v1.tex" "${proj}/paper/assets/tables/mechanism_census2000_employment_rates_v1.tex", replace

exit, clear
