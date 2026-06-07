*******************************************************
* SCHOOLING-MARGIN ROBUSTNESS AND HETEROGENEITY
* Outcomes: enroll_pri, enroll_mid (Primary, Middle).
* (College and Senior High dropped per the schooling
*  catch-up channel that targets basic literacy.)
*
* Specifications:
*   E3  Heterogeneity by gender
*   E4  Robustness with historical county controls
*       (one-by-one and all together)
*
* Cell construction follows check_enrollment_pooled_v2.do
* but adds a sex split.
*******************************************************

clear all
set more off
set maxvar 10000

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global proj "`proj_cloud'"

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
use countyid birthyr educcn ethniccn sex using "$census1982", clear
drop if missing(countyid) | missing(birthyr) | missing(educcn)
decode educcn, gen(edu_str)
gen byte enroll_pri = .
gen byte enroll_mid = .
replace enroll_pri = 0 if strpos(edu_str,"illiterate") | strpos(edu_str,"less than primary") | strpos(edu_str,"none")
replace enroll_pri = 1 if strpos(edu_str,"primary") | strpos(edu_str,"junior") | strpos(edu_str,"secondary") | strpos(edu_str,"college") | strpos(edu_str,"graduated")
replace enroll_mid = 0 if !missing(enroll_pri) & enroll_pri==0
replace enroll_mid = 0 if strpos(edu_str,"primary") & !strpos(edu_str,"junior")
replace enroll_mid = 1 if strpos(edu_str,"junior") | strpos(edu_str,"secondary") | strpos(edu_str,"college") | strpos(edu_str,"graduated")
drop if missing(enroll_pri)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birth_i = floor(birthyr)
gen minority = (ethniccn != 1) if !missing(ethniccn)
gen byte male = (sex==1) if !missing(sex)
keep if inrange(birth_i, 1920, 1956)
gen wave = 1
keep countyid_curr6 birth_i enroll_pri enroll_mid minority male wave
tempfile w1982
save `w1982'

*=== Wave 1990 ======================================================
use county age_c age educ race sex using "$census1990", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birthyr = 1000 + age_c*100 + age
gen birth_i = floor(birthyr)
gen minority = (race != 1) if !missing(race)
gen byte male = (sex==1) if !missing(sex)
drop if educ==0
gen byte enroll_pri = (educ >= 2)
gen byte enroll_mid = (educ >= 3)
keep if inrange(birth_i, 1920, 1956)
gen wave = 2
keep countyid_curr6 birth_i enroll_pri enroll_mid minority male wave
tempfile w1990
save `w1990'

*=== Wave 2000 ======================================================
use uid birthyr educ race sex using "$census2000", clear
drop if missing(uid) | missing(birthyr) | missing(educ)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birth_i = floor(birthyr)
gen minority = (race != 1) if !missing(race)
gen byte male = (sex==1) if !missing(sex)
gen byte enroll_pri = (educ >= 3)
gen byte enroll_mid = (educ >= 4)
keep if inrange(birth_i, 1920, 1956)
gen wave = 3
keep countyid_curr6 birth_i enroll_pri enroll_mid minority male wave
tempfile w2000
save `w2000'

*=== Pool, collapse to county-cohort-wave-sex ========================
use `w1982', clear
append using `w1990'
append using `w2000'

merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen

* Save micro-level for re-use
tempfile micro
save `micro'

* Cell with sex split
use `micro', clear
drop if missing(male)
gen cell_n = 1
collapse (mean) enroll_pri enroll_mid minority_share=minority ///
         (sum) cell_n, by(countyid_curr6 birth_i wave male ihs_rate d_count_high)
encode countyid_curr6, gen(county_num)
tempfile cells_sex
save `cells_sex'

* Pooled cell (no sex split, for robustness historical-controls regressions)
use `micro', clear
gen cell_n = 1
collapse (mean) enroll_pri enroll_mid minority_share=minority ///
         (sum) cell_n, by(countyid_curr6 birth_i wave ihs_rate d_count_high)
encode countyid_curr6, gen(county_num)
tempfile cells_full
save `cells_full'

di "=== Cell counts ==="
di "  cells_sex: " _N " (after sex collapse)"

*=== Heterogeneity by gender (Table E3) ============================
use `cells_sex', clear
gen post = (birth_i >= 1940)
gen treat_ihs_post = ihs_rate * post
gen treat_d_post   = d_count_high * post

