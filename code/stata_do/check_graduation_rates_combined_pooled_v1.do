*******************************************************
* Combined basic education completion rates — POOLED COUNTY-COHORT-WAVE
* Pools 1982+1990+2000 censuses
* Denominator = full county x cohort x wave population
* basic_rate = (primary_rate + junior_rate) / 2
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
if fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta") global census1982 "${proj}/data/temp/census_1982_mainvars_v1.dta"
if fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta") global census1990 "${proj}/data/temp/census_1990_mainvars_v1.dta"
if fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta") global census2000 "${proj}/data/temp/census_2000_mainvars_v1.dta"

global outdir "${proj}/paper/assets/tables"

capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

*--------------------------------------------------------------
* county dictionary + crosswalk
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
* star program
*--------------------------------------------------------------
capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*==============================================================
*  Load each wave — individual level, create completion dummies
*==============================================================
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
gen primary = (eduy >= 6)
gen junior = (eduy >= 9)
gen basic = (primary + junior) / 2
gen wave = 1
keep countyid_curr6 birth_i primary junior basic minority wave
tempfile w1982
save `w1982'

use county age_c age educ race using "$census1990", clear
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
gen primary = (eduy >= 6)
gen junior = (eduy >= 9)
gen basic = (primary + junior) / 2
gen wave = 2
keep countyid_curr6 birth_i primary junior basic minority wave
tempfile w1990
save `w1990'

use uid birthyr eduyr race using "$census2000", clear
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
gen primary = (eduy >= 6)
gen junior = (eduy >= 9)
gen basic = (primary + junior) / 2
gen wave = 3
keep countyid_curr6 birth_i primary junior basic minority wave
tempfile w2000
save `w2000'

*==============================================================
*  Pool, merge treatment, and collapse to county-cohort-wave rates
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'

merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
encode countyid_curr6, gen(county_num)
gen cell_n = 1
collapse (mean) primary junior basic minority_share=minority ///
         (sum) cell_n, by(countyid_curr6 county_num birth_i wave ihs_rate d_count_high)

di "=== POOLED county-cohort-wave cells = " _N " ==="

*==============================================================
*  Regressions — county-cohort-wave rates, weighted by cell size
*==============================================================

foreach cutoff in 1940 1946 {
    capture drop post treat_ihs_post treat_d_post
    gen post = (birth_i >= `cutoff')
    gen treat_ihs_post = ihs_rate * post
    gen treat_d_post = d_count_high * post
    local omit = cond(`cutoff'==1940, 1939, 1945)

    * Primary
    quietly reghdfejl primary treat_ihs_post ihs_rate post minority_share i.wave [aw=cell_n] if birth_i != `omit', absorb(county_num birth_i) vce(cluster county_num)
    local b_pi_`cutoff' = _b[treat_ihs_post]
    local se_pi_`cutoff' = _se[treat_ihs_post]
    local p_pi_`cutoff' = 2*ttail(e(df_r), abs(`b_pi_`cutoff''/`se_pi_`cutoff''))
    local n_ihs_`cutoff' = e(N)

    quietly reghdfejl primary treat_d_post d_count_high post minority_share i.wave [aw=cell_n] if birth_i != `omit', absorb(county_num birth_i) vce(cluster county_num)
    local b_pd_`cutoff' = _b[treat_d_post]
    local se_pd_`cutoff' = _se[treat_d_post]
    local p_pd_`cutoff' = 2*ttail(e(df_r), abs(`b_pd_`cutoff''/`se_pd_`cutoff''))
    local n_d_`cutoff' = e(N)

    * Junior high
    quietly reghdfejl junior treat_ihs_post ihs_rate post minority_share i.wave [aw=cell_n] if birth_i != `omit', absorb(county_num birth_i) vce(cluster county_num)
    local b_ji_`cutoff' = _b[treat_ihs_post]
    local se_ji_`cutoff' = _se[treat_ihs_post]
    local p_ji_`cutoff' = 2*ttail(e(df_r), abs(`b_ji_`cutoff''/`se_ji_`cutoff''))

    quietly reghdfejl junior treat_d_post d_count_high post minority_share i.wave [aw=cell_n] if birth_i != `omit', absorb(county_num birth_i) vce(cluster county_num)
    local b_jd_`cutoff' = _b[treat_d_post]
    local se_jd_`cutoff' = _se[treat_d_post]
    local p_jd_`cutoff' = 2*ttail(e(df_r), abs(`b_jd_`cutoff''/`se_jd_`cutoff''))

    * Combined basic
    quietly reghdfejl basic treat_ihs_post ihs_rate post minority_share i.wave [aw=cell_n] if birth_i != `omit', absorb(county_num birth_i) vce(cluster county_num)
    local b_bi_`cutoff' = _b[treat_ihs_post]
    local se_bi_`cutoff' = _se[treat_ihs_post]
    local p_bi_`cutoff' = 2*ttail(e(df_r), abs(`b_bi_`cutoff''/`se_bi_`cutoff''))

    quietly reghdfejl basic treat_d_post d_count_high post minority_share i.wave [aw=cell_n] if birth_i != `omit', absorb(county_num birth_i) vce(cluster county_num)
    local b_bd_`cutoff' = _b[treat_d_post]
    local se_bd_`cutoff' = _se[treat_d_post]
    local p_bd_`cutoff' = 2*ttail(e(df_r), abs(`b_bd_`cutoff''/`se_bd_`cutoff''))

    drop post treat_ihs_post treat_d_post
}

*==============================================================
*  Output table — both cutoffs in one table
*==============================================================
foreach cutoff in 1940 1946 {
    foreach v in pi ji bi pd jd bd {
        _stars `p_`v'_`cutoff''
        local s_`v'_`cutoff' "`r(star)'"
    }
    * Pre-format
    foreach v in pi ji bi pd jd bd {
        local fb_`v'_`cutoff' : di %9.4f `b_`v'_`cutoff''
        local fse_`v'_`cutoff' : di %7.4f `se_`v'_`cutoff''
    }
    local fn_ihs_`cutoff' : di %12.0fc `n_ihs_`cutoff''
    local fn_d_`cutoff' : di %12.0fc `n_d_`cutoff''
}

