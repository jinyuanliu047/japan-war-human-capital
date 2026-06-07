*******************************************************
* Main individual-level eduy regressions, 1982 wave only
* Treat starts in 1946, drop 1945
* Historical county characteristics added one by one
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"



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
* Step 2. 1982 crosswalk
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

*******************************************************
* Step 3. Build 1982 individual-level regression sample
*******************************************************

use countyid birthyr eduy ethniccn using "${proj}/data/temp/census_1982_cleaned.dta", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using `cw1982', keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen birth_i = floor(birthyr)
gen minority = (ethniccn!=1) if !missing(ethniccn)
keep if inrange(birth_i, 1920, 1960)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1945
gen post = birth_i >= 1946
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `ctrls', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)

*******************************************************
* Step 4. Baseline and one-by-one robustness regressions
*******************************************************

reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd local Controls "Y"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"


reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control c.sdy_density#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd local Controls "Y"
estadd local Hist_Control "sdy_density"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"


reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control c.ins_famine#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd local Controls "Y"
estadd local Hist_Control "ins_famine"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"


reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control c.ln_victims_cr#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd local Controls "Y"
estadd local Hist_Control "Log victims"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"


reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control c.ln_grain_output#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd local Controls "Y"
estadd local Hist_Control "Log grain"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"


reghdfejl eduy c.ln_martyr_per100k_1953##i.post $control c.urbanratio64#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd local Controls "Y"
estadd local Hist_Control "urbanratio64"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"

*******************************************************
* Step 5. Export table
*******************************************************

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_micro_eduy_1982_onebyone_controls_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls Hist_Control County_FE Cohort_FE Cutoff) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_micro_eduy_1982_onebyone_controls_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls Hist_Control County_FE Cohort_FE Cutoff) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Step 6. Export summary CSV
*******************************************************

tempname memhold
postfile `memhold' str4 wave str20 spec double b se p N N_clust using "${proj}/result/table/main_micro_eduy_1982_onebyone_controls_v1_tmp.dta", replace

estimates restore model1
post `memhold' ("1982") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model2
post `memhold' ("1982") ("sdy_density") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model3
post `memhold' ("1982") ("ins_famine") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model4
post `memhold' ("1982") ("log_victims") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model5
post `memhold' ("1982") ("log_grain") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model6
post `memhold' ("1982") ("urbanratio64") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

postclose `memhold'
use "${proj}/result/table/main_micro_eduy_1982_onebyone_controls_v1_tmp.dta", clear
export delimited using "${proj}/result/table/main_micro_eduy_1982_onebyone_controls_v1.csv", replace
erase "${proj}/result/table/main_micro_eduy_1982_onebyone_controls_v1_tmp.dta"