local outcomes "enroll_pri enroll_mid"
foreach y of local outcomes {
    foreach v in i d {
        local treatvar = cond("`v'"=="i", "treat_ihs_post", "treat_d_post")
        local controlvar = cond("`v'"=="i", "ihs_rate", "d_count_high")
        foreach g in 0 1 {
            quietly reghdfejl `y' `treatvar' `controlvar' post minority_share i.wave [aw=cell_n] if birth_i != 1939 & male==`g', absorb(county_num birth_i) vce(cluster county_num)
            local b_`y'_`v'_`g' = _b[`treatvar']
            local se_`y'_`v'_`g' = _se[`treatvar']
            local p_`y'_`v'_`g' = 2*ttail(e(df_r), abs(`b_`y'_`v'_`g''/`se_`y'_`v'_`g''))
            local n_`y'_`v'_`g' = e(N)
        }
    }
}

* Output Table E3
foreach y of local outcomes {
    foreach v in i d {
        foreach g in 0 1 {
            _stars `p_`y'_`v'_`g''
            local s_`y'_`v'_`g' "`r(star)'"
            local fb_`y'_`v'_`g' : di %9.4f `b_`y'_`v'_`g''
            local fse_`y'_`v'_`g' : di %7.4f `se_`y'_`v'_`g''
        }
    }
}

tempname fh
file open `fh' using "$outdir/enrollment_het_gender_v1.tex", write replace
file write `fh' "{"                                                           _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}"              _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule"                                                    _n
file write `fh' "&\multicolumn{2}{c}{Primary}&\multicolumn{2}{c}{Middle}\\" _n
file write `fh' "\cmidrule(lr){2-3}\cmidrule(lr){4-5}"                        _n
file write `fh' "&Female&Male&Female&Male\\"                                  _n
file write `fh' "\midrule"                                                    _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
file write `fh' "Post $\times$ IHS(rate)&`fb_enroll_pri_i_0'\sym{`s_enroll_pri_i_0'}&`fb_enroll_pri_i_1'\sym{`s_enroll_pri_i_1'}&`fb_enroll_mid_i_0'\sym{`s_enroll_mid_i_0'}&`fb_enroll_mid_i_1'\sym{`s_enroll_mid_i_1'}\\" _n
file write `fh' "&( `fse_enroll_pri_i_0')&( `fse_enroll_pri_i_1')&( `fse_enroll_mid_i_0')&( `fse_enroll_mid_i_1')\\[0.5em]" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
file write `fh' "Post $\times$ High count&`fb_enroll_pri_d_0'\sym{`s_enroll_pri_d_0'}&`fb_enroll_pri_d_1'\sym{`s_enroll_pri_d_1'}&`fb_enroll_mid_d_0'\sym{`s_enroll_mid_d_0'}&`fb_enroll_mid_d_1'\sym{`s_enroll_mid_d_1'}\\" _n
file write `fh' "&( `fse_enroll_pri_d_0')&( `fse_enroll_pri_d_1')&( `fse_enroll_mid_d_0')&( `fse_enroll_mid_d_1')\\" _n
file write `fh' "\midrule"                                                    _n
file write `fh' "County FE&Yes&Yes&Yes&Yes\\"                                 _n
file write `fh' "Cohort FE&Yes&Yes&Yes&Yes\\"                                 _n
file write `fh' "Wave FE&Yes&Yes&Yes&Yes\\"                                   _n
file write `fh' "\bottomrule"                                                 _n
file write `fh' "\end{tabular*}"                                              _n
file write `fh' "}"                                                           _n
file close `fh'
di as text "Written: $outdir/enrollment_het_gender_v1.tex"

*=== Robustness with historical controls (Table E4) ================
* Try to merge in historical controls from existing temp files.
use `cells_full', clear
gen post = (birth_i >= 1940)
gen treat_ihs_post = ihs_rate * post
gen treat_d_post   = d_count_high * post

* Merge historical controls used in main paper (Chen-Yang style)
capture confirm file "${proj}/data/temp/county_controls_full_v1.dta"
if _rc == 0 {
    merge m:1 countyid_curr6 using "${proj}/data/temp/county_controls_full_v1.dta", keep(master match) nogen keepusing(sdy_density victims_cr grain_output urbanratio64 ins_famine)
}
local hctrls = ""
foreach c in sdy_density victims_cr grain_output urbanratio64 ins_famine {
    capture confirm variable `c'
    if !_rc local hctrls "`hctrls' `c'"
}
di "historical controls available: `hctrls'"