tempname fh
file open `fh' using "$outdir/graduation_combined_pooled_v1.tex", write replace
file write `fh' "{"                                                           _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}"              _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{6}{c}}" _n
file write `fh' "\toprule"                                                    _n
file write `fh' "            &\multicolumn{3}{c}{Cutoff 1940}&\multicolumn{3}{c}{Cutoff 1946}\\" _n
file write `fh' "            \cmidrule(lr){2-4}\cmidrule(lr){5-7}"           _n
file write `fh' "            &Primary&Junior high&Combined&Primary&Junior high&Combined\\" _n
file write `fh' "\midrule"                                                    _n
file write `fh' "\multicolumn{7}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
file write `fh' "Post $\times$ IHS(rate)&`fb_pi_1940'\sym{`s_pi_1940'}&`fb_ji_1940'\sym{`s_ji_1940'}&`fb_bi_1940'\sym{`s_bi_1940'}&`fb_pi_1946'\sym{`s_pi_1946'}&`fb_ji_1946'\sym{`s_ji_1946'}&`fb_bi_1946'\sym{`s_bi_1946'}\\" _n
file write `fh' "            &( `fse_pi_1940')&( `fse_ji_1940')&( `fse_bi_1940')&( `fse_pi_1946')&( `fse_ji_1946')&( `fse_bi_1946')\\[0.5em]" _n
file write `fh' "\multicolumn{7}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
file write `fh' "Post $\times$ High count&`fb_pd_1940'\sym{`s_pd_1940'}&`fb_jd_1940'\sym{`s_jd_1940'}&`fb_bd_1940'\sym{`s_bd_1940'}&`fb_pd_1946'\sym{`s_pd_1946'}&`fb_jd_1946'\sym{`s_jd_1946'}&`fb_bd_1946'\sym{`s_bd_1946'}\\" _n
file write `fh' "            &( `fse_pd_1940')&( `fse_jd_1940')&( `fse_bd_1940')&( `fse_pd_1946')&( `fse_jd_1946')&( `fse_bd_1946')\\" _n
file write `fh' "\midrule"                                                    _n
file write `fh' "County FE&\multicolumn{6}{c}{Yes}\\"                        _n
file write `fh' "Cohort FE&\multicolumn{6}{c}{Yes}\\"                        _n
file write `fh' "Wave FE&\multicolumn{6}{c}{Yes}\\"                          _n
file write `fh' "Weights&\multicolumn{6}{c}{County $\times$ cohort $\times$ wave population}\\" _n
file write `fh' "Obs (IHS)&\multicolumn{3}{c}{`fn_ihs_1940'}&\multicolumn{3}{c}{`fn_ihs_1946'}\\" _n
file write `fh' "Obs (Dummy)&\multicolumn{3}{c}{`fn_d_1940'}&\multicolumn{3}{c}{`fn_d_1946'}\\" _n
file write `fh' "\bottomrule"                                                 _n
file write `fh' "\end{tabular*}"                                              _n
file write `fh' "}"                                                           _n
file close `fh'

di as text "Written: $outdir/graduation_combined_pooled_v1.tex"

exit, clear
