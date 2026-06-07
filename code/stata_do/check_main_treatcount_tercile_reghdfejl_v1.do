*******************************************************
* Heterogeneity by raw martyr count tercile
* Grouping variable: martyr_count_1931_1945
* Regression X: ln_martyr_per100k_1953
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 {
    ssc install estout, replace
}

capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
}

capture program drop _prep_wave
program define _prep_wave
    syntax , WAVE(integer) HI(integer)

    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr,1920,`hi')
    drop if floor(birthyr)==1939
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953) & !missing(martyr_count_1931_1945)
    drop if countyid_curr6=="" | countyid_curr6=="000000"

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)
    sort county_num birth_i

    by county_num: egen __raw = max(martyr_count_1931_1945)
    egen __tag = tag(county_num)
    xtile __ter = __raw if __tag==1, nq(3)
    by county_num: egen treatcount_tercile = max(__ter)

    drop __raw __tag __ter
end

capture program drop _run_one
program define _run_one, rclass
    syntax , PANEL(string) GROUPVAL(integer) MODEL(string) GLABEL(string)

    use "`panel'", clear

    quietly count if treatcount_tercile==`groupval'
    return scalar n_cells = r(N)

    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post if treatcount_tercile==`groupval', ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Group "`glabel'"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
end

eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str24 dim = ""
gen str8 grp = ""
gen b = .
gen se = .
gen p = .
gen n_cells = .
save `summary', replace

local models ""

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978

    quietly _prep_wave, wave(`w') hi(`hi')
    tempfile wpanel
    save `wpanel', replace

    foreach g in 1 2 3 {
        local m = "trc`w'_`g'"
        quietly _run_one, panel("`wpanel'") groupval(`g') model("`m'") glabel("RC`g'")
        local models "`models' `m'"
        use `summary', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        replace dim = "rawcount_tercile" in `n'
        replace grp = "RC`g'" in `n'
        replace b = r(b) in `n'
        replace se = r(se) in `n'
        replace p = r(p) in `n'
        replace n_cells = r(n_cells) in `n'
        save `summary', replace
    }
}

use `summary', clear
gen t_abs = abs(b/se)
sort wave grp
export delimited using "${proj}/result/table/main_treatcount_tercile_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_treatcount_tercile_reghdfejl_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/main_treatcount_tercile_reghdfejl_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/main_treatcount_tercile_reghdfejl_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
