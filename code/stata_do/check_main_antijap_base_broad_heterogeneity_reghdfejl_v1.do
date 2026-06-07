*******************************************************
* Heterogeneity: broad anti-Japanese base mapping
* Explicit sample-style version
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

capture which esttab
if _rc != 0 ssc install estout, replace

eststo clear

*******************************************************
* Step 1. 1982 wave
*******************************************************

use "${proj}/data/temp/did_1982_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1960)
drop if floor(birthyr) == 1939
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
merge m:1 countyid_curr6 using "${proj}/data/temp/antijap_base_broad_indicator_v1.dta", keep(master match) nogen
replace base_broad_any = 0 if missing(base_broad_any)
egen county_num = group(countyid_curr6)

preserve
keep if base_broad_any == 0
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty1 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty1'
restore

preserve
keep if base_broad_any == 1
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty2 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty2'
restore

*******************************************************
* Step 2. 1990 wave
*******************************************************

use "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1968)
drop if floor(birthyr) == 1939
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
merge m:1 countyid_curr6 using "${proj}/data/temp/antijap_base_broad_indicator_v1.dta", keep(master match) nogen
replace base_broad_any = 0 if missing(base_broad_any)
egen county_num = group(countyid_curr6)

preserve
keep if base_broad_any == 0
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty3 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty3'
restore

preserve
keep if base_broad_any == 1
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty4 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty4'
restore

*******************************************************
* Step 3. 2000 wave
*******************************************************

use "${proj}/data/temp/did_2000_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1978)
drop if floor(birthyr) == 1939
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
merge m:1 countyid_curr6 using "${proj}/data/temp/antijap_base_broad_indicator_v1.dta", keep(master match) nogen
replace base_broad_any = 0 if missing(base_broad_any)
egen county_num = group(countyid_curr6)

preserve
keep if base_broad_any == 0
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty5 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty5'
restore

preserve
keep if base_broad_any == 1
egen tag_county = tag(county_num)
quietly count if tag_county == 1
local ncounty6 = r(N)
drop tag_county
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty6'
restore

*******************************************************
* Step 4. Table output
*******************************************************

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_antijap_base_broad_heterogeneity_reghdfe_v1.rtf", ///
    replace ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 Non-base" "1982 Base" "1990 Non-base" "1990 Base" "2000 Non-base" "2000 Base") ///
    stats(Weight County_FE Cohort_FE N_counties N r2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_antijap_base_broad_heterogeneity_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 Non-base" "1982 Base" "1990 Non-base" "1990 Base" "2000 Non-base" "2000 Base") ///
    stats(Weight County_FE Cohort_FE N_counties N r2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Step 5. Summary CSV
*******************************************************

tempname memhold
postfile `memhold' str4 wave str8 subgroup double b se p n_cells n_counties using "${proj}/result/table/main_antijap_base_broad_heterogeneity_reghdfe_summary_v1_tmp.dta", replace

estimates restore model1
post `memhold' ("1982") ("other") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty1')

estimates restore model2
post `memhold' ("1982") ("base") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty2')

estimates restore model3
post `memhold' ("1990") ("other") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty3')

estimates restore model4
post `memhold' ("1990") ("base") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty4')

estimates restore model5
post `memhold' ("2000") ("other") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty5')

estimates restore model6
post `memhold' ("2000") ("base") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty6')

postclose `memhold'

use "${proj}/result/table/main_antijap_base_broad_heterogeneity_reghdfe_summary_v1_tmp.dta", clear
export delimited using "${proj}/result/table/main_antijap_base_broad_heterogeneity_reghdfe_summary_v1.csv", replace
save "${proj}/result/table/main_antijap_base_broad_heterogeneity_reghdfe_summary_v1.dta", replace
erase "${proj}/result/table/main_antijap_base_broad_heterogeneity_reghdfe_summary_v1_tmp.dta"

exit, clear
