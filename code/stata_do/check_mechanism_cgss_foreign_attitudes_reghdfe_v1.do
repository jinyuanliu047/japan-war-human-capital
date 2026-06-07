*******************************************************
* CGSS 2008 foreign-attitude appendix mechanism table
* Post-war cohort defined as birth >= 1946
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

use serial countyid a1 a2 a6 a14a a14d using "${proj}/data/raw/cgss2008_14.dta", clear
merge 1:1 serial using "${proj}/data/raw/cgss2008b_14.dta", keep(match) nogen

gen str6 countyid_curr6 = string(countyid, "%06.0f")
merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", ///
    keep(match) nogen keepusing(ln_martyr_per100k_1953)

gen birth_i = floor(a2)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1945
gen post = birth_i >= 1946

gen female = (a1 == 2) if inlist(a1, 1, 2)
gen minority = (a6 != 1) if inrange(a6, 1, 56)
gen urban_hukou = inlist(a14a, 1, 2, 3, 4, 5) if inrange(a14a, 1, 6)
gen local_hukou = inlist(a14d, 1, 2) if inrange(a14d, 1, 4)
egen county_num = group(countyid_curr6)

gen japan_anime_freq = 5 - ga1 if inrange(ga1, 1, 4)
gen chinese_movie_freq = 5 - ga2 if inrange(ga2, 1, 4)
gen korean_drama_freq = 5 - ga3 if inrange(ga3, 1, 4)
gen country_affect = 5 - ge1b if inrange(ge1b, 1, 4)
gen eastasia_affect = 5 - ge1c if inrange(ge1c, 1, 4)
gen import_protect = 8 - gl1a if inrange(gl1a, 1, 7)
gen nat_interest = 8 - gl1b if inrange(gl1b, 1, 7)
gen culture_protect = 8 - gl1c if inrange(gl1c, 1, 7)

label var japan_anime_freq "Watch Japanese anime"
label var chinese_movie_freq "Watch Chinese movies"
label var korean_drama_freq "Watch Korean TV"
label var import_protect "Support import limits"
label var nat_interest "National interest first"
label var culture_protect "Foreign culture harmful"
label var country_affect "Affect to country"
label var eastasia_affect "Affect to East Asia"

local outcomes japan_anime_freq import_protect nat_interest culture_protect country_affect eastasia_affect chinese_movie_freq korean_drama_freq
local models ""

tempfile summary
clear
set obs 0
gen str32 outcome = ""
gen b = .
gen se = .
gen p = .
gen n = .
save `summary', replace

foreach y of local outcomes {
    quietly reghdfe `y' c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou ///
        if !missing(`y', ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou), ///
        absorb(county_num birth_i) vce(cluster county_num)
    local m = "m_`y'"
    estimates store `m'
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    local models "`models' `m'"

    local b = _b[1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    quietly count if !missing(`y', ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou)
    local n = r(N)

    use `summary', clear
    local row = _N + 1
    set obs `row'
    replace outcome = "`y'" in `row'
    replace b = `b' in `row'
    replace se = `se' in `row'
    replace p = `p' in `row'
    replace n = `n' in `row'
    save `summary', replace
}

use `summary', clear
export delimited using "${proj}/result/table/mechanism_cgss_foreign_attitudes_reghdfe_summary_v1.csv", replace

esttab `models' using "${proj}/result/table/mechanism_cgss_foreign_attitudes_reghdfe_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post-war cohort × War exposure") ///
    scalar(Controls County_FE Cohort_FE) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/mechanism_cgss_foreign_attitudes_reghdfe_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post-war cohort × War exposure") ///
    scalar(Controls County_FE Cohort_FE) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
