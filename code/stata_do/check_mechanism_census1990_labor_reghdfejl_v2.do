*******************************************************
* Census 1990 raw labor force / occupation outcomes
* Uses rebuilt raw-1990 micro data, not clean 1990
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "male minority rural"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
}

use "${proj}/data/temp/census1990_labor_micro_v2.dta", clear
egen county_num = group(countyid_curr6)

capture program drop _run_one
program define _run_one, rclass
    syntax , YVAR(name) MODEL(name)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male, minority, rural)
    local n = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male, minority, rural) & post == 0
    local n_pre = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male, minority, rural) & post == 1
    local n_post = r(N)
    quietly reghdfejl `yvar' c.ln_martyr_per100k_1953##ib0.post $control ///
        if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, male, minority, rural), ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar N = `n'
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

local outcomes in_labor_force employed nonagri white_collar manual
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
export delimited using "${proj}/result/table/mechanism_census1990_labor_reghdfejl_summary_v2.csv", replace
save "${proj}/result/table/mechanism_census1990_labor_reghdfejl_summary_v2.dta", replace

esttab `models' using "${proj}/result/table/mechanism_census1990_labor_reghdfejl_v2.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/mechanism_census1990_labor_reghdfejl_v2.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