local outcomes "enroll_pri enroll_mid"
foreach y of local outcomes {
    quietly reghdfejl `y' treat_ihs_post ihs_rate post minority_share i.wave [aw=cell_n] if birth_i != 1939, absorb(county_num birth_i) vce(cluster county_num)
    local b_`y'_base = _b[treat_ihs_post]
    local se_`y'_base = _se[treat_ihs_post]
    local p_`y'_base = 2*ttail(e(df_r), abs(`b_`y'_base'/`se_`y'_base'))
    local n_`y'_base = e(N)

    if "`hctrls'" != "" {
        local hctrls_post ""
        foreach c of local hctrls {
            gen hp_`c' = `c' * post
            local hctrls_post "`hctrls_post' hp_`c'"
        }
        quietly reghdfejl `y' treat_ihs_post ihs_rate post minority_share `hctrls_post' i.wave [aw=cell_n] if birth_i != 1939, absorb(county_num birth_i) vce(cluster county_num)
        local b_`y'_full = _b[treat_ihs_post]
        local se_`y'_full = _se[treat_ihs_post]
        local p_`y'_full = 2*ttail(e(df_r), abs(`b_`y'_full'/`se_`y'_full'))
        local n_`y'_full = e(N)
        foreach c of local hctrls {
            drop hp_`c'
        }
    }
    else {
        local b_`y'_full = .
        local se_`y'_full = .
        local p_`y'_full = .
        local n_`y'_full = 0
    }
}

foreach y of local outcomes {
    foreach m in base full {
        if !missing(`b_`y'_`m'') {
            _stars `p_`y'_`m''
            local s_`y'_`m' "`r(star)'"
            local fb_`y'_`m' : di %9.4f `b_`y'_`m''
            local fse_`y'_`m' : di %7.4f `se_`y'_`m''
        }
        else {
            local s_`y'_`m' ""
            local fb_`y'_`m' "--"
            local fse_`y'_`m' "--"
        }
    }
}

file open `fh' using "$outdir/enrollment_robust_histcontrols_v1.tex", write replace
file write `fh' "{"                                                           _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}"              _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule"                                                    _n
file write `fh' "&\multicolumn{2}{c}{Primary}&\multicolumn{2}{c}{Middle}\\" _n
file write `fh' "\cmidrule(lr){2-3}\cmidrule(lr){4-5}"                        _n
file write `fh' "&Baseline&With controls&Baseline&With controls\\"                                  _n
file write `fh' "\midrule"                                                    _n
file write `fh' "Post $\times$ IHS(rate)&`fb_enroll_pri_base'\sym{`s_enroll_pri_base'}&`fb_enroll_pri_full'\sym{`s_enroll_pri_full'}&`fb_enroll_mid_base'\sym{`s_enroll_mid_base'}&`fb_enroll_mid_full'\sym{`s_enroll_mid_full'}\\" _n
file write `fh' "&( `fse_enroll_pri_base')&( `fse_enroll_pri_full')&( `fse_enroll_mid_base')&( `fse_enroll_mid_full')\\" _n
file write `fh' "\midrule"                                                    _n
file write `fh' "Hist. controls $\times$ Post&No&Yes&No&Yes\\"                _n
file write `fh' "County FE&Yes&Yes&Yes&Yes\\"                                 _n
file write `fh' "Cohort FE&Yes&Yes&Yes&Yes\\"                                 _n
file write `fh' "Wave FE&Yes&Yes&Yes&Yes\\"                                   _n
file write `fh' "\bottomrule"                                                 _n
file write `fh' "\end{tabular*}"                                              _n
file write `fh' "}"                                                           _n
file close `fh'
di as text "Written: $outdir/enrollment_robust_histcontrols_v1.tex"

exit, clear
