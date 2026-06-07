*******************************************************
* Gender + urban-rural heterogeneity
* Explicit sample-style version
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global paneldir "${proj}/data/temp/heterogeneity_groups_v4"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

eststo clear

*******************************************************
* Step 1. Gender heterogeneity
*******************************************************

use "${paneldir}/panel_1982_male.dta", clear
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
replace minority_share = 0 if missing(minority_share)
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty1 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty1'

use "${paneldir}/panel_1982_female.dta", clear
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
replace minority_share = 0 if missing(minority_share)
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty2 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty2'

use "${paneldir}/panel_1990_male.dta", clear
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
replace minority_share = 0 if missing(minority_share)
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty3 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty3'

use "${paneldir}/panel_1990_female.dta", clear
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
replace minority_share = 0 if missing(minority_share)
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty4 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty4'

use "${paneldir}/panel_2000_male.dta", clear
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
replace minority_share = 0 if missing(minority_share)
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty5 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty5'

use "${paneldir}/panel_2000_female.dta", clear
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
replace minority_share = 0 if missing(minority_share)
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty6 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty6'

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_individual_heterogeneity_gender_reghdfe_v4.rtf", ///
    replace ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 Male" "1982 Female" "1990 Male" "1990 Female" "2000 Male" "2000 Female") ///
    stats(Controls County_FE Cohort_FE N_counties N r2, ///
        labels("Minority control" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_individual_heterogeneity_gender_reghdfe_v4.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 Male" "1982 Female" "1990 Male" "1990 Female" "2000 Male" "2000 Female") ///
    stats(Controls County_FE Cohort_FE N_counties N r2, ///
        labels("Minority control" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

tempname memhold_gender
postfile `memhold_gender' str4 wave str8 subgroup double b se p n_cells n_counties using "${proj}/result/table/main_individual_heterogeneity_gender_reghdfe_summary_v4_tmp.dta", replace

estimates restore model1
post `memhold_gender' ("1982") ("male") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty1')

estimates restore model2
post `memhold_gender' ("1982") ("female") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty2')

estimates restore model3
post `memhold_gender' ("1990") ("male") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty3')

estimates restore model4
post `memhold_gender' ("1990") ("female") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty4')

estimates restore model5
post `memhold_gender' ("2000") ("male") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty5')

estimates restore model6
post `memhold_gender' ("2000") ("female") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty6')

postclose `memhold_gender'

use "${proj}/result/table/main_individual_heterogeneity_gender_reghdfe_summary_v4_tmp.dta", clear
export delimited using "${proj}/result/table/main_individual_heterogeneity_gender_reghdfe_summary_v4.csv", replace
save "${proj}/result/table/main_individual_heterogeneity_gender_reghdfe_summary_v4.dta", replace
erase "${proj}/result/table/main_individual_heterogeneity_gender_reghdfe_summary_v4_tmp.dta"

*******************************************************
* Step 2. Urban-rural heterogeneity
*******************************************************

use "${paneldir}/panel_1990_urban.dta", clear
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
replace minority_share = 0 if missing(minority_share)
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty7 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, absorb(county_num birth_i) vce(cluster county_num)
estimates store model7
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty7'

use "${paneldir}/panel_1990_rural.dta", clear
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
replace minority_share = 0 if missing(minority_share)
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty8 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, absorb(county_num birth_i) vce(cluster county_num)
estimates store model8
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty8'

use "${paneldir}/panel_2000_urban.dta", clear
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
replace minority_share = 0 if missing(minority_share)
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty9 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, absorb(county_num birth_i) vce(cluster county_num)
estimates store model9
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty9'

use "${paneldir}/panel_2000_rural.dta", clear
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
replace minority_share = 0 if missing(minority_share)
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty10 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, absorb(county_num birth_i) vce(cluster county_num)
estimates store model10
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty10'

esttab model7 model8 model9 model10 using "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfe_v4.rtf", ///
    replace ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1990 Urban" "1990 Rural" "2000 Urban" "2000 Rural") ///
    stats(Controls County_FE Cohort_FE N_counties N r2, ///
        labels("Minority control" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model7 model8 model9 model10 using "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfe_v4.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1990 Urban" "1990 Rural" "2000 Urban" "2000 Rural") ///
    stats(Controls County_FE Cohort_FE N_counties N r2, ///
        labels("Minority control" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

tempname memhold_urban
postfile `memhold_urban' str4 wave str8 subgroup double b se p n_cells n_counties using "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfe_summary_v4_tmp.dta", replace

estimates restore model7
post `memhold_urban' ("1990") ("urban") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty7')

estimates restore model8
post `memhold_urban' ("1990") ("rural") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty8')

estimates restore model9
post `memhold_urban' ("2000") ("urban") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty9')

estimates restore model10
post `memhold_urban' ("2000") ("rural") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty10')

postclose `memhold_urban'

use "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfe_summary_v4_tmp.dta", clear
export delimited using "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfe_summary_v4.csv", replace
save "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfe_summary_v4.dta", replace
erase "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfe_summary_v4_tmp.dta"

exit, clear
