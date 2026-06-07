*******************************************************
* Heterogeneity pack (reghdfe)
* Explicit sample-style version
* 1) Treatment intensity tercile
* 2) Base education tercile
* 3) Clan intensity
* 4) Massacre severity
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/county_controls_full_v1.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

*******************************************************
* Step 1. County controls used for heterogeneity splits
*******************************************************

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 clan_num ln_massacre_death
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6) - 5, 6)
replace clan_num = 0 if missing(clan_num)
replace ln_massacre_death = 0 if missing(ln_massacre_death)
keep countyid_curr6 clan_num ln_massacre_death
duplicates drop countyid_curr6, force
tempfile hetero_ctrl
save `hetero_ctrl'

eststo clear

*******************************************************
* Step 2. 1982 wave
*******************************************************

use "${proj}/data/temp/did_1982_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1960)
drop if floor(birthyr) == 1939
keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"
merge m:1 countyid_curr6 using `hetero_ctrl', keep(master match) nogen
replace clan_num = 0 if missing(clan_num)
replace ln_massacre_death = 0 if missing(ln_massacre_death)
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
sort county_num birth_i

by county_num: egen tx_county = max(ln_martyr_per100k_1953)
egen tag_county = tag(county_num)
xtile tx_ter = tx_county if tag_county == 1, nq(3)
by county_num: egen tx_tercile = max(tx_ter)

egen base_pre = mean(eduy_mean) if inrange(birth_i, 1920, 1938), by(county_num)
by county_num: egen base_fill = max(base_pre)
replace base_pre = base_fill if missing(base_pre)
quietly summarize base_pre
replace base_pre = r(mean) if missing(base_pre)
xtile base_ter = base_pre if tag_county == 1, nq(3)
by county_num: egen baseedu_tercile = max(base_ter)

gen clan_high = (clan_num > 0) if !missing(clan_num)
replace clan_high = 0 if missing(clan_high)

