*******************************************************
* CGSS 2008 birth-order / older-sibling heterogeneity
* Main version uses direct sibling counts in CGSS
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

use serial countyid a1 a2 a3c a6 a14a a14d b21 b22 b23 b24 using "${proj}/data/raw/cgss2008_14.dta", clear
gen str6 countyid_curr6 = string(countyid, "%06.0f")
merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", ///
    keep(match) nogen keepusing(ln_martyr_per100k_1953)

gen birth_i = floor(a2)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940

gen female = (a1 == 2) if inlist(a1, 1, 2)
gen minority = (a6 != 1) if inrange(a6, 1, 56)
gen urban_hukou = inlist(a14a, 1, 2, 3, 4, 5) if inrange(a14a, 1, 6)
gen local_hukou = inlist(a14d, 1, 2) if inrange(a14d, 1, 4)
gen eduy = a3c if inrange(a3c, 0, 30)

gen older_brother = b21 if inrange(b21, 0, 20)
gen older_sister = b22 if inrange(b22, 0, 20)
gen younger_brother = b23 if inrange(b23, 0, 20)
gen younger_sister = b24 if inrange(b24, 0, 20)
gen older_sib = older_brother + older_sister if !missing(older_brother, older_sister)
gen total_sib = older_brother + older_sister + younger_brother + younger_sister if !missing(older_brother, older_sister, younger_brother, younger_sister)

gen firstborn = (older_sib == 0) if !missing(older_sib)
gen any_older_sib = (older_sib > 0) if !missing(older_sib)
gen has_older_brother = (older_brother > 0) if !missing(older_brother)
gen has_older_sister = (older_sister > 0) if !missing(older_sister)
gen older_sib_2plus = (older_sib >= 2) if !missing(older_sib)

egen county_num = group(countyid_curr6)

tempfile cgss_main
save `cgss_main', replace
global cgss_birth_tmp "`cgss_main'"

tempfile audit
preserve
    keep older_brother older_sister younger_brother younger_sister older_sib total_sib firstborn any_older_sib has_older_brother has_older_sister older_sib_2plus
    gen one = 1
    collapse (count) n_obs=one ///
        (mean) older_brother older_sister younger_brother younger_sister older_sib total_sib ///
               firstborn any_older_sib has_older_brother has_older_sister older_sib_2plus
    export delimited using "${proj}/result/table/cgss_birthorder_audit_v1.csv", replace
restore

capture program drop _run_split
program define _run_split, rclass
    syntax , GROUPVAR(name) GVAL(integer) MODEL(name) GLABEL(string)
    use "$cgss_birth_tmp", clear
    quietly count if `groupvar' == `gval' & !missing(eduy, ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou)
    local n = r(N)
    quietly reghdfe eduy c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou ///
        if `groupvar' == `gval' & !missing(eduy, ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou), ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Group "`glabel'"
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
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
gen str24 dim = ""
gen str20 grp = ""
gen b = .
gen se = .
gen p = .
gen n = .
save `summary', replace

local specs firstborn any_older_sib has_older_brother has_older_sister older_sib_2plus
local models ""

foreach spec of local specs {
    foreach g in 0 1 {
        local glab = cond(`g' == 1, "`spec'=1", "`spec'=0")
        local m = "m_`spec'_`g'"
        quietly _run_split, groupvar(`spec') gval(`g') model(`m') glabel("`glab'")
        local models "`models' `m'"
        use `summary', clear
        local row = _N + 1
        set obs `row'
        replace dim = "`spec'" in `row'
        replace grp = "`glab'" in `row'
        replace b = r(b) in `row'
        replace se = r(se) in `row'
        replace p = r(p) in `row'
        replace n = r(n) in `row'
        save `summary', replace
    }
}

use `summary', clear
export delimited using "${proj}/result/table/cgss_birthorder_heterogeneity_reghdfejl_summary_v2.csv", replace
save "${proj}/result/table/cgss_birthorder_heterogeneity_reghdfejl_summary_v2.dta", replace

esttab `models' using "${proj}/result/table/cgss_birthorder_heterogeneity_reghdfejl_v2.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE N_sample) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/cgss_birthorder_heterogeneity_reghdfejl_v2.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE N_sample) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
