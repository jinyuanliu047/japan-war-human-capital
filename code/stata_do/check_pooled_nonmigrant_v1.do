*******************************************************
* MIGRATION ROBUSTNESS — pooled baseline DID on
* non-movers only, vs full sample.
*
* Outcome: eduy (years of schooling).
* Non-migrant flag:
*   1990 raw census   regstatu == 1  (registered locally)
*   2000 raw census   r061     == 1  (registered locally)
*   1982 IPUMS         not identified  -> kept in sample
*
* Two cutoffs (1940 / 1946), two treatment forms
* (IHS rate, above-median dummy), two samples
* (full / non-migrant).  Eight DID coefficients.
*******************************************************

clear all
set more off
set maxvar 10000

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/census_1982_cleaned.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

global census1982 "${proj}/data/temp/census_1982_cleaned.dta"
global census1990 "${proj}/data/raw/census/census1990.dta"
global census2000 "${proj}/data/raw/census/census2000.dta"

global outdir "${proj}/paper/assets/tables"

capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

*--- county dictionary + crosswalk ----------------------------------
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
    replace county_curr6 = "310101" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    drop county_curr6
    rename curr_res county_curr6
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace county_curr6 = curr_dict if county_curr6=="" & curr_dict!=""
    drop curr_dict
end

use county using "$census1990", clear
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

use uid using "$census2000", clear
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

*--- treatment ------------------------------------------------------
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

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*=== Wave 1982 ======================================================
use countyid birthyr eduy ethniccn using "$census1982", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birth_i = floor(birthyr)
gen minority = (ethniccn != 1) if !missing(ethniccn)
keep if inrange(birth_i, 1920, 1956)
keep if inrange(eduy, 0, 25)
gen byte nonmigrant = 1
gen wave = 1
keep countyid_curr6 birth_i eduy minority nonmigrant wave
tempfile w1982
save `w1982'

*=== Wave 1990 ======================================================
use county age_c age educ race regstatu using "$census1990", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birthyr = 1000 + age_c*100 + age
gen birth_i = floor(birthyr)
gen minority = (race != 1) if !missing(race)
gen eduy = .
replace eduy = 0  if educ==1
replace eduy = 6  if educ==2
replace eduy = 9  if educ==3
replace eduy = 12 if inlist(educ,4,5)
replace eduy = 15 if educ==6
replace eduy = 16 if educ==7
keep if inrange(birth_i, 1920, 1956)
drop if missing(eduy)
keep if inrange(eduy, 0, 25)
gen byte nonmigrant = (regstatu == 1) if !missing(regstatu)
replace nonmigrant = 1 if missing(regstatu)
gen wave = 2
keep countyid_curr6 birth_i eduy minority nonmigrant wave
tempfile w1990
save `w1990'

*=== Wave 2000 ======================================================
use uid birthyr eduyr race r061 using "$census2000", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birth_i = floor(birthyr)
gen minority = (race != 1) if !missing(race)
gen eduy = eduyr
keep if inrange(birth_i, 1920, 1956)
drop if missing(eduy)
keep if inrange(eduy, 0, 25)
gen byte nonmigrant = (r061 == 1) if !missing(r061)
replace nonmigrant = 1 if missing(r061)
gen wave = 3
keep countyid_curr6 birth_i eduy minority nonmigrant wave
tempfile w2000
save `w2000'

*=== Pool, merge treatment, drop far-west ===========================
use `w1982', clear
append using `w1990'
append using `w2000'

merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen

encode countyid_curr6, gen(county_num)

*=== TWO collapses: full vs non-migrant =============================
preserve
    gen cell_n = 1
    collapse (mean) eduy minority_share=minority (sum) cell_n, by(countyid_curr6 county_num birth_i wave ihs_rate d_count_high)
    tempfile pooled_full
    save `pooled_full'
restore

preserve
    keep if nonmigrant == 1
    gen cell_n = 1
    collapse (mean) eduy minority_share=minority (sum) cell_n, by(countyid_curr6 county_num birth_i wave ihs_rate d_count_high)
    tempfile pooled_nm
    save `pooled_nm'
restore

