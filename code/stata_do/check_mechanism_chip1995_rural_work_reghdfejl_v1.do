*******************************************************
* CHIP 1995 rural individual: work and occupation outcomes
* Geography uses A1 = province + county/city code
* 0/1 outcomes, all regressions include controls
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

use A1 B105 B106 B107 B110A B114 B115 using "${proj}/data/raw/1995/1995_DS0001_rural_individual/DS0001_rural_individual/03012-0001-Data.dta", clear

gen str6 countyid_curr6 = string(A1, "%06.0f")
merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", ///
    keep(match) nogen keepusing(ln_martyr_per100k_1953)

gen birth_i = 1995 - B105 if !missing(B105)
keep if inrange(birth_i, 1920, 1977)
drop if birth_i == 1939
gen post = birth_i >= 1940

gen female = (B106 == 2) if inlist(B106, 1, 2)
gen eduy = B110A if inrange(B110A, 0, 30)

gen any_work = inlist(B107, 1, 2) if inrange(B107, 0, 9)
gen offfarm_work = (B107 == 2) if inrange(B107, 0, 9)
gen white_collar = inlist(B114, 4, 5, 6, 7, 8, 10) if inrange(B114, 0, 11)
gen industry_sector = inlist(B115, 4, 5, 6, 7, 8, 14, 16, 17) if inrange(B115, 0, 19)

egen county_num = group(countyid_curr6)
label var any_work "Any work"
label var offfarm_work "Off-farm work"
label var white_collar "White-collar/cadre"
label var industry_sector "Industry/service sector"

capture program drop _run_one
program define _run_one, rclass
    syntax , YVAR(name) MODEL(name)
    use "${proj}/data/raw/1995/1995_DS0001_rural_individual/DS0001_rural_individual/03012-0001-Data.dta", clear
    keep A1 B105 B106 B107 B110A B114 B115
    gen str6 countyid_curr6 = string(A1, "%06.0f")
    merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", ///
        keep(match) nogen keepusing(ln_martyr_per100k_1953)
    gen birth_i = 1995 - B105 if !missing(B105)
    keep if inrange(birth_i, 1920, 1977)
    drop if birth_i == 1939
    gen post = birth_i >= 1940
    gen female = (B106 == 2) if inlist(B106, 1, 2)
    gen eduy = B110A if inrange(B110A, 0, 30)
    gen any_work = inlist(B107, 1, 2) if inrange(B107, 0, 9)
    gen offfarm_work = (B107 == 2) if inrange(B107, 0, 9)
    gen white_collar = inlist(B114, 4, 5, 6, 7, 8, 10) if inrange(B114, 0, 11)
    gen industry_sector = inlist(B115, 4, 5, 6, 7, 8, 14, 16, 17) if inrange(B115, 0, 19)
    egen county_num = group(countyid_curr6)
    keep if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, female, eduy)
    quietly count
    local n = r(N)
    quietly count if post==0
    local n_pre = r(N)
    quietly count if post==1
    local n_post = r(N)
    quietly reghdfejl `yvar' c.ln_martyr_per100k_1953##ib0.post female c.eduy, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
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

local outcomes any_work offfarm_work white_collar industry_sector
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
export delimited using "${proj}/result/table/mechanism_chip1995_rural_work_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/mechanism_chip1995_rural_work_reghdfejl_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/mechanism_chip1995_rural_work_reghdfejl_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/mechanism_chip1995_rural_work_reghdfejl_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
