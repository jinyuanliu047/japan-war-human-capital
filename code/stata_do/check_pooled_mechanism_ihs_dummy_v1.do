/*  ================================================================
    Mechanism regressions with IHS + Dummy treatment
    Panel A: IHS(rate) treatment
    Panel B: Binary (above median) treatment

    1. CGSS 2008 attitudes (7 outcomes)
    2. CHIP 1995 education investment (3 outcomes)
    3. Census 1990 career choice (3 outcomes)
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global outdir "${proj}/paper/assets/tables"

capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*##############################################################
*  PART 1: CGSS 2008 ATTITUDES
*##############################################################
di ""
di "========================================"
di "  PART 1: CGSS 2008 Attitudes (IHS + Dummy)"
di "========================================"

use serial countyid a1 a2 a6 a14a a14d e3a e3b e3c e3d e3e e3f using "${proj}/data/raw/cgss2008_14.dta", clear
merge 1:1 serial using "${proj}/data/raw/cgss2008b_14.dta", keep(match) nogen

gen str6 countyid_curr6 = string(countyid, "%06.0f")

/* merge treatment and build IHS + dummy */
merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", ///
    keep(match) nogen keepusing(ln_martyr_per100k_1953 martyr_per100k_1953 ln_martyr_raw)

gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)

gen birth_i = floor(a2)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940

gen female = (a1 == 2) if inlist(a1, 1, 2)
gen minority = (a6 != 1) if inrange(a6, 1, 56)
gen urban_hukou = inlist(a14a, 1, 2, 3, 4, 5) if inrange(a14a, 1, 6)
gen local_hukou = inlist(a14d, 1, 2) if inrange(a14d, 1, 4)

egen county_num = group(countyid_curr6)

gen hometown_affect = 5 - ge1a if inrange(ge1a, 1, 4)
gen parent_edu_importance = 6 - f1b if inrange(f1b, 1, 5)
gen ambition_importance = 6 - f1d if inrange(f1d, 1, 5)
gen hardwork_importance = 6 - f1e if inrange(f1e, 1, 5)
gen connections_importance = 6 - f1f if inrange(f1f, 1, 5)
gen religion_importance = 6 - f1j if inrange(f1j, 1, 5)
gen college_only_for_rich = 6 - f2c if inrange(f2c, 1, 5)

local cgss_outcomes "ambition_importance parent_edu_importance college_only_for_rich hardwork_importance hometown_affect connections_importance religion_importance"
local cgss_titles `" "Ambition" "Parents' edu" "Rich only" "Hard work" "Hometown" "Connections" "Religion" "'
local cgss_ncols = 7

local m = 0
foreach yvar of local cgss_outcomes {
    local m = `m' + 1

    /* Panel A: IHS */
    di "=== CGSS IHS: `yvar' ==="
    reghdfejl `yvar' c.ihs_rate##ib0.post female minority urban_hukou local_hukou, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_ihs_`m' = _b[1.post#c.ihs_rate]
    local se_ihs_`m' = _se[1.post#c.ihs_rate]
    local p_ihs_`m' = 2*ttail(e(df_r), abs(`b_ihs_`m''/`se_ihs_`m''))
    local n_ihs_`m' = e(N)

    /* Panel B: Dummy */
    di "=== CGSS Dummy: `yvar' ==="
    reghdfejl `yvar' i.d_count_high##ib0.post female minority urban_hukou local_hukou, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_dum_`m' = _b[1.d_count_high#1.post]
    local se_dum_`m' = _se[1.d_count_high#1.post]
    local p_dum_`m' = 2*ttail(e(df_r), abs(`b_dum_`m''/`se_dum_`m''))
    local n_dum_`m' = e(N)
}

/* Output CGSS table */
tempname fh
file open `fh' using "${outdir}/mechanism_cgss_attitudes_ihs_dummy_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{7}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}\\" _n
file write `fh' "            &Ambition&Parents' edu&Rich only&Hard work&Hometown&Connections&Religion\\" _n
file write `fh' "\midrule" _n