*=== Regressions ====================================================
foreach samp in full nm {
    use `pooled_`samp'', clear
    foreach cutoff in 1940 1946 {
        capture drop post treat_ihs_post treat_d_post
        gen post = (birth_i >= `cutoff')
        gen treat_ihs_post = ihs_rate * post
        gen treat_d_post = d_count_high * post
        local omit = cond(`cutoff'==1940, 1939, 1945)

        quietly reghdfejl eduy treat_ihs_post ihs_rate post minority_share i.wave [aw=cell_n] if birth_i != `omit', absorb(county_num birth_i) vce(cluster county_num)
        local b_i_`samp'_`cutoff' = _b[treat_ihs_post]
        local se_i_`samp'_`cutoff' = _se[treat_ihs_post]
        local p_i_`samp'_`cutoff' = 2*ttail(e(df_r), abs(`b_i_`samp'_`cutoff''/`se_i_`samp'_`cutoff''))
        local n_i_`samp'_`cutoff' = e(N)

        quietly reghdfejl eduy treat_d_post d_count_high post minority_share i.wave [aw=cell_n] if birth_i != `omit', absorb(county_num birth_i) vce(cluster county_num)
        local b_d_`samp'_`cutoff' = _b[treat_d_post]
        local se_d_`samp'_`cutoff' = _se[treat_d_post]
        local p_d_`samp'_`cutoff' = 2*ttail(e(df_r), abs(`b_d_`samp'_`cutoff''/`se_d_`samp'_`cutoff''))
        local n_d_`samp'_`cutoff' = e(N)
    }
}

*=== Output table ===================================================
foreach samp in full nm {
    foreach cutoff in 1940 1946 {
        foreach v in i d {
            _stars `p_`v'_`samp'_`cutoff''
            local s_`v'_`samp'_`cutoff' "`r(star)'"
            local fb_`v'_`samp'_`cutoff' : di %9.4f `b_`v'_`samp'_`cutoff''
            local fse_`v'_`samp'_`cutoff' : di %7.4f `se_`v'_`samp'_`cutoff''
        }
    }
    local fn_full_1940 : di %12.0fc `n_i_full_1940'
    local fn_full_1946 : di %12.0fc `n_i_full_1946'
    local fn_nm_1940   : di %12.0fc `n_i_nm_1940'
    local fn_nm_1946   : di %12.0fc `n_i_nm_1946'
}

tempname fh
file open `fh' using "$outdir/nonmigrant_robust_pooled_v1.tex", write replace
file write `fh' "{"                                                           _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}"              _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule"                                                    _n
file write `fh' "&\multicolumn{2}{c}{Cutoff 1940}&\multicolumn{2}{c}{Cutoff 1946}\\" _n
file write `fh' "\cmidrule(lr){2-3}\cmidrule(lr){4-5}"                         _n
file write `fh' "&Full&Non-mover&Full&Non-mover\\"                            _n
file write `fh' "\midrule"                                                    _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: IHS(rate) treatment}}\\"  _n
file write `fh' "Post $\times$ IHS(rate)&`fb_i_full_1940'\sym{`s_i_full_1940'}&`fb_i_nm_1940'\sym{`s_i_nm_1940'}&`fb_i_full_1946'\sym{`s_i_full_1946'}&`fb_i_nm_1946'\sym{`s_i_nm_1946'}\\" _n
file write `fh' "            &( `fse_i_full_1940')&( `fse_i_nm_1940')&( `fse_i_full_1946')&( `fse_i_nm_1946')\\[0.5em]" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
file write `fh' "Post $\times$ High count&`fb_d_full_1940'\sym{`s_d_full_1940'}&`fb_d_nm_1940'\sym{`s_d_nm_1940'}&`fb_d_full_1946'\sym{`s_d_full_1946'}&`fb_d_nm_1946'\sym{`s_d_nm_1946'}\\" _n
file write `fh' "            &( `fse_d_full_1940')&( `fse_d_nm_1940')&( `fse_d_full_1946')&( `fse_d_nm_1946')\\" _n
file write `fh' "\midrule"                                                    _n
file write `fh' "County FE&\multicolumn{4}{c}{Yes}\\"                          _n
file write `fh' "Cohort FE&\multicolumn{4}{c}{Yes}\\"                          _n
file write `fh' "Wave FE&\multicolumn{4}{c}{Yes}\\"                            _n
file write `fh' "Cells&`fn_full_1940'&`fn_nm_1940'&`fn_full_1946'&`fn_nm_1946'\\" _n
file write `fh' "\bottomrule"                                                 _n
file write `fh' "\end{tabular*}"                                              _n
file write `fh' "}"                                                           _n
file close `fh'

di as text "Written: $outdir/nonmigrant_robust_pooled_v1.tex"

exit, clear
