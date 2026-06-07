*******************************************************
* CGSS 2008 positive and significant attitude outcomes only
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

use serial countyid a1 a2 a6 a14a a14d e3a e3b e3c e3d e3e e3f using "${proj}/data/raw/cgss2008_14.dta", clear
merge 1:1 serial using "${proj}/data/raw/cgss2008b_14.dta", keep(match) nogen

gen str6 countyid_curr6 = string(countyid, "%06.0f")
merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", keep(match) nogen keepusing(ln_martyr_per100k_1953)

gen birth_i = floor(a2)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940

gen female = (a1 == 2) if inlist(a1, 1, 2)
gen minority = (a6 != 1) if inrange(a6, 1, 56)
gen urban_hukou = inlist(a14a, 1, 2, 3, 4, 5) if inrange(a14a, 1, 6)
gen local_hukou = inlist(a14d, 1, 2) if inrange(a14d, 1, 4)

egen county_num = group(countyid_curr6)

gen hometown_affect = 5 - ge1a if inrange(ge1a, 1, 4)
gen parent_edu_importance = 6 - f1b if inrange(f1b, 1, 5)
gen ambition_importance = 6 - f1d if inrange(f1d, 1, 5)
gen hardwork_importance = 6 - f1e if inrange(f1e, 1, 5)
gen connections_importance = 6 - f1f if inrange(f1f, 1, 5)
gen religion_importance = 6 - f1j if inrange(f1j, 1, 5)
gen college_only_for_rich = 6 - f2c if inrange(f2c, 1, 5)

// mechanism_cgss_attitudes_positive
reghdfejl ambition_importance c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou, absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
capture noisily estadd scalar ar2 = e(r2_a)

reghdfejl parent_edu_importance c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou, absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
capture noisily estadd scalar ar2 = e(r2_a)

reghdfejl college_only_for_rich c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou, absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
capture noisily estadd scalar ar2 = e(r2_a)

reghdfejl hardwork_importance c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou, absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
capture noisily estadd scalar ar2 = e(r2_a)

reghdfejl hometown_affect c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou, absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
capture noisily estadd scalar ar2 = e(r2_a)

reghdfejl connections_importance c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou, absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
capture noisily estadd scalar ar2 = e(r2_a)

reghdfejl religion_importance c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou, absorb(county_num birth_i) vce(cluster county_num)
estimates store model7
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
capture noisily estadd scalar ar2 = e(r2_a)

esttab model1 model2 model3 model4 model5 model6 model7 using "${proj}/result/table/mechanism_cgss_attitudes_positive_reghdfe_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("Ambition" "Parents' edu" "Rich only" "Hard work" "Hometown" "Connections" "Religion") ///
    stats(Controls County_FE Cohort_FE N r2 ar2, labels("Individual controls" "County FE" "Cohort FE" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 model7 using "${proj}/result/table/mechanism_cgss_attitudes_positive_reghdfe_v1.tex", ///
    replace booktabs nonotes keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("Ambition" "Parents' edu" "Rich only" "Hard work" "Hometown" "Connections" "Religion") ///
    stats(Controls County_FE Cohort_FE N r2 ar2, labels("Individual controls" "County FE" "Cohort FE" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)
exit, clear
