*******************************************************
* 1990 IPUMS employment and occupation outcomes
* Explicit model-by-model version for paper output
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "male_share minority_share"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

use "${proj}/data/temp/census1990_ipums_labor_industry_panel_v1.dta", clear
egen geo2_num = group(geo2_cn1990)

quietly count if !missing(in_labor_force, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n1 = r(N)
quietly count if !missing(in_labor_force, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n1_pre = r(N)
quietly count if !missing(in_labor_force, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n1_post = r(N)
reghdfe in_labor_force c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model1
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n1'
estadd scalar N_pre = `n1_pre'
estadd scalar N_post = `n1_post'

quietly count if !missing(employed, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n2 = r(N)
quietly count if !missing(employed, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n2_pre = r(N)
quietly count if !missing(employed, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n2_post = r(N)
reghdfe employed c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model2
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n2'
estadd scalar N_pre = `n2_pre'
estadd scalar N_post = `n2_post'

quietly count if !missing(unemployed, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n3 = r(N)
quietly count if !missing(unemployed, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n3_pre = r(N)
quietly count if !missing(unemployed, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n3_post = r(N)
reghdfe unemployed c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model3
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n3'
estadd scalar N_pre = `n3_pre'
estadd scalar N_post = `n3_post'

quietly count if !missing(inactive, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n4 = r(N)
quietly count if !missing(inactive, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n4_pre = r(N)
quietly count if !missing(inactive, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n4_post = r(N)
reghdfe inactive c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model4
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n4'
estadd scalar N_pre = `n4_pre'
estadd scalar N_post = `n4_post'

quietly count if !missing(white_collar, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n5 = r(N)
quietly count if !missing(white_collar, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n5_pre = r(N)
quietly count if !missing(white_collar, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n5_post = r(N)
reghdfe white_collar c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model5
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n5'
estadd scalar N_pre = `n5_pre'
estadd scalar N_post = `n5_post'

quietly count if !missing(professional_manager, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n6 = r(N)
quietly count if !missing(professional_manager, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n6_pre = r(N)
quietly count if !missing(professional_manager, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n6_post = r(N)
reghdfe professional_manager c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model6
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n6'
estadd scalar N_pre = `n6_pre'
estadd scalar N_post = `n6_post'

quietly count if !missing(clerical, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n7 = r(N)
quietly count if !missing(clerical, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n7_pre = r(N)
quietly count if !missing(clerical, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n7_post = r(N)
reghdfe clerical c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model7
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n7'
estadd scalar N_pre = `n7_pre'
estadd scalar N_post = `n7_post'

quietly count if !missing(service_sales, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n8 = r(N)
quietly count if !missing(service_sales, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n8_pre = r(N)
quietly count if !missing(service_sales, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n8_post = r(N)
reghdfe service_sales c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model8
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n8'
estadd scalar N_pre = `n8_pre'
estadd scalar N_post = `n8_post'

quietly count if !missing(agri_occupation, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n9 = r(N)
quietly count if !missing(agri_occupation, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n9_pre = r(N)
quietly count if !missing(agri_occupation, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n9_post = r(N)
reghdfe agri_occupation c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model9
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n9'
estadd scalar N_pre = `n9_pre'
estadd scalar N_post = `n9_post'

quietly count if !missing(craft, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n10 = r(N)
quietly count if !missing(craft, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n10_pre = r(N)
quietly count if !missing(craft, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n10_post = r(N)
reghdfe craft c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model10
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n10'
estadd scalar N_pre = `n10_pre'
estadd scalar N_post = `n10_post'

quietly count if !missing(machine_operator, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n11 = r(N)
quietly count if !missing(machine_operator, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n11_pre = r(N)
quietly count if !missing(machine_operator, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n11_post = r(N)
reghdfe machine_operator c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model11
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n11'
estadd scalar N_pre = `n11_pre'
estadd scalar N_post = `n11_post'

quietly count if !missing(elementary, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n12 = r(N)
quietly count if !missing(elementary, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n12_pre = r(N)
quietly count if !missing(elementary, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n12_post = r(N)
reghdfe elementary c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model12
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n12'
estadd scalar N_pre = `n12_pre'
estadd scalar N_post = `n12_post'

esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 model11 model12 using "${proj}/result/table/mechanism_census1990_ipums_employment_reghdfe_v1.rtf", ///
    replace ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("Labor force" "Employed" "Unemployed" "Inactive" "White collar" "Prof./manager" "Clerical" "Service/sales" "Agriculture" "Craft" "Machine operator" "Elementary") ///
    stats(Controls Geo2_FE Cohort_FE N_sample N_pre N_post N r2, ///
        labels("Individual controls" "Geo2 FE" "Cohort FE" "Sample cells" "Pre-treatment cells" "Post-treatment cells" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 model11 model12 using "${proj}/result/table/mechanism_census1990_ipums_employment_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("Labor force" "Employed" "Unemployed" "Inactive" "White collar" "Prof./manager" "Clerical" "Service/sales" "Agriculture" "Craft" "Machine operator" "Elementary") ///
    stats(Controls Geo2_FE Cohort_FE N_sample N_pre N_post N r2, ///
        labels("Individual controls" "Geo2 FE" "Cohort FE" "Sample cells" "Pre-treatment cells" "Post-treatment cells" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' str32 outcome double b se p n n_pre n_post using "${proj}/result/table/mechanism_census1990_ipums_employment_reghdfe_summary_v1_tmp.dta", replace

estimates restore model1
post `memhold' ("in_labor_force") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n1') (`n1_pre') (`n1_post')
estimates restore model2
post `memhold' ("employed") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n2') (`n2_pre') (`n2_post')
estimates restore model3
post `memhold' ("unemployed") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n3') (`n3_pre') (`n3_post')
estimates restore model4
post `memhold' ("inactive") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n4') (`n4_pre') (`n4_post')
estimates restore model5
post `memhold' ("white_collar") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n5') (`n5_pre') (`n5_post')
estimates restore model6
post `memhold' ("professional_manager") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n6') (`n6_pre') (`n6_post')
estimates restore model7
post `memhold' ("clerical") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n7') (`n7_pre') (`n7_post')
estimates restore model8
post `memhold' ("service_sales") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n8') (`n8_pre') (`n8_post')
estimates restore model9
post `memhold' ("agri_occupation") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n9') (`n9_pre') (`n9_post')
estimates restore model10
post `memhold' ("craft") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n10') (`n10_pre') (`n10_post')
estimates restore model11
post `memhold' ("machine_operator") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n11') (`n11_pre') (`n11_post')
estimates restore model12
post `memhold' ("elementary") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n12') (`n12_pre') (`n12_post')

postclose `memhold'
use "${proj}/result/table/mechanism_census1990_ipums_employment_reghdfe_summary_v1_tmp.dta", clear
export delimited using "${proj}/result/table/mechanism_census1990_ipums_employment_reghdfe_summary_v1.csv", replace
save "${proj}/result/table/mechanism_census1990_ipums_employment_reghdfe_summary_v1.dta", replace
erase "${proj}/result/table/mechanism_census1990_ipums_employment_reghdfe_summary_v1_tmp.dta"

exit, clear
