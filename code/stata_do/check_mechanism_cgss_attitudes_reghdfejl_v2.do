*******************************************************
* CGSS 2008 attitude mechanism, county-birth panel
* - main sample + B module
* - collapse to county x birth cohort means
* - weighted by cell size
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
}

use serial countyid a1 a2 a6 a14a a14d using "${proj}/data/raw/cgss2008_14.dta", clear
merge 1:1 serial using "${proj}/data/raw/cgss2008b_14.dta", keep(match) nogen

gen str6 countyid_curr6 = string(countyid, "%06.0f")
merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", ///
    keep(match) nogen keepusing(ln_martyr_per100k_1953)

gen birth_i = floor(a2)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939

gen female = (a1 == 2) if inlist(a1, 1, 2)
gen minority = (a6 != 1) if inrange(a6, 1, 8)
gen urban_hukou = inlist(a14a, 1, 2, 3, 4, 5) if inrange(a14a, 1, 6)
gen local_hukou = inlist(a14d, 1, 2) if inrange(a14d, 1, 4)

gen nat_interest      = 8 - gl1b if inrange(gl1b, 1, 7)
gen import_protect    = 8 - gl1a if inrange(gl1a, 1, 7)
gen culture_protect   = 8 - gl1c if inrange(gl1c, 1, 7)
gen country_affect    = 5 - ge1b if inrange(ge1b, 1, 4)
gen anti_eastasia     = ge1c - 1 if inrange(ge1c, 1, 4)
gen edu_fairness      = 6 - f2d if inrange(f2d, 1, 5)
gen anti_edu_ineq     = 6 - f8b if inrange(f8b, 1, 5)

collapse ///
    (count) n_obs=nat_interest ///
    (mean) nat_interest import_protect culture_protect country_affect anti_eastasia ///
           edu_fairness anti_edu_ineq female_share=female minority_share=minority ///
           urban_share=urban_hukou local_share=local_hukou, ///
    by(countyid_curr6 birth_i ln_martyr_per100k_1953)

gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
save "${proj}/data/temp/cgss2008_attitude_county_birth_panel_v2.dta", replace

capture program drop _run_outcome
program define _run_outcome, rclass
    syntax , YVAR(name) MODEL(name)
    use "${proj}/data/temp/cgss2008_attitude_county_birth_panel_v2.dta", clear
    keep if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, n_obs)
    quietly count
    local n_cells = r(N)
    quietly summarize n_obs
    local n_resp = r(sum)
    quietly summarize n_obs if post==0
    local n_pre = r(sum)
    quietly summarize n_obs if post==1
    local n_post = r(sum)
    quietly reghdfejl `yvar' c.ln_martyr_per100k_1953##ib0.post ///
        female_share minority_share urban_share [aw=n_obs], ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar N_resp = `n_resp'
    estadd scalar N_pre = `n_pre'
    estadd scalar N_post = `n_post'
    return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))
    return scalar n_cells = `n_cells'
    return scalar n_resp = `n_resp'
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
gen n_cells = .
gen n_resp = .
gen n_pre = .
gen n_post = .
save `summary', replace

local outcomes nat_interest import_protect culture_protect country_affect anti_eastasia edu_fairness anti_edu_ineq
local models ""

foreach y of local outcomes {
    local m = "m_`y'"
    quietly _run_outcome, yvar(`y') model(`m')
    local models "`models' `m'"
    use `summary', clear
    local row = _N + 1
    set obs `row'
    replace outcome = "`y'" in `row'
    replace b = r(b) in `row'
    replace se = r(se) in `row'
    replace p = r(p) in `row'
    replace n_cells = r(n_cells) in `row'
    replace n_resp = r(n_resp) in `row'
    replace n_pre = r(n_pre) in `row'
    replace n_post = r(n_post) in `row'
    save `summary', replace
}

use `summary', clear
export delimited using "${proj}/result/table/mechanism_cgss_attitudes_reghdfejl_summary_v2.csv", replace
save "${proj}/result/table/mechanism_cgss_attitudes_reghdfejl_summary_v2.dta", replace

esttab `models' using "${proj}/result/table/mechanism_cgss_attitudes_reghdfejl_v2.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N_resp N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/mechanism_cgss_attitudes_reghdfejl_v2.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N_resp N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
