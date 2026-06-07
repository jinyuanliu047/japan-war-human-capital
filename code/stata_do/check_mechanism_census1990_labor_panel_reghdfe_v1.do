// mechanism_census1990_labor_panel

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "male_share minority_share rural_share"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
}

use "${proj}/data/temp/census1990_labor_panel_v1.dta", clear
keep if !missing(countyid_curr6, birth_i, ln_martyr_per100k_1953)
egen county_num = group(countyid_curr6)

tempfile labor_main
save `labor_main', replace
global labor_panel_tmp "`labor_main'"

capture program drop _run_one
program define _run_one, rclass
    syntax , YVAR(name) MODEL(name)
    use "$labor_panel_tmp", clear
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male_share, minority_share, rural_share, n_obs)
    local n = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male_share, minority_share, rural_share, n_obs) & post==0
    local n_pre = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male_share, minority_share, rural_share, n_obs) & post==1
    local n_post = r(N)
    quietly reghdfejl `yvar' c.ln_martyr_per100k_1953##ib0.post $control [aw=n_obs], ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
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
gen str20 outcome = ""
gen b = .
gen se = .
gen p = .
gen n = .
gen n_pre = .
gen n_post = .
save `summary', replace

quietly _run_one, yvar(in_labor_force) model(model1)
use `summary', clear
set obs `=_N+1'
replace outcome = "in_labor_force" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(employed) model(model2)
use `summary', clear
set obs `=_N+1'
replace outcome = "employed" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(unemployed) model(model3)
use `summary', clear
set obs `=_N+1'
replace outcome = "unemployed" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(nonagri) model(model4)
use `summary', clear
set obs `=_N+1'
replace outcome = "nonagri" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(white_collar) model(model5)
use `summary', clear
set obs `=_N+1'
replace outcome = "white_collar" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(professional_manager) model(model6)
use `summary', clear
set obs `=_N+1'
replace outcome = "professional_manager" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(clerical) model(model7)
use `summary', clear
set obs `=_N+1'
replace outcome = "clerical" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(service_sales) model(model8)
use `summary', clear
set obs `=_N+1'
replace outcome = "service_sales" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(agri_occupation) model(model9)
use `summary', clear
set obs `=_N+1'
replace outcome = "agri_occupation" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(craft) model(model10)
use `summary', clear
set obs `=_N+1'
replace outcome = "craft" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(machine_operator) model(model11)
use `summary', clear
set obs `=_N+1'
replace outcome = "machine_operator" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(elementary) model(model12)
use `summary', clear
set obs `=_N+1'
replace outcome = "elementary" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

quietly _run_one, yvar(manual) model(model13)
use `summary', clear
set obs `=_N+1'
replace outcome = "manual" in L
replace b = r(b) in L
replace se = r(se) in L
replace p = r(p) in L
replace n = r(n) in L
replace n_pre = r(n_pre) in L
replace n_post = r(n_post) in L
save `summary', replace

use `summary', clear
export delimited using "${proj}/result/table/mechanism_census1990_labor_panel_reghdfe_summary_v1.csv", replace
save "${proj}/result/table/mechanism_census1990_labor_panel_reghdfe_summary_v1.dta", replace

esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 model11 model12 model13 using "${proj}/result/table/mechanism_census1990_labor_panel_reghdfe_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 model7 model8 model9 model10 model11 model12 model13 using "${proj}/result/table/mechanism_census1990_labor_panel_reghdfe_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
