*******************************************************
* Census 1990 mechanism: employment and occupation
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

use "${proj}/data/temp/census1990_occupation_micro_v1.dta", clear
gen post_ln = post * ln_martyr_per100k_1953

label var lf_participate "Labor force"
label var teacher_job "Teacher job"
label var white_collar "White-collar"
label var professional "Professional/manager"
label var manual "Manual occupation"

egen county_num = group(countyid_curr6)

tempfile occdata
save `occdata', replace
global occdata_tmp "`occdata'"

capture program drop _run_occ
program define _run_occ, rclass
    syntax , YVAR(name) MODEL(name) LABEL(string)
    preserve
        use "$occdata_tmp", clear
        keep if !missing(`yvar', post_ln, county_num, birth_i, male, minority, rural)
        quietly count
        local n = r(N)
        quietly reghdfejl `yvar' post_ln $control, ///
            absorb(county_num birth_i) vce(cluster county_num)
        estimates store `model'
        estadd local Outcome "`label'"
        estadd local Controls "Y"
        estadd local County_FE "Y"
        estadd local Cohort_FE "Y"
        return scalar b = _b[post_ln]
        return scalar se = _se[post_ln]
        return scalar p = 2*ttail(e(df_r), abs(_b[post_ln] / _se[post_ln]))
        return scalar n = `n'
    restore
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
save `summary', replace

local outcomes lf_participate teacher_job white_collar professional manual
local labels `" "Labor force" "Teacher job" "White-collar" "Professional/manager" "Manual occupation" "'

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
    save `summary', replace
    local ++i
}

use `summary', clear
export delimited using "${proj}/result/table/mechanism_census1990_occupation_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/mechanism_census1990_occupation_reghdfejl_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/mechanism_census1990_occupation_reghdfejl_v1.rtf", ///
    replace keep(post_ln) ///
    scalar(Outcome Controls County_FE Cohort_FE) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/mechanism_census1990_occupation_reghdfejl_v1.tex", ///
    replace keep(post_ln) ///
    scalar(Outcome Controls County_FE Cohort_FE) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
