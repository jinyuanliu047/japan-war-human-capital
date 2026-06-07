*******************************************************
* 1990 IPUMS industry outcomes
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

quietly count if !missing(agriculture_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n1 = r(N)
quietly count if !missing(agriculture_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n1_pre = r(N)
quietly count if !missing(agriculture_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n1_post = r(N)
reghdfe agriculture_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model1
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n1'
estadd scalar N_pre = `n1_pre'
estadd scalar N_post = `n1_post'

quietly count if !missing(manufacturing_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n2 = r(N)
quietly count if !missing(manufacturing_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n2_pre = r(N)
quietly count if !missing(manufacturing_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n2_post = r(N)
reghdfe manufacturing_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model2
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n2'
estadd scalar N_pre = `n2_pre'
estadd scalar N_post = `n2_post'

quietly count if !missing(construction_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n3 = r(N)
quietly count if !missing(construction_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n3_pre = r(N)
quietly count if !missing(construction_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n3_post = r(N)
reghdfe construction_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model3
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n3'
estadd scalar N_pre = `n3_pre'
estadd scalar N_post = `n3_post'

quietly count if !missing(trade_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n4 = r(N)
quietly count if !missing(trade_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n4_pre = r(N)
quietly count if !missing(trade_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n4_post = r(N)
reghdfe trade_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model4
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n4'
estadd scalar N_pre = `n4_pre'
estadd scalar N_post = `n4_post'

quietly count if !missing(transport_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n5 = r(N)
quietly count if !missing(transport_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n5_pre = r(N)
quietly count if !missing(transport_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n5_post = r(N)
reghdfe transport_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model5
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n5'
estadd scalar N_pre = `n5_pre'
estadd scalar N_post = `n5_post'

quietly count if !missing(finance_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n6 = r(N)
quietly count if !missing(finance_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n6_pre = r(N)
quietly count if !missing(finance_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n6_post = r(N)
reghdfe finance_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model6
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n6'
estadd scalar N_pre = `n6_pre'
estadd scalar N_post = `n6_post'

quietly count if !missing(public_admin_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n7 = r(N)
quietly count if !missing(public_admin_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n7_pre = r(N)
quietly count if !missing(public_admin_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n7_post = r(N)
reghdfe public_admin_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model7
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n7'
estadd scalar N_pre = `n7_pre'
estadd scalar N_post = `n7_post'

quietly count if !missing(business_realestate_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n8 = r(N)
quietly count if !missing(business_realestate_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n8_pre = r(N)
quietly count if !missing(business_realestate_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n8_post = r(N)
reghdfe business_realestate_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model8
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n8'
estadd scalar N_pre = `n8_pre'
estadd scalar N_post = `n8_post'

quietly count if !missing(education_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n9 = r(N)
quietly count if !missing(education_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n9_pre = r(N)
quietly count if !missing(education_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n9_post = r(N)
reghdfe education_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model9
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n9'
estadd scalar N_pre = `n9_pre'
estadd scalar N_post = `n9_post'

quietly count if !missing(health_social_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n10 = r(N)
quietly count if !missing(health_social_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n10_pre = r(N)
quietly count if !missing(health_social_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n10_post = r(N)
reghdfe health_social_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model10
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n10'
estadd scalar N_pre = `n10_pre'
estadd scalar N_post = `n10_post'

quietly count if !missing(other_services_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs)
local n11 = r(N)
quietly count if !missing(other_services_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 0
local n11_pre = r(N)
quietly count if !missing(other_services_ind, ln_martyr_per100k_1953, post, geo2_num, birth_i, male_share, minority_share, n_obs) & post == 1
local n11_post = r(N)
reghdfe other_services_ind c.ln_martyr_per100k_1953##ib0.post $control [aw = n_obs], absorb(geo2_num birth_i) vce(cluster geo2_num)
estimates store model11
estadd local Controls "Y"
estadd local Geo2_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_sample = `n11'
estadd scalar N_pre = `n11_pre'
estadd scalar N_post = `n11_post'

esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 model11 using "${proj}/result/table/mechanism_census1990_ipums_industry_reghdfe_v1.rtf", ///
    replace ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("Agriculture" "Manufacturing" "Construction" "Trade" "Transport" "Finance" "Public admin" "Business/real estate" "Education" "Health/social" "Other services") ///
    stats(Controls Geo2_FE Cohort_FE N_sample N_pre N_post N r2, ///
        labels("Individual controls" "Geo2 FE" "Cohort FE" "Sample cells" "Pre-treatment cells" "Post-treatment cells" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 model11 using "${proj}/result/table/mechanism_census1990_ipums_industry_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("Agriculture" "Manufacturing" "Construction" "Trade" "Transport" "Finance" "Public admin" "Business/real estate" "Education" "Health/social" "Other services") ///
    stats(Controls Geo2_FE Cohort_FE N_sample N_pre N_post N r2, ///
        labels("Individual controls" "Geo2 FE" "Cohort FE" "Sample cells" "Pre-treatment cells" "Post-treatment cells" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' str32 outcome double b se p n n_pre n_post using "${proj}/result/table/mechanism_census1990_ipums_industry_reghdfe_summary_v1_tmp.dta", replace

estimates restore model1
post `memhold' ("agriculture_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n1') (`n1_pre') (`n1_post')
estimates restore model2
post `memhold' ("manufacturing_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n2') (`n2_pre') (`n2_post')
estimates restore model3
post `memhold' ("construction_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n3') (`n3_pre') (`n3_post')
estimates restore model4
post `memhold' ("trade_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n4') (`n4_pre') (`n4_post')
estimates restore model5
post `memhold' ("transport_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n5') (`n5_pre') (`n5_post')
estimates restore model6
post `memhold' ("finance_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n6') (`n6_pre') (`n6_post')
estimates restore model7
post `memhold' ("public_admin_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n7') (`n7_pre') (`n7_post')
estimates restore model8
post `memhold' ("business_realestate_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n8') (`n8_pre') (`n8_post')
estimates restore model9
post `memhold' ("education_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n9') (`n9_pre') (`n9_post')
estimates restore model10
post `memhold' ("health_social_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n10') (`n10_pre') (`n10_post')
estimates restore model11
post `memhold' ("other_services_ind") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2 * ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (`n11') (`n11_pre') (`n11_post')

postclose `memhold'
use "${proj}/result/table/mechanism_census1990_ipums_industry_reghdfe_summary_v1_tmp.dta", clear
export delimited using "${proj}/result/table/mechanism_census1990_ipums_industry_reghdfe_summary_v1.csv", replace
save "${proj}/result/table/mechanism_census1990_ipums_industry_reghdfe_summary_v1.dta", replace
erase "${proj}/result/table/mechanism_census1990_ipums_industry_reghdfe_summary_v1_tmp.dta"

exit, clear
