*******************************************************
* CHIP 1995 education investment: pooled urban + rural
* Unified geography at prefecture level
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfe
if _rc != 0 {
    di as error "reghdfe not found"
    exit 198
}

tempfile pref_treat pooled summary

import delimited "${proj}/data/temp/county_to_pref4_crosswalk_v1.csv", clear varnames(1)
tostring countyid_curr6, replace force
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
merge 1:m countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", ///
    keep(match) nogen keepusing(pop_1953 martyr_count_1931_1945)
collapse (sum) pop_1953 martyr_count_1931_1945, by(pref4_curr)
gen martyr_per100k_1953 = martyr_count_1931_1945 / pop_1953 * 100000 if pop_1953>0
gen ln_martyr_per100k_1953 = ln(martyr_per100k_1953 + 1)
save `pref_treat', replace

use "${proj}/data/temp/chip1995_urban_edu_spend_micro_v1.dta", clear
keep pref4_guess birth_i post NHH head_female head_working head_eduy edu_total tuition_fee adult_training
rename pref4_guess pref4_curr
rename tuition_fee schooling_fee
rename adult_training training_cost
gen sample_rural = 0
keep if !missing(pref4_curr, birth_i)
merge m:1 pref4_curr using `pref_treat', keep(match) nogen
tempfile urban_pref
save `urban_pref', replace

use "${proj}/data/temp/chip1995_rural_edu_spend_micro_v1.dta", clear
merge m:1 countyid_curr6 using "${proj}/data/temp/county_to_pref4_crosswalk_v1.csv", keep(match) nogen
keep pref4_curr birth_i post NHH head_female head_working head_eduy edu_total schooling_fee training_cost
gen sample_rural = 1
keep if !missing(pref4_curr, birth_i)
merge m:1 pref4_curr using `pref_treat', keep(match) nogen
append using `urban_pref'

egen pref_num = group(pref4_curr)
save `pooled', replace
global chip_pooled_tmp "`pooled'"
global chip_pooled_control "NHH head_female head_working head_eduy sample_rural"

preserve
    keep pref4_curr sample_rural ln_martyr_per100k_1953
    duplicates drop
    gen match_status = "matched_pref4"
    export delimited using "${proj}/data/temp/chip1995_pooled_pref_match_audit_v1.csv", replace
restore

capture program drop _run_one
program define _run_one, rclass
    syntax , YVAR(name) MODEL(name)
    use "$chip_pooled_tmp", clear
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy, sample_rural)
    local n = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy, sample_rural) & post==0
    local n_pre = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy, sample_rural) & post==1
    local n_post = r(N)
    quietly reghdfe `yvar' c.ln_martyr_per100k_1953##ib0.post $chip_pooled_control ///
        if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy, sample_rural), ///
        absorb(pref_num birth_i) vce(cluster pref_num)
    estimates store `model'
    estadd local Controls "Y"
    estadd local Pref_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar N_sample = `n'
    estadd scalar N_pre = `n_pre'
    estadd scalar N_post = `n_post'
    return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))
    return scalar n = `n'
    return scalar n_pre = `n_pre'
    return scalar n_post = `n_post'
end

eststo clear
clear
set obs 0
gen str20 outcome = ""
gen b = .
gen se = .
gen p = .
gen n = .
gen n_pre = .
gen n_post = .
save `summary', replace

local outcomes edu_total schooling_fee training_cost
local models ""
foreach y of local outcomes {
    local m = "m_`y'"
    quietly _run_one, yvar(`y') model(`m')
    local models "`models' `m'"
    use `summary', clear
    local row = _N + 1
    set obs `row'
    replace outcome = "`y'" in `row'
    replace b = r(b) in `row'
    replace se = r(se) in `row'
    replace p = r(p) in `row'
    replace n = r(n) in `row'
    replace n_pre = r(n_pre) in `row'
    replace n_post = r(n_post) in `row'
    save `summary', replace
}

use `summary', clear
export delimited using "${proj}/result/table/mechanism_chip1995_edu_pooled_pref_reghdfe_summary_v1.csv", replace
save "${proj}/result/table/mechanism_chip1995_edu_pooled_pref_reghdfe_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/mechanism_chip1995_edu_pooled_pref_reghdfe_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls Pref_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/mechanism_chip1995_edu_pooled_pref_reghdfe_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls Pref_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
