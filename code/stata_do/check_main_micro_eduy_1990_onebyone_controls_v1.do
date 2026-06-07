*******************************************************
* Main individual-level eduy regressions, 1990 wave only
* Treat starts in 1946, drop 1945
* Historical county characteristics added one by one
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/county_controls_full_v1.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

global control "minority"

*******************************************************
* Step 1. County treatment and county controls
*******************************************************

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953 martyr_per100k_1953
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
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
tempfile ctrls
save `ctrls'

*******************************************************
* Step 2. 1990 county-code map
*******************************************************

use countyid region1990 using "${proj}/data/raw/census_1990_county_char.dta", clear
drop if missing(countyid) | missing(region1990)
rename countyid countyid_1990
gen str6 county_curr6 = string(region1990, "%06.0f")
keep countyid_1990 county_curr6
duplicates drop countyid_1990, force
tempfile map1990
save `map1990'

*******************************************************
* Step 3. Build 1990 individual-level regression sample
*******************************************************

use countyid year_birth yedu han_ethn using "${proj}/data/raw/census_1990_clean.dta", clear
drop if missing(countyid) | missing(year_birth) | missing(yedu)
rename countyid countyid_1990
merge m:1 countyid_1990 using `map1990', keep(master match) nogen
keep if county_curr6!=""
gen birth_i = floor(year_birth)
gen eduy = yedu
gen minority = (han_ethn!=1) if !missing(han_ethn)
keep if inrange(birth_i, 1920, 1968)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1945
gen post = birth_i >= 1946
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `ctrls', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)

// main_micro_eduy_1990
*******************************************************
* Step 4. Baseline and one-by-one robustness regressions
*******************************************************

reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd local Controls "Y"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"

reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control c.sdy_density#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd local Controls "Y"
estadd local Hist_Control "SDY"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"

reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control c.ins_famine#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd local Controls "Y"
estadd local Hist_Control "Famine"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"

reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control c.ln_victims_cr#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd local Controls "Y"
estadd local Hist_Control "Log victims"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"

reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control c.ln_grain_output#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd local Controls "Y"
estadd local Hist_Control "Log grain"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"

reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control c.urbanratio64#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd local Controls "Y"
estadd local Hist_Control "Urban"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"

*******************************************************
* Step 5. Export table
*******************************************************

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_micro_eduy_1990_onebyone_controls_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("Baseline" "+ SDY" "+ Famine" "+ Log victims" "+ Log grain" "+ Urban") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N r2 ar2, ///
        labels("Individual controls" "History control" "County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_micro_eduy_1990_onebyone_controls_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("Baseline" "+ SDY" "+ Famine" "+ Log victims" "+ Log grain" "+ Urban") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N r2 ar2, ///
        labels("Individual controls" "History control" "County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)
