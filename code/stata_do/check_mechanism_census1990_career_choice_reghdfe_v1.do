*******************************************************
* Census 1990 mechanism: individual 0/1 career-choice outcomes
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "male minority rural"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

use "${proj}/data/temp/census1990_occupation_micro_v1.dta", clear
egen county_num = group(countyid_curr6)

tempfile occdata
save `occdata', replace
global occdata_tmp "`occdata'"

capture program drop _run_occ
program define _run_occ, rclass
    syntax , YVAR(name) MODEL(name) LABEL(string)
    use "$occdata_tmp", clear
    keep if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male, minority, rural)
    quietly count
    local n = r(N)
    quietly count if post == 0
    local n_pre = r(N)
    quietly count if post == 1
    local n_post = r(N)
    quietly reghdfe `yvar' c.ln_martyr_per100k_1953##ib0.post $control, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Outcome "`label'"
    estadd local Controls "Y"
    estadd local County_FE "Y"
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
gen str24 outcome = ""
gen b = .
gen se = .
gen p = .
gen n = .
gen n_pre = .
gen n_post = .
save `summary', replace

local outcomes teacher_job white_collar professional manual
local labels `" "Teacher job" "White-collar" "Professional/manager" "Manual occupation" "'

local models ""
local i = 1
foreach y of local outcomes {
    local lab : word `i' of `labels'
    local m = "m`i'"
    quietly _run_occ, yvar(`y') model(`m') label(`"`lab'"')
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
    local ++i
}

use `summary', clear
export delimited using "${proj}/result/table/mechanism_census1990_career_choice_reghdfe_summary_v1.csv", replace
save "${proj}/result/table/mechanism_census1990_career_choice_reghdfe_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/mechanism_census1990_career_choice_reghdfe_v1.tex", ///
    replace booktabs nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("Teacher job" "White-collar" "Prof./manager" "Manual occupation") ///
    stats(Controls County_FE Cohort_FE N_sample N_pre N_post r2 ar2, ///
        labels("Controls" "County FE" "Cohort FE" "Observations" "N pre" "N post" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

exit, clear