quietly summarize ln_massacre_death if tag_county == 1 & ln_massacre_death > 0, detail
local med82 = r(p50)
gen massacre_high = (ln_massacre_death > `med82') if ln_massacre_death > 0
replace massacre_high = 0 if ln_massacre_death == 0

preserve
keep if tx_tercile == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty1 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty1'
restore

preserve
keep if tx_tercile == 2
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty2 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty2'
restore

preserve
keep if tx_tercile == 3
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty3 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty3'
restore

preserve
keep if baseedu_tercile == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty4 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty4'
restore

preserve
keep if baseedu_tercile == 2
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty5 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty5'
restore

preserve
keep if baseedu_tercile == 3
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty6 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty6'
restore

preserve
keep if clan_high == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty7 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model7
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty7'
restore

preserve
keep if clan_high == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty8 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model8
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty8'
restore

preserve
keep if massacre_high == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty9 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model9
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty9'
restore

preserve
keep if massacre_high == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty10 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model10
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty10'
restore

*******************************************************
* Step 3. 1990 wave
*******************************************************

use "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1968)
drop if floor(birthyr) == 1939
keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"
merge m:1 countyid_curr6 using `hetero_ctrl', keep(master match) nogen
replace clan_num = 0 if missing(clan_num)
replace ln_massacre_death = 0 if missing(ln_massacre_death)
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
sort county_num birth_i

by county_num: egen tx_county = max(ln_martyr_per100k_1953)
egen tag_county = tag(county_num)
xtile tx_ter = tx_county if tag_county == 1, nq(3)
by county_num: egen tx_tercile = max(tx_ter)

egen base_pre = mean(eduy_mean) if inrange(birth_i, 1920, 1938), by(county_num)
by county_num: egen base_fill = max(base_pre)
replace base_pre = base_fill if missing(base_pre)
quietly summarize base_pre
replace base_pre = r(mean) if missing(base_pre)
xtile base_ter = base_pre if tag_county == 1, nq(3)
by county_num: egen baseedu_tercile = max(base_ter)

gen clan_high = (clan_num > 0) if !missing(clan_num)
replace clan_high = 0 if missing(clan_high)

quietly summarize ln_massacre_death if tag_county == 1 & ln_massacre_death > 0, detail
local med90 = r(p50)
gen massacre_high = (ln_massacre_death > `med90') if ln_massacre_death > 0
replace massacre_high = 0 if ln_massacre_death == 0

preserve
keep if tx_tercile == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty11 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model11
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty11'
restore

preserve
keep if tx_tercile == 2
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty12 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model12
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty12'
restore

preserve
keep if tx_tercile == 3
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty13 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model13
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty13'
restore

preserve
keep if baseedu_tercile == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty14 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model14
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty14'
restore

preserve
keep if baseedu_tercile == 2
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty15 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model15
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty15'
restore

preserve
keep if baseedu_tercile == 3
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty16 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model16
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty16'
restore

preserve
keep if clan_high == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty17 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model17
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty17'
restore

preserve
keep if clan_high == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty18 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model18
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty18'
restore

preserve
keep if massacre_high == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty19 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model19
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty19'
restore

preserve
keep if massacre_high == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty20 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model20
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty20'
restore

*******************************************************
* Step 4. 2000 wave
*******************************************************

use "${proj}/data/temp/did_2000_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1978)
drop if floor(birthyr) == 1939
keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"
merge m:1 countyid_curr6 using `hetero_ctrl', keep(master match) nogen
replace clan_num = 0 if missing(clan_num)
replace ln_massacre_death = 0 if missing(ln_massacre_death)
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
sort county_num birth_i

by county_num: egen tx_county = max(ln_martyr_per100k_1953)
egen tag_county = tag(county_num)
xtile tx_ter = tx_county if tag_county == 1, nq(3)
by county_num: egen tx_tercile = max(tx_ter)

egen base_pre = mean(eduy_mean) if inrange(birth_i, 1920, 1938), by(county_num)
by county_num: egen base_fill = max(base_pre)
replace base_pre = base_fill if missing(base_pre)
quietly summarize base_pre
replace base_pre = r(mean) if missing(base_pre)
xtile base_ter = base_pre if tag_county == 1, nq(3)
by county_num: egen baseedu_tercile = max(base_ter)

gen clan_high = (clan_num > 0) if !missing(clan_num)
replace clan_high = 0 if missing(clan_high)

quietly summarize ln_massacre_death if tag_county == 1 & ln_massacre_death > 0, detail
local med00 = r(p50)
gen massacre_high = (ln_massacre_death > `med00') if ln_massacre_death > 0
replace massacre_high = 0 if ln_massacre_death == 0

preserve
keep if tx_tercile == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty21 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model21
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty21'
restore

preserve
keep if tx_tercile == 2
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty22 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model22
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty22'
restore

preserve
keep if tx_tercile == 3
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty23 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model23
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty23'
restore

preserve
keep if baseedu_tercile == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty24 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model24
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty24'
restore

preserve
keep if baseedu_tercile == 2
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty25 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model25
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty25'
restore

preserve
keep if baseedu_tercile == 3
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty26 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model26
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty26'
restore

preserve
keep if clan_high == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty27 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model27
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty27'
restore

preserve
keep if clan_high == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty28 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model28
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty28'
restore

preserve
keep if massacre_high == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty29 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model29
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty29'
restore

preserve
keep if massacre_high == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty30 = r(N)
drop tag_model
reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model30
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty30'
restore

*******************************************************
* Step 5. Table output
*******************************************************

esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 ///
       model11 model12 model13 model14 model15 model16 model17 model18 model19 model20 ///
       model21 model22 model23 model24 model25 model26 model27 model28 model29 model30 ///
       using "${proj}/result/table/main_heterogeneity_pack_reghdfe_v1.rtf", ///
    replace ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("82 T1" "82 T2" "82 T3" "82 B1" "82 B2" "82 B3" "82 C0" "82 C1" "82 D0" "82 D1" ///
            "90 T1" "90 T2" "90 T3" "90 B1" "90 B2" "90 B3" "90 C0" "90 C1" "90 D0" "90 D1" ///
            "00 T1" "00 T2" "00 T3" "00 B1" "00 B2" "00 B3" "00 C0" "00 C1" "00 D0" "00 D1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 ///
       using "${proj}/result/table/main_heterogeneity_pack_1982_reghdfe_v1.rtf", ///
    replace ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("T1" "T2" "T3" "B1" "B2" "B3" "C0" "C1" "D0" "D1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2 ar2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model11 model12 model13 model14 model15 model16 model17 model18 model19 model20 ///
       using "${proj}/result/table/main_heterogeneity_pack_1990_reghdfe_v1.rtf", ///
    replace ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("T1" "T2" "T3" "B1" "B2" "B3" "C0" "C1" "D0" "D1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2 ar2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model21 model22 model23 model24 model25 model26 model27 model28 model29 model30 ///
       using "${proj}/result/table/main_heterogeneity_pack_2000_reghdfe_v1.rtf", ///
    replace ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("T1" "T2" "T3" "B1" "B2" "B3" "C0" "C1" "D0" "D1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2 ar2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 ///
       model11 model12 model13 model14 model15 model16 model17 model18 model19 model20 ///
       model21 model22 model23 model24 model25 model26 model27 model28 model29 model30 ///
       using "${proj}/result/table/main_heterogeneity_pack_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("82 T1" "82 T2" "82 T3" "82 B1" "82 B2" "82 B3" "82 C0" "82 C1" "82 D0" "82 D1" ///
            "90 T1" "90 T2" "90 T3" "90 B1" "90 B2" "90 B3" "90 C0" "90 C1" "90 D0" "90 D1" ///
            "00 T1" "00 T2" "00 T3" "00 B1" "00 B2" "00 B3" "00 C0" "00 C1" "00 D0" "00 D1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 ///
       using "${proj}/result/table/main_heterogeneity_pack_1982_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("T1" "T2" "T3" "B1" "B2" "B3" "C0" "C1" "D0" "D1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model11 model12 model13 model14 model15 model16 model17 model18 model19 model20 ///
       using "${proj}/result/table/main_heterogeneity_pack_1990_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("T1" "T2" "T3" "B1" "B2" "B3" "C0" "C1" "D0" "D1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model21 model22 model23 model24 model25 model26 model27 model28 model29 model30 ///
       using "${proj}/result/table/main_heterogeneity_pack_2000_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("T1" "T2" "T3" "B1" "B2" "B3" "C0" "C1" "D0" "D1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Step 6. Summary CSV
*******************************************************

tempname memhold
postfile `memhold' str4 wave str12 dim str4 subgroup double b se p n_cells n_counties using "${proj}/result/table/main_heterogeneity_pack_reghdfe_summary_v1_tmp.dta", replace

estimates restore model1
post `memhold' ("1982") ("treat") ("T1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty1')
estimates restore model2
post `memhold' ("1982") ("treat") ("T2") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty2')
estimates restore model3
post `memhold' ("1982") ("treat") ("T3") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty3')
estimates restore model4
post `memhold' ("1982") ("baseedu") ("B1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty4')
estimates restore model5
post `memhold' ("1982") ("baseedu") ("B2") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty5')
estimates restore model6
post `memhold' ("1982") ("baseedu") ("B3") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty6')
estimates restore model7
post `memhold' ("1982") ("clan") ("C0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty7')
estimates restore model8
post `memhold' ("1982") ("clan") ("C1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty8')
estimates restore model9
post `memhold' ("1982") ("massacre") ("D0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty9')
estimates restore model10
post `memhold' ("1982") ("massacre") ("D1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty10')

