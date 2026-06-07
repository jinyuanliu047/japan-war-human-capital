*******************************************************
* Triple diff appendix: link-based anti-Japanese base indicator
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

capture program drop _grab3
program define _grab3, rclass
    capture return scalar b_base = _b[1.post#c.ln_martyr_per100k_1953]
    capture return scalar se_base = _se[1.post#c.ln_martyr_per100k_1953]
    if _rc != 0 {
        return scalar b_base = _b[c.ln_martyr_per100k_1953#1.post]
        return scalar se_base = _se[c.ln_martyr_per100k_1953#1.post]
    }
    capture return scalar b_diff = _b[1.base_link_any#1.post#c.ln_martyr_per100k_1953]
    capture return scalar se_diff = _se[1.base_link_any#1.post#c.ln_martyr_per100k_1953]
    if _rc != 0 {
        return scalar b_diff = _b[c.ln_martyr_per100k_1953#1.post#1.base_link_any]
        return scalar se_diff = _se[c.ln_martyr_per100k_1953#1.post#1.base_link_any]
    }
    return scalar p_base = 2*ttail(e(df_r), abs(return(b_base)/return(se_base)))
    return scalar p_diff = 2*ttail(e(df_r), abs(return(b_diff)/return(se_diff)))
end

eststo clear
tempfile summary
clear
set obs 0
gen wave = .
gen b_base = .
gen se_base = .
gen p_base = .
gen b_diff = .
gen se_diff = .
gen p_diff = .
gen n = .
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if `w'==1990 local hi = 1968
    if `w'==2000 local hi = 1978

    use "${proj}/data/temp/did_`w'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    gen birth_i = floor(birthyr)
    gen post = birth_i>=1940
    merge m:1 countyid_curr6 using "${proj}/data/temp/antijap_base_link_indicator_v2.dta", keep(master match) nogen
    replace base_link_any = 0 if missing(base_link_any)
    egen county_num = group(countyid_curr6)

    quietly count
    local n = r(N)

    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post##ib0.base_link_any ///
        [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store t`w'
    quietly _grab3

    use `summary', clear
    set obs `=_N+1'
    replace wave = `w' in L
    replace b_base = r(b_base) in L
    replace se_base = r(se_base) in L
    replace p_base = r(p_base) in L
    replace b_diff = r(b_diff) in L
    replace se_diff = r(se_diff) in L
    replace p_diff = r(p_diff) in L
    replace n = `n' in L
    save `summary', replace
}

use `summary', clear
export delimited using "${proj}/result/table/main_antijap_base_link_triplediff_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_antijap_base_link_triplediff_reghdfejl_summary_v1.dta", replace

esttab t1982 t1990 t2000 using "${proj}/result/table/main_antijap_base_link_triplediff_reghdfejl_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953 1.base_link_any#1.post#c.ln_martyr_per100k_1953) ///
    se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab t1982 t1990 t2000 using "${proj}/result/table/main_antijap_base_link_triplediff_reghdfejl_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953 1.base_link_any#1.post#c.ln_martyr_per100k_1953) ///
    se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