/* Panel A: IHS */
file write `fh' "\multicolumn{8}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
_stars `p_ihs_1'
file write `fh' "Post $\times$ IHS(rate)&" %9.4f (`b_ihs_1') "\sym{`r(star)'}"
forvalues j = 2/7 {
    _stars `p_ihs_`j''
    file write `fh' "&" %9.4f (`b_ihs_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_ihs_1') ")"
forvalues j = 2/7 {
    file write `fh' "&(" %7.4f (`se_ihs_`j'') ")"
}
file write `fh' "\\[0.5em]" _n

/* Panel B: Dummy */
file write `fh' "\multicolumn{8}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
_stars `p_dum_1'
file write `fh' "Post $\times$ High count&" %9.4f (`b_dum_1') "\sym{`r(star)'}"
forvalues j = 2/7 {
    _stars `p_dum_`j''
    file write `fh' "&" %9.4f (`b_dum_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_dum_1') ")"
forvalues j = 2/7 {
    file write `fh' "&(" %7.4f (`se_dum_`j'') ")"
}
file write `fh' "\\" _n

file write `fh' "\midrule" _n
file write `fh' "Individual controls&     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "County FE&     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Cohort FE&     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_ihs_1')
forvalues j = 2/7 {
    file write `fh' "&" %12.0fc (`n_ihs_`j'')
}
file write `fh' "\\" _n
file write `fh' "Obs (Dummy)&" %12.0fc (`n_dum_1')
forvalues j = 2/7 {
    file write `fh' "&" %12.0fc (`n_dum_`j'')
}
file write `fh' "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== CGSS attitudes IHS+Dummy table saved ==="

*##############################################################
*  PART 2: CHIP 1995 EDUCATION INVESTMENT
*##############################################################
di ""
di "========================================"
di "  PART 2: CHIP 1995 Education (IHS + Dummy)"
di "========================================"

use "${proj}/data/temp/chip1995_edu_pooled_pref_micro_v1.dta", clear
egen pref_num = group(pref4_curr)

/* build IHS + dummy treatment */
* reconstruct martyr_per100k_1953 from ln(x+1)
gen martyr_per100k_1953 = exp(ln_martyr_per100k_1953) - 1 if !missing(ln_martyr_per100k_1953)
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

/* dummy: median split on rate */
summ martyr_per100k_1953, detail
gen d_count_high = (martyr_per100k_1953 > r(p50)) if !missing(martyr_per100k_1953)

gen ln1p_edu_total = ln(edu_total + 1) if !missing(edu_total)
gen ln1p_schooling_fee = ln(schooling_fee + 1) if !missing(schooling_fee)
gen ln1p_training_cost = ln(training_cost + 1) if !missing(training_cost)

global control "NHH head_female head_working head_eduy sample_rural"

local chip_outcomes "ln1p_edu_total ln1p_schooling_fee ln1p_training_cost"
local chip_titles `" "ln(1+Edu total)" "ln(1+School fee)" "ln(1+Training)" "'

local m = 0
foreach yvar of local chip_outcomes {
    local m = `m' + 1

    /* Panel A: IHS */
    di "=== CHIP IHS: `yvar' ==="
    reghdfejl `yvar' c.ihs_rate##ib0.post $control, ///
        absorb(pref_num birth_i) vce(cluster pref_num)
    local b_ihs_`m' = _b[1.post#c.ihs_rate]
    local se_ihs_`m' = _se[1.post#c.ihs_rate]
    local p_ihs_`m' = 2*ttail(e(df_r), abs(`b_ihs_`m''/`se_ihs_`m''))
    local n_ihs_`m' = e(N)

    /* Panel B: Dummy */
    di "=== CHIP Dummy: `yvar' ==="
    reghdfejl `yvar' i.d_count_high##ib0.post $control, ///
        absorb(pref_num birth_i) vce(cluster pref_num)
    local b_dum_`m' = _b[1.d_count_high#1.post]
    local se_dum_`m' = _se[1.d_count_high#1.post]
    local p_dum_`m' = 2*ttail(e(df_r), abs(`b_dum_`m''/`se_dum_`m''))
    local n_dum_`m' = e(N)
}

/* Output CHIP table */
tempname fh
file open `fh' using "${outdir}/mechanism_chip1995_ihs_dummy_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{3}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}\\" _n
file write `fh' "            &ln(1+Edu total)&ln(1+School fee)&ln(1+Training)\\" _n
file write `fh' "\midrule" _n

/* Panel A: IHS */
file write `fh' "\multicolumn{4}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
_stars `p_ihs_1'
file write `fh' "Post $\times$ IHS(rate)&" %9.4f (`b_ihs_1') "\sym{`r(star)'}"
forvalues j = 2/3 {
    _stars `p_ihs_`j''
    file write `fh' "&" %9.4f (`b_ihs_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_ihs_1') ")"
forvalues j = 2/3 {
    file write `fh' "&(" %7.4f (`se_ihs_`j'') ")"
}
file write `fh' "\\[0.5em]" _n

/* Panel B: Dummy */
file write `fh' "\multicolumn{4}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
_stars `p_dum_1'
file write `fh' "Post $\times$ High count&" %9.4f (`b_dum_1') "\sym{`r(star)'}"
forvalues j = 2/3 {
    _stars `p_dum_`j''
    file write `fh' "&" %9.4f (`b_dum_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_dum_1') ")"
forvalues j = 2/3 {
    file write `fh' "&(" %7.4f (`se_dum_`j'') ")"
}
file write `fh' "\\" _n

file write `fh' "\midrule" _n
file write `fh' "Household controls&     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Prefecture FE&     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Cohort FE&     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_ihs_1') "&" %12.0fc (`n_ihs_2') "&" %12.0fc (`n_ihs_3') "\\" _n
file write `fh' "Obs (Dummy)&" %12.0fc (`n_dum_1') "&" %12.0fc (`n_dum_2') "&" %12.0fc (`n_dum_3') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== CHIP 1995 IHS+Dummy table saved ==="

*##############################################################
*  PART 3: CENSUS 1990 CAREER CHOICE
*##############################################################
di ""
di "========================================"
di "  PART 3: Census 1990 Career (IHS + Dummy)"
di "========================================"

/* crosswalk setup */
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
keep old6 county_curr6 route_final
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
    replace route = "manual_successor" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace route = "manual_successor" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace route = "manual_successor" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"
    replace route = "manual_successor" if old6=="110010"
    tempfile left
    save `left'
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6 route_final)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    replace route = "crosswalk_1982" if county_curr6!="" & route=="unmatched"
    drop county_curr6 route_final
    rename curr_res county_curr6
    save `left', replace
    use `left', clear
    rename county_curr6 curr_res
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace curr_res = curr_dict if curr_res=="" & curr_dict!=""
    replace route = "exact_code" if curr_dict!="" & route=="unmatched"
    drop curr_dict
    rename curr_res county_curr6
    gen str6 muni6 = substr(old6,1,2) + "01" + substr(old6,5,2) ///
        if inlist(substr(old6,1,2),"11","12","31") & substr(old6,3,2)=="00" & county_curr6==""
    tempfile muni_exact
    tempfile muni_cw
    preserve
        keep old6
        keep if 0
        gen str6 curr_from_muni_exact = ""
        save `muni_exact', replace
    restore
    preserve
        keep old6
        keep if 0
        gen str6 curr_from_muni_cw = ""
        save `muni_cw', replace
    restore
    preserve
        keep if muni6!="" & county_curr6==""
        count
        if r(N)>0 {
            keep old6 muni6
            rename muni6 old6_muni
            rename old6 old6_orig
            rename old6_muni old6
            merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
            keep if curr_dict!=""
            drop old6
            rename old6_orig old6
            rename curr_dict curr_from_muni_exact
            keep old6 curr_from_muni_exact
            save `muni_exact', replace
        }
    restore
    merge 1:1 old6 using `muni_exact', keep(master match) nogen
    replace county_curr6 = curr_from_muni_exact if county_curr6=="" & curr_from_muni_exact!=""
    replace route = "municipality_geo3_recode" if county_curr6==curr_from_muni_exact & curr_from_muni_exact!=""
    drop curr_from_muni_exact
    preserve
        keep if muni6!="" & county_curr6==""
        count
        if r(N)>0 {
            keep old6 muni6
            rename muni6 old6_muni
            rename old6 old6_orig
            rename old6_muni old6
            merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
            keep if county_curr6!=""
            drop old6
            rename old6_orig old6
            rename county_curr6 curr_from_muni_cw
            keep old6 curr_from_muni_cw
            save `muni_cw', replace
        }
    restore
    merge 1:1 old6 using `muni_cw', keep(master match) nogen
    replace county_curr6 = curr_from_muni_cw if county_curr6=="" & curr_from_muni_cw!=""
    replace route = "municipality_then_crosswalk_1982" if county_curr6==curr_from_muni_cw & curr_from_muni_cw!=""
    drop curr_from_muni_cw muni6
end

/* treatment with IHS + dummy */
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953 martyr_per100k_1953 ln_martyr_raw
gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
rename countyid_curr6 county_curr6
duplicates drop county_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

/* mapping */
global raw1990 "${proj}/data/raw/census/census1990.dta"
use county using "$raw1990", clear
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

/* load 1990 census data */
use county age_c age sex race regstatu occu using "$raw1990", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(occu)

gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using "$map1990_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""

gen birth_i = 1000 + age_c*100 + age
keep if inrange(birth_i, 1920, 1968)
drop if birth_i == 1939

merge m:1 county_curr6 using "$treat_tmp", keep(master match) nogen
rename county_curr6 countyid_curr6

gen post = birth_i >= 1940
gen male = (sex == 1) if inlist(sex, 1, 2)
gen minority = (race != 1) if !missing(race)
gen rural = (regstatu == 1) if inrange(regstatu, 1, 5)

gen employed = (occu > 0) if !missing(occu)
keep if employed == 1

gen white_collar = inrange(occu, 11, 399) if employed == 1
gen agri_job = inrange(occu, 401, 599) if employed == 1
gen manual = inrange(occu, 601, 999) if employed == 1

egen county_num = group(countyid_curr6)

global control "male minority rural"

local occ_outcomes "white_collar agri_job manual"
local occ_titles `" "White-collar" "Agricultural" "Manual" "'

local m = 0
foreach yvar of local occ_outcomes {
    local m = `m' + 1

    /* Panel A: IHS */
    di "=== Career IHS: `yvar' ==="
    reghdfejl `yvar' c.ihs_rate##ib0.post $control, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_ihs_`m' = _b[1.post#c.ihs_rate]
    local se_ihs_`m' = _se[1.post#c.ihs_rate]
    local p_ihs_`m' = 2*ttail(e(df_r), abs(`b_ihs_`m''/`se_ihs_`m''))
    local n_ihs_`m' = e(N)

    /* Panel B: Dummy */
    di "=== Career Dummy: `yvar' ==="
    reghdfejl `yvar' i.d_count_high##ib0.post $control, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_dum_`m' = _b[1.d_count_high#1.post]
    local se_dum_`m' = _se[1.d_count_high#1.post]
    local p_dum_`m' = 2*ttail(e(df_r), abs(`b_dum_`m''/`se_dum_`m''))
    local n_dum_`m' = e(N)
}

/* Output career table */
tempname fh
file open `fh' using "${outdir}/mechanism_career_ihs_dummy_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{3}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}\\" _n
file write `fh' "            &White-collar&Agricultural&Manual\\" _n
file write `fh' "\midrule" _n

/* Panel A: IHS */
file write `fh' "\multicolumn{4}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
_stars `p_ihs_1'
file write `fh' "Post $\times$ IHS(rate)&" %9.4f (`b_ihs_1') "\sym{`r(star)'}"
forvalues j = 2/3 {
    _stars `p_ihs_`j''
    file write `fh' "&" %9.4f (`b_ihs_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_ihs_1') ")"
forvalues j = 2/3 {
    file write `fh' "&(" %7.4f (`se_ihs_`j'') ")"
}
file write `fh' "\\[0.5em]" _n

/* Panel B: Dummy */
file write `fh' "\multicolumn{4}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
_stars `p_dum_1'
file write `fh' "Post $\times$ High count&" %9.4f (`b_dum_1') "\sym{`r(star)'}"
forvalues j = 2/3 {
    _stars `p_dum_`j''
    file write `fh' "&" %9.4f (`b_dum_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_dum_1') ")"
forvalues j = 2/3 {
    file write `fh' "&(" %7.4f (`se_dum_`j'') ")"
}
file write `fh' "\\" _n

file write `fh' "\midrule" _n
file write `fh' "Individual controls&     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "County FE&     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Cohort FE&     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_ihs_1') "&" %12.0fc (`n_ihs_2') "&" %12.0fc (`n_ihs_3') "\\" _n
file write `fh' "Obs (Dummy)&" %12.0fc (`n_dum_1') "&" %12.0fc (`n_dum_2') "&" %12.0fc (`n_dum_3') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Career choice IHS+Dummy table saved ==="

di ""
di "========================================="
di "  ALL MECHANISM IHS+DUMMY REGRESSIONS COMPLETE"
di "========================================="

exit, clear
