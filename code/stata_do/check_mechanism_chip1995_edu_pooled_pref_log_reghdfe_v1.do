*******************************************************
* CHIP 1995 pooled education investment
* Log specification: ln(1+y)
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "NHH head_female head_working head_eduy sample_rural"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

use "${proj}/data/temp/chip1995_edu_pooled_pref_micro_v1.dta", clear
egen pref_num = group(pref4_curr)

gen ln1p_edu_total = ln(edu_total + 1) if !missing(edu_total)
gen ln1p_schooling_fee = ln(schooling_fee + 1) if !missing(schooling_fee)
gen ln1p_training_cost = ln(training_cost + 1) if !missing(training_cost)

// mechanism_chip1995_edu_pooled_pref_log
reghdfejl ln1p_edu_total c.ln_martyr_per100k_1953##ib0.post $control, absorb(pref_num birth_i) vce(cluster pref_num)
estimates store model1
estadd local Controls "Y"
estadd local Pref_FE "Y"
estadd local Cohort_FE "Y"

reghdfejl ln1p_schooling_fee c.ln_martyr_per100k_1953##ib0.post $control, absorb(pref_num birth_i) vce(cluster pref_num)
estimates store model2
estadd local Controls "Y"
estadd local Pref_FE "Y"
estadd local Cohort_FE "Y"

reghdfejl ln1p_training_cost c.ln_martyr_per100k_1953##ib0.post $control, absorb(pref_num birth_i) vce(cluster pref_num)
estimates store model3
estadd local Controls "Y"
estadd local Pref_FE "Y"
estadd local Cohort_FE "Y"

esttab model1 model2 model3 using "${proj}/result/table/mechanism_chip1995_edu_pooled_pref_log_reghdfe_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("ln(1+Education total)" "ln(1+Schooling fee)" "ln(1+Training cost)") ///
    stats(Controls Pref_FE Cohort_FE N r2, labels("Household controls" "Prefecture FE" "Cohort FE" "Observations" "R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 using "${proj}/result/table/mechanism_chip1995_edu_pooled_pref_log_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("ln(1+Education total)" "ln(1+Schooling fee)" "ln(1+Training cost)") ///
    stats(Controls Pref_FE Cohort_FE N r2, labels("Household controls" "Prefecture FE" "Cohort FE" "Observations" "R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' str24 outcome double b se p N using "${proj}/result/table/mechanism_chip1995_edu_pooled_pref_log_reghdfe_summary_v1_tmp.dta", replace
estimates restore model1
post `memhold' ("ln1p_edu_total") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N))
estimates restore model2
post `memhold' ("ln1p_schooling_fee") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N))
estimates restore model3
post `memhold' ("ln1p_training_cost") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N))
postclose `memhold'
use "${proj}/result/table/mechanism_chip1995_edu_pooled_pref_log_reghdfe_summary_v1_tmp.dta", clear
export delimited using "${proj}/result/table/mechanism_chip1995_edu_pooled_pref_log_reghdfe_summary_v1.csv", replace
erase "${proj}/result/table/mechanism_chip1995_edu_pooled_pref_log_reghdfe_summary_v1_tmp.dta"
exit, clear
