*******************************************************
* CHIP 1995 education investment: urban + rural in one table
* Only keep conceptually comparable outcomes across surveys
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

tempfile urban_main rural_main

use "${proj}/data/temp/chip1995_urban_edu_spend_micro_v1.dta", clear
keep if !missing(pref4_guess, birth_i, ln_martyr_per100k_1953)
egen pref_num = group(pref4_guess)
gen schooling_fee = tuition_fee
gen training_cost = adult_training
save `urban_main', replace
global chip_urban_tmp "`urban_main'"

use "${proj}/data/temp/chip1995_rural_edu_spend_micro_v1.dta", clear
keep if !missing(countyid_curr6, birth_i, ln_martyr_per100k_1953)
egen county_num = group(countyid_curr6)
save `rural_main', replace
global chip_rural_tmp "`rural_main'"

global urban_control "NHH head_female head_working head_eduy"
global rural_control "NHH head_female head_working head_eduy"

capture program drop _run_urban
program define _run_urban, rclass
    syntax , YVAR(name) MODEL(name)
    use "$chip_urban_tmp", clear
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy)
    local n = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy) & post == 0
    local n_pre = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy) & post == 1
    local n_post = r(N)
    quietly reghdfe `yvar' c.ln_martyr_per100k_1953##ib0.post $urban_control ///
        if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy), ///
        absorb(pref_num birth_i) vce(cluster pref_num)
    estimates store `model'
    estadd local Sample "Urban"
    estadd local Controls "Y"
    estadd local Geo_FE "Prefecture"
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

capture program drop _run_rural
program define _run_rural, rclass
    syntax , YVAR(name) MODEL(name)
    use "$chip_rural_tmp", clear
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, NHH, head_female, head_working, head_eduy)
    local n = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, NHH, head_female, head_working, head_eduy) & post == 0
    local n_pre = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, NHH, head_female, head_working, head_eduy) & post == 1
    local n_post = r(N)
    quietly reghdfe `yvar' c.ln_martyr_per100k_1953##ib0.post $rural_control ///
        if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, NHH, head_female, head_working, head_eduy), ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Sample "Rural"
    estadd local Controls "Y"
    estadd local Geo_FE "County"
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
tempfile summary
clear
set obs 0
gen str10 sample = ""
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
    local mu = "u_`y'"
    quietly _run_urban, yvar(`y') model(`mu')
    local models "`models' `mu'"
    use `summary', clear
    local row = _N + 1
    set obs `row'
    replace sample = "urban" in `row'
    replace outcome = "`y'" in `row'
    replace b = r(b) in `row'
    replace se = r(se) in `row'
    replace p = r(p) in `row'
    replace n = r(n) in `row'
    replace n_pre = r(n_pre) in `row'
    replace n_post = r(n_post) in `row'
    save `summary', replace
}

foreach y of local outcomes {
    local mr = "r_`y'"
    quietly _run_rural, yvar(`y') model(`mr')
    local models "`models' `mr'"
    use `summary', clear
    local row = _N + 1
    set obs `row'
    replace sample = "rural" in `row'
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
export delimited using "${proj}/result/table/mechanism_chip1995_edu_combined_reghdfe_summary_v1.csv", replace
save "${proj}/result/table/mechanism_chip1995_edu_combined_reghdfe_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/mechanism_chip1995_edu_combined_reghdfe_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Sample Controls Geo_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/mechanism_chip1995_edu_combined_reghdfe_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Sample Controls Geo_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
