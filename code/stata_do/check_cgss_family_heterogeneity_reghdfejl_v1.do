*******************************************************
* CGSS 2008 supplemental heterogeneity
* Y: years of schooling
* Split by sibling size and birth-order proxy
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

use serial countyid a1 a2 a3c a6 a14a b21 b22 b23 b24 using "${proj}/data/raw/cgss2008_14.dta", clear
gen str6 countyid_curr6 = string(countyid, "%06.0f")
merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", ///
    keep(match) nogen keepusing(ln_martyr_per100k_1953)

gen birth_i = floor(a2)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940

gen female = (a1 == 2) if inlist(a1, 1, 2)
gen minority = (a6 != 1) if inrange(a6, 1, 8)
gen urban_hukou = inlist(a14a, 1, 2, 3, 4, 5) if inrange(a14a, 1, 6)
gen eduy = a3c if inrange(a3c, 0, 30)

gen older_sib = b21 + b22 if !missing(b21, b22)
gen sibling_total = b21 + b22 + b23 + b24 if !missing(b21, b22, b23, b24)
gen firstborn = (older_sib == 0) if !missing(older_sib)

quietly summarize sibling_total, detail
local p50 = r(p50)
gen large_sibship = (sibling_total > `p50') if !missing(sibling_total)

egen county_num = group(countyid_curr6)

capture program drop _run_split
program define _run_split, rclass
    syntax , GROUPVAR(name) GVAL(integer) MODEL(name) GLABEL(string)
    use "${proj}/data/raw/cgss2008_14.dta", clear
    keep serial countyid a1 a2 a3c a6 a14a b21 b22 b23 b24
    gen str6 countyid_curr6 = string(countyid, "%06.0f")
    merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", ///
        keep(match) nogen keepusing(ln_martyr_per100k_1953)
    gen birth_i = floor(a2)
    keep if inrange(birth_i, 1920, 1990)
    drop if birth_i == 1939
    gen post = birth_i >= 1940
    gen female = (a1 == 2) if inlist(a1, 1, 2)
    gen minority = (a6 != 1) if inrange(a6, 1, 8)
    gen urban_hukou = inlist(a14a, 1, 2, 3, 4, 5) if inrange(a14a, 1, 6)
    gen eduy = a3c if inrange(a3c, 0, 30)
    gen older_sib = b21 + b22 if !missing(b21, b22)
    gen sibling_total = b21 + b22 + b23 + b24 if !missing(b21, b22, b23, b24)
    gen firstborn = (older_sib == 0) if !missing(older_sib)
    quietly summarize sibling_total, detail
    local p50 = r(p50)
    gen large_sibship = (sibling_total > `p50') if !missing(sibling_total)
    egen county_num = group(countyid_curr6)
    keep if `groupvar' == `gval'
    keep if !missing(eduy, ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou)
    quietly count
    local n = r(N)
    quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Group "`glabel'"
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))
    return scalar n = `n'
end

eststo clear

tempfile summary
clear
set obs 0
gen str16 dim = ""
gen str12 grp = ""
gen b = .
gen se = .
gen p = .
gen n = .
save `summary', replace

local models ""

foreach spec in firstborn large_sibship {
    foreach g in 0 1 {
        local glab = cond("`spec'"=="firstborn", cond(`g'==1,"firstborn","laterborn"), cond(`g'==1,"large_sib","small_sib"))
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
export delimited using "${proj}/result/table/cgss_family_heterogeneity_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/cgss_family_heterogeneity_reghdfejl_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/cgss_family_heterogeneity_reghdfejl_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/cgss_family_heterogeneity_reghdfejl_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
