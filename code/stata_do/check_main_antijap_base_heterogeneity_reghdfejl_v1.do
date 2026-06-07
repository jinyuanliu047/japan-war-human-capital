*******************************************************
* Heterogeneity: anti-Japanese base-site counties
* Operationalized from heritage sites with "抗日根据地/根据地"
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
}
capture which esttab
if _rc != 0 ssc install estout, replace

capture program drop _run_split
program define _run_split, rclass
    syntax , WAVE(integer) HI(integer) GVAL(integer) MODEL(name)
    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    gen birth_i = floor(birthyr)
    gen post = birth_i>=1940
    merge m:1 countyid_curr6 using "${proj}/data/temp/antijap_base_site_indicator_v1.dta", keep(master match) nogen
    replace base_site_any = 0 if missing(base_site_any)
    keep if base_site_any == `gval'
    egen county_num = group(countyid_curr6)
    quietly count
    local n = r(N)
    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post ///
        [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local BaseSite = "`gval'"
    estadd scalar N_sample = `n'
    return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))
    return scalar n = `n'
end

eststo clear
tempfile summary
clear
set obs 0
gen wave = .
gen base_site_any = .
gen b = .
gen se = .
gen p = .
gen n = .
save `summary', replace

local models ""
foreach w in 1982 1990 2000 {
    local hi = 1960
    if `w'==1990 local hi = 1968
    if `w'==2000 local hi = 1978
    foreach g in 0 1 {
        local m = "m`w'_g`g'"
        quietly _run_split, wave(`w') hi(`hi') gval(`g') model(`m')
        local models "`models' `m'"
        use `summary', clear
        set obs `=_N+1'
        replace wave = `w' in L
        replace base_site_any = `g' in L
        replace b = r(b) in L
        replace se = r(se) in L
        replace p = r(p) in L
        replace n = r(n) in L
        save `summary', replace
    }
}

use `summary', clear
export delimited using "${proj}/result/table/main_antijap_base_heterogeneity_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_antijap_base_heterogeneity_reghdfejl_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/main_antijap_base_heterogeneity_reghdfejl_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) scalar(BaseSite N_sample) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/main_antijap_base_heterogeneity_reghdfejl_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) scalar(BaseSite N_sample) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
