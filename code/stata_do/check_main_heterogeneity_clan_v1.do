*******************************************************
* Clan heterogeneity (reghdfe)
* Explicit sample-style version
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/did_1982_county_birthyr_pop1953_unwt_v2.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 clan_num
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6) - 5, 6)
replace clan_num = 0 if missing(clan_num)
duplicates drop countyid_curr6, force
tempfile clan_ctrl
save `clan_ctrl'

eststo clear

*******************************************************
* 1982
*******************************************************

use "${proj}/data/temp/did_1982_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1960)
drop if floor(birthyr) == 1939
keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"
merge m:1 countyid_curr6 using `clan_ctrl', keep(master match) nogen
replace clan_num = 0 if missing(clan_num)
gen clan_any = clan_num > 0
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
sort county_num birth_i

preserve
keep if clan_any == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty1 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty1'
restore

preserve
keep if clan_any == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty2 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty2'
restore

*******************************************************
* 1990
*******************************************************

use "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1968)
drop if floor(birthyr) == 1939
keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"
merge m:1 countyid_curr6 using `clan_ctrl', keep(master match) nogen
replace clan_num = 0 if missing(clan_num)
gen clan_any = clan_num > 0
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
sort county_num birth_i

preserve
keep if clan_any == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty3 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty3'
restore

preserve
keep if clan_any == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty4 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty4'
restore

*******************************************************
* 2000
*******************************************************

use "${proj}/data/temp/did_2000_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1978)
drop if floor(birthyr) == 1939
keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"
merge m:1 countyid_curr6 using `clan_ctrl', keep(master match) nogen
replace clan_num = 0 if missing(clan_num)
gen clan_any = clan_num > 0
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
sort county_num birth_i

preserve
keep if clan_any == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty5 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty5'
restore

preserve
keep if clan_any == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty6 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty6'
restore

*******************************************************
* Output
*******************************************************

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_clan_heterogeneity_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("82 C0" "82 C1" "90 C0" "90 C1" "00 C0" "00 C1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2 ar2, ///
          labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.10 ** 0.05 *** 0.01)

postutil clear
postfile handle str8 wave str6 subgroup double b se p long n_cells n_counties using "${proj}/result/table/main_clan_heterogeneity_reghdfe_summary_v1.dta", replace
estimates restore model1
post handle ("1982") ("C0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty1')
estimates restore model2
post handle ("1982") ("C1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty2')
estimates restore model3
post handle ("1990") ("C0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty3')
estimates restore model4
post handle ("1990") ("C1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty4')
estimates restore model5
post handle ("2000") ("C0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty5')
estimates restore model6
post handle ("2000") ("C1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r),abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty6')
postclose handle

use "${proj}/result/table/main_clan_heterogeneity_reghdfe_summary_v1.dta", clear
export delimited using "${proj}/result/table/main_clan_heterogeneity_reghdfe_summary_v1.csv", replace
