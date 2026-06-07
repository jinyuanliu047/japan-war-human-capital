/*  ================================================================
    PPML version of main baseline regressions
    Uses ppmlhdfe for Poisson pseudo-maximum likelihood
    Simplified spec: treat*post, absorb, cluster — no ib0, no drop
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")
global outdir "${proj}/paper/assets/tables"

capture which ppmlhdfe
if _rc != 0 ssc install ppmlhdfe, replace
capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

*--------------------------------------------------------------
* county dictionary + crosswalk (same as main)
*--------------------------------------------------------------
import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
keep GBCounty
destring GBCounty, replace force
drop if missing(GBCounty)
gen str6 county_curr6 = string(GBCounty, "%06.0f")
gen str6 old6 = county_curr6
gen str6 curr_dict = county_curr6
keep old6 curr_dict
duplicates drop old6, force
tempfile county_dict
save `county_dict'
global county_dict_tmp "`county_dict'"

import delimited "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", clear varnames(1) stringcols(_all)
rename countyid_old6 old6
rename countyid_curr6_final county_curr6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = subinstr(county_curr6, ".0", "", .)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'
global cw1982_tmp "`cw1982'"

capture program drop _resolve_old6_map
program define _resolve_old6_map
    gen str6 county_curr6 = ""
    gen str30 route = "unmatched"
    replace county_curr6 = "310101" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"
    tempfile left
    save `left'
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    drop county_curr6
    rename curr_res county_curr6
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace county_curr6 = curr_dict if county_curr6=="" & curr_dict!=""
    drop curr_dict route
end

*--------------------------------------------------------------
* treatment
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw
gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
tempfile treat
save `treat'
global treat_tmp "`treat'"

*--------------------------------------------------------------
* mapping 1990/2000
*--------------------------------------------------------------
use county using "$c1990", clear
drop if missing(county)
gen str6 old6 = string(county, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map1990
save `map1990'
global map1990_tmp "`map1990'"

use uid using "$c2000", clear
drop if missing(uid)
gen str6 old6 = string(uid, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map2000
save `map2000'
global map2000_tmp "`map2000'"

*==============================================================
*  Load each wave
*==============================================================
use countyid birthyr eduy ethniccn using "$c1982", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen minority = (ethniccn != 1) if !missing(ethniccn)
keep if inrange(birthyr, 1920, 1956)
rename county_curr6 countyid_curr6
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 1
tempfile w1982
save `w1982'

use county age_c age educ race using "$c1990", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birthyr = 1000 + age_c*100 + age
gen eduy = .
replace eduy = 0  if educ==1
replace eduy = 6  if educ==2
replace eduy = 9  if educ==3
replace eduy = 12 if inlist(educ,4,5)
replace eduy = 15 if educ==6
replace eduy = 16 if educ==7
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 2
tempfile w1990
save `w1990'

use uid birthyr eduyr race using "$c2000", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 3
tempfile w2000
save `w2000'

*==============================================================
*  Pool
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'

* eduy must be non-negative for PPML (it already is: min 0)
* But PPML with zeros is fine
replace eduy = 0 if eduy < 0

encode countyid_curr6, gen(county_num)

di "=== POOLED N = " _N " ==="

*==============================================================
*  Helper: stars
*==============================================================
capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*==============================================================
*  PPML regressions — simplified spec per user request
*  No ib0, no drop. Just treat*post + absorb + cluster
*==============================================================

foreach cutoff in 1940 1946 {
    capture drop post treat_ihs_post treat_d_post
    gen post = (birth_i >= `cutoff')

    * IHS rate interaction
    gen treat_ihs_post = ihs_rate * post

    * Dummy interaction
    gen treat_d_post = d_count_high * post

    * ---- (1) OLS IHS (reference, same simplified spec) ----
    di "=== Cutoff `cutoff': OLS IHS ==="
    reghdfejl eduy treat_ihs_post ihs_rate post minority i.wave, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_ols_ihs_`cutoff' = _b[treat_ihs_post]
    local se_ols_ihs_`cutoff' = _se[treat_ihs_post]
    local p_ols_ihs_`cutoff' = 2*ttail(e(df_r), abs(`b_ols_ihs_`cutoff''/`se_ols_ihs_`cutoff''))
    local n_ols_ihs_`cutoff' = e(N)

    * ---- (2) PPML IHS ----
    di "=== Cutoff `cutoff': PPML IHS ==="
    ppmlhdfe eduy treat_ihs_post ihs_rate post minority i.wave, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_ppml_ihs_`cutoff' = _b[treat_ihs_post]
    local se_ppml_ihs_`cutoff' = _se[treat_ihs_post]
    local p_ppml_ihs_`cutoff' = 2*normal(-abs(`b_ppml_ihs_`cutoff''/`se_ppml_ihs_`cutoff''))
    local n_ppml_ihs_`cutoff' = e(N)

    * ---- (3) OLS Dummy (reference) ----
    di "=== Cutoff `cutoff': OLS Dummy ==="
    reghdfejl eduy treat_d_post d_count_high post minority i.wave, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_ols_d_`cutoff' = _b[treat_d_post]
    local se_ols_d_`cutoff' = _se[treat_d_post]
    local p_ols_d_`cutoff' = 2*ttail(e(df_r), abs(`b_ols_d_`cutoff''/`se_ols_d_`cutoff''))
    local n_ols_d_`cutoff' = e(N)

    * ---- (4) PPML Dummy ----
    di "=== Cutoff `cutoff': PPML Dummy ==="
    ppmlhdfe eduy treat_d_post d_count_high post minority i.wave, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_ppml_d_`cutoff' = _b[treat_d_post]
    local se_ppml_d_`cutoff' = _se[treat_d_post]
    local p_ppml_d_`cutoff' = 2*normal(-abs(`b_ppml_d_`cutoff''/`se_ppml_d_`cutoff''))
    local n_ppml_d_`cutoff' = e(N)

    drop post treat_ihs_post treat_d_post
}

*==============================================================
*  Output table
*==============================================================
foreach cutoff in 1940 1946 {
    foreach v in ols_ihs ols_d ppml_ihs ppml_d {
        _stars `p_`v'_`cutoff''
        local s_`v'_`cutoff' "`r(star)'"
    }
}

* Pre-format all values
foreach cutoff in 1940 1946 {
    foreach v in ols_ihs ppml_ihs ols_d ppml_d {
        local fb_`v'_`cutoff' : di %9.4f `b_`v'_`cutoff''
        local fse_`v'_`cutoff' : di %7.4f `se_`v'_`cutoff''
        local fn_`v'_`cutoff' : di %12.0fc `n_`v'_`cutoff''
    }
}

* Write combined table: 1940 and 1946, OLS vs PPML, IHS vs Dummy
tempname fh
file open `fh' using "$outdir/pooled_ppml_comparison_v1.tex", write replace
file write `fh' "{"                                                           _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}"              _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule"                                                    _n
file write `fh' "            &\multicolumn{2}{c}{Cutoff 1940}&\multicolumn{2}{c}{Cutoff 1946}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}"           _n
file write `fh' "            &OLS&PPML&OLS&PPML\\"                           _n
file write `fh' "\midrule"                                                    _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
file write `fh' "Post $\times$ IHS(rate)&`fb_ols_ihs_1940'\sym{`s_ols_ihs_1940'}&`fb_ppml_ihs_1940'\sym{`s_ppml_ihs_1940'}&`fb_ols_ihs_1946'\sym{`s_ols_ihs_1946'}&`fb_ppml_ihs_1946'\sym{`s_ppml_ihs_1946'}\\" _n
file write `fh' "            &( `fse_ols_ihs_1940')&( `fse_ppml_ihs_1940')&( `fse_ols_ihs_1946')&( `fse_ppml_ihs_1946')\\[0.5em]" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
file write `fh' "Post $\times$ High count&`fb_ols_d_1940'\sym{`s_ols_d_1940'}&`fb_ppml_d_1940'\sym{`s_ppml_d_1940'}&`fb_ols_d_1946'\sym{`s_ols_d_1946'}&`fb_ppml_d_1946'\sym{`s_ppml_d_1946'}\\" _n
file write `fh' "            &( `fse_ols_d_1940')&( `fse_ppml_d_1940')&( `fse_ols_d_1946')&( `fse_ppml_d_1946')\\" _n
file write `fh' "\midrule"                                                    _n
file write `fh' "Estimator&OLS&PPML&OLS&PPML\\"                             _n
file write `fh' "Minority control&     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "County FE&     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Cohort FE&     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Wave FE&     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Obs (IHS)&`fn_ols_ihs_1940'&`fn_ppml_ihs_1940'&`fn_ols_ihs_1946'&`fn_ppml_ihs_1946'\\" _n
file write `fh' "Obs (Dummy)&`fn_ols_d_1940'&`fn_ppml_d_1940'&`fn_ols_d_1946'&`fn_ppml_d_1946'\\" _n
file write `fh' "\bottomrule"                                                 _n
file write `fh' "\end{tabular*}"                                              _n
file write `fh' "}"                                                           _n
file close `fh'

di as text "Written: $outdir/pooled_ppml_comparison_v1.tex"

exit, clear
