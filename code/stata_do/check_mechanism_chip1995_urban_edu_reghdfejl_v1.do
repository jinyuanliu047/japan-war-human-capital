*******************************************************
* CHIP 1995 urban household education investment
* Geography: matched current prefecture/sample-city only
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

use "${proj}/data/temp/chip1995_urban_edu_spend_micro_v1.dta", clear
keep if !missing(pref4_guess, birth_i, ln_martyr_per100k_1953)
egen pref_num = group(pref4_guess)

tempfile chip_edu_main
save `chip_edu_main', replace
global chip_edu_tmp "`chip_edu_main'"

global control "NHH head_female head_working head_eduy"

capture program drop _run_one
program define _run_one, rclass
    syntax , YVAR(name) MODEL(name)
    use "$chip_edu_tmp", clear
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy)
    local n = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy) & post == 0
    local n_pre = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy) & post == 1
    local n_post = r(N)
    quietly reghdfe `yvar' c.ln_martyr_per100k_1953##ib0.post $control ///
        if !missing(`yvar', ln_martyr_per100k_1953, post, pref_num, birth_i, NHH, head_female, head_working, head_eduy), ///
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
tempfile summary
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

local outcomes edu_book tuition_fee child_edu_other adult_training edu_total
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
export delimited using "${proj}/result/table/mechanism_chip1995_urban_edu_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/mechanism_chip1995_urban_edu_reghdfejl_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/mechanism_chip1995_urban_edu_reghdfejl_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls Pref_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/mechanism_chip1995_urban_edu_reghdfejl_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls Pref_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