estimates restore model11
post `memhold' ("1990") ("treat") ("T1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty11')
estimates restore model12
post `memhold' ("1990") ("treat") ("T2") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty12')
estimates restore model13
post `memhold' ("1990") ("treat") ("T3") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty13')
estimates restore model14
post `memhold' ("1990") ("baseedu") ("B1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty14')
estimates restore model15
post `memhold' ("1990") ("baseedu") ("B2") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty15')
estimates restore model16
post `memhold' ("1990") ("baseedu") ("B3") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty16')
estimates restore model17
post `memhold' ("1990") ("clan") ("C0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty17')
estimates restore model18
post `memhold' ("1990") ("clan") ("C1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty18')
estimates restore model19
post `memhold' ("1990") ("massacre") ("D0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty19')
estimates restore model20
post `memhold' ("1990") ("massacre") ("D1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty20')

estimates restore model21
post `memhold' ("2000") ("treat") ("T1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty21')
estimates restore model22
post `memhold' ("2000") ("treat") ("T2") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty22')
estimates restore model23
post `memhold' ("2000") ("treat") ("T3") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty23')
estimates restore model24
post `memhold' ("2000") ("baseedu") ("B1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty24')
estimates restore model25
post `memhold' ("2000") ("baseedu") ("B2") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty25')
estimates restore model26
post `memhold' ("2000") ("baseedu") ("B3") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty26')
estimates restore model27
post `memhold' ("2000") ("clan") ("C0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty27')
estimates restore model28
post `memhold' ("2000") ("clan") ("C1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty28')
estimates restore model29
post `memhold' ("2000") ("massacre") ("D0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty29')
estimates restore model30
post `memhold' ("2000") ("massacre") ("D1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty30')

postclose `memhold'

use "${proj}/result/table/main_heterogeneity_pack_reghdfe_summary_v1_tmp.dta", clear
export delimited using "${proj}/result/table/main_heterogeneity_pack_reghdfe_summary_v1.csv", replace
save "${proj}/result/table/main_heterogeneity_pack_reghdfe_summary_v1.dta", replace
erase "${proj}/result/table/main_heterogeneity_pack_reghdfe_summary_v1_tmp.dta"

exit, clear
