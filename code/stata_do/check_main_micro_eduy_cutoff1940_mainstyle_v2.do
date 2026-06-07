*******************************************************
* Main individual-level eduy regressions
* Treat starts in 1940, drop 1939
* Three census waves
* Straightforward wave-by-wave structure
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

global control "minority"
global hist_controls_all "c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post"

*******************************************************
* Step 1. County harmonization and county-level files
*******************************************************
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
drop if county_curr6=="" | county_curr6=="000000"
duplicates drop county_curr6, force
tempfile treat
save `treat'

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
drop if county_curr6=="" | county_curr6=="000000"
duplicates drop county_curr6, force
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
tempfile histctrl
save `histctrl'

*******************************************************
* Step 2. Wave 1982 sample and regressions
*******************************************************
if fileexists("/tmp/census_1982_cleaned_small.csv") {
    import delimited "/tmp/census_1982_cleaned_small.csv", clear varnames(1)
}
else {
    use countyid birthyr eduy ethniccn using "${proj}/data/temp/census_1982_cleaned.dta", clear
}
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using `cw1982', keep(master match) nogen
keep if county_curr6!=""
gen birth_i = floor(birthyr)
gen minority = (ethniccn!=1) if !missing(ethniccn)
keep if inrange(birth_i, 1920, 1960)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1939
gen post = birth_i >= 1940
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `histctrl', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd local Controls "Y"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control $hist_controls_all, absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd local Controls "Y"
estadd local Hist_Control "All five"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

*******************************************************
* Step 3. Wave 1990 sample and regressions
*******************************************************
if fileexists("/tmp/census1990_raw_small.csv") {
    import delimited "/tmp/census1990_raw_small.csv", clear varnames(1)
}
else {
    use county age_c age educ race using "${proj}/data/raw/census/census1990.dta", clear
}
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 county_curr6 = string(county, "%06.0f")
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
merge m:1 county_curr6 using `histctrl', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd local Controls "Y"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control $hist_controls_all, absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd local Controls "Y"
estadd local Hist_Control "All five"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

*******************************************************
* Step 4. Wave 2000 sample and regressions
*******************************************************
if fileexists("/tmp/census2000_raw_small.csv") {
    import delimited "/tmp/census2000_raw_small.csv", clear varnames(1)
}
else {
    use uid birthyr eduyr race using "${proj}/data/raw/census/census2000.dta", clear
}
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
merge m:1 county_curr6 using `histctrl', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd local Controls "Y"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control $hist_controls_all, absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd local Controls "Y"
estadd local Hist_Control "All five"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

*******************************************************
* Step 5. Table output
*******************************************************
esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v2.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 baseline" "1982 + all five" "1990 baseline" "1990 + all five" "2000 baseline" "2000 + all five") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N r2 ar2, ///
        labels("Individual controls" "County history control" "County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v2.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 baseline" "1982 + all five" "1990 baseline" "1990 + all five" "2000 baseline" "2000 + all five") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N r2 ar2, ///
        labels("Individual controls" "County history control" "County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Step 6. Summary CSV
*******************************************************
tempname memhold
postfile `memhold' str4 wave str12 spec double b se p N N_clust using "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v2_tmp.dta", replace

estimates restore model1
post `memhold' ("1982") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model2
post `memhold' ("1982") ("all_five") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model3
post `memhold' ("1990") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model4
post `memhold' ("1990") ("all_five") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model5
post `memhold' ("2000") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model6
post `memhold' ("2000") ("all_five") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

postclose `memhold'
use "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v2_tmp.dta", clear
export delimited using "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v2.csv", replace
erase "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v2_tmp.dta"
exit, clear
