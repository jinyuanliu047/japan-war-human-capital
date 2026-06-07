/* ================================================================
   1946 CUTOFF — Lite version
   Reuses pooling from main do file, just changes post to 1946
   Only runs key regressions (baseline, hist controls, LM/Korea)
   ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 "${proj}/data/raw/census/census1990.dta"
global c2000 "${proj}/data/raw/census/census2000.dta"
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

*--------------------------------------------------------------
* county dictionary + crosswalk (same as main do)
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
* treatment + controls
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
merge 1:1 countyid_curr6 using "${proj}/data/temp/county_controls_full_v1.dta", keep(master match) nogen keepusing(sdy_density ins_famine victims_cr grain_output urbanratio64)
merge 1:1 countyid_curr6 using "${proj}/data/temp/revolutionary_proxy_controls_v1.dta", keep(master match) nogen

capture gen ihs_longmarch = ln(longmarch_martyr_per100k + sqrt(longmarch_martyr_per100k^2 + 1)) if !missing(longmarch_martyr_per100k)
capture gen ihs_korea = ln(korea_war_martyr_per100k + sqrt(korea_war_martyr_per100k^2 + 1)) if !missing(korea_war_martyr_per100k)

gen ln_victims_cr = ln(1 + victims_cr) if !missing(victims_cr)
gen ln_grain_output = ln(1 + grain_output) if !missing(grain_output)
foreach v in sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 {
    capture replace `v' = 0 if missing(`v')
}
capture replace ihs_longmarch = 0 if missing(ihs_longmarch)
capture replace ihs_korea = 0 if missing(ihs_korea)

tempfile treat
save `treat'
global treat_tmp "`treat'"

*--------------------------------------------------------------
* mapping for 1990 + 2000
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
*  Load and pool — minimal variables
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
keep countyid_curr6 eduy birth_i wave minority ihs_rate d_count_high ///
    sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64
capture keep countyid_curr6 eduy birth_i wave minority ihs_rate d_count_high ///
    sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 ///
    ihs_longmarch ihs_korea
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
replace eduy = 0 if educ==1
replace eduy = 6 if educ==2
replace eduy = 9 if educ==3
replace eduy = 12 if inlist(educ,4,5)
replace eduy = 15 if educ==6
replace eduy = 16 if educ==7
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 2
keep countyid_curr6 eduy birth_i wave minority ihs_rate d_count_high ///
    sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64
capture keep countyid_curr6 eduy birth_i wave minority ihs_rate d_count_high ///
    sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 ///
    ihs_longmarch ihs_korea
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
keep countyid_curr6 eduy birth_i wave minority ihs_rate d_count_high ///
    sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64
capture keep countyid_curr6 eduy birth_i wave minority ihs_rate d_count_high ///
    sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 ///
    ihs_longmarch ihs_korea
tempfile w2000
save `w2000'

*==============================================================
*  Pool & setup
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'

summ eduy, detail
scalar p1 = r(p1)
scalar p99 = r(p99)
replace eduy = p1 if eduy < p1
replace eduy = p99 if eduy > p99 & !missing(eduy)

encode countyid_curr6, gen(county_num)
bysort county_num birth_i wave: gen cohort_n = _N
gen ln_cohort_n = ln(cohort_n)

gen post1946 = (birth_i >= 1946)

di "=== POOLED N = " _N " ==="

*##############################################################
*  REGRESSIONS WITH 1946 CUTOFF
*##############################################################

* ---- Baseline ----
di "=== Baseline IHS, 1946 ==="
reghdfejl eduy c.ihs_rate##ib0.post1946 minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_base_ihs = _b[1.post1946#c.ihs_rate]
local se_base_ihs = _se[1.post1946#c.ihs_rate]
local p_base_ihs = 2*ttail(e(df_r), abs(`b_base_ihs'/`se_base_ihs'))
local n_base = e(N)

di "=== Baseline Dummy, 1946 ==="
reghdfejl eduy i.d_count_high##ib0.post1946 ln_cohort_n minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_base_dum = _b[1.d_count_high#1.post1946]
local se_base_dum = _se[1.d_count_high#1.post1946]
local p_base_dum = 2*ttail(e(df_r), abs(`b_base_dum'/`se_base_dum'))

* ---- Historical controls ----
local controls "sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64"
local col = 0
foreach ctrl of local controls {
    local col = `col' + 1
    di "=== IHS + `ctrl', 1946 ==="
    reghdfejl eduy c.ihs_rate##ib0.post1946 c.`ctrl'##ib0.post1946 minority i.wave, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_hist_ihs_`col' = _b[1.post1946#c.ihs_rate]
    local se_hist_ihs_`col' = _se[1.post1946#c.ihs_rate]
    local p_hist_ihs_`col' = 2*ttail(e(df_r), abs(`b_hist_ihs_`col''/`se_hist_ihs_`col''))
    local n_hist_`col' = e(N)

    di "=== Dummy + `ctrl', 1946 ==="
    reghdfejl eduy i.d_count_high##ib0.post1946 c.`ctrl'##ib0.post1946 ln_cohort_n minority i.wave, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_hist_dum_`col' = _b[1.d_count_high#1.post1946]
    local se_hist_dum_`col' = _se[1.d_count_high#1.post1946]
    local p_hist_dum_`col' = 2*ttail(e(df_r), abs(`b_hist_dum_`col''/`se_hist_dum_`col''))
}

* All controls
di "=== IHS + all controls, 1946 ==="
reghdfejl eduy c.ihs_rate##ib0.post1946 ///
    c.sdy_density##ib0.post1946 c.ins_famine##ib0.post1946 ///
    c.ln_victims_cr##ib0.post1946 c.ln_grain_output##ib0.post1946 ///
    c.urbanratio64##ib0.post1946 minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_hist_ihs_all = _b[1.post1946#c.ihs_rate]
local se_hist_ihs_all = _se[1.post1946#c.ihs_rate]
local p_hist_ihs_all = 2*ttail(e(df_r), abs(`b_hist_ihs_all'/`se_hist_ihs_all'))
local n_hist_all = e(N)

di "=== Dummy + all controls, 1946 ==="
reghdfejl eduy i.d_count_high##ib0.post1946 ///
    c.sdy_density##ib0.post1946 c.ins_famine##ib0.post1946 ///
    c.ln_victims_cr##ib0.post1946 c.ln_grain_output##ib0.post1946 ///
    c.urbanratio64##ib0.post1946 ln_cohort_n minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_hist_dum_all = _b[1.d_count_high#1.post1946]
local se_hist_dum_all = _se[1.d_count_high#1.post1946]
local p_hist_dum_all = 2*ttail(e(df_r), abs(`b_hist_dum_all'/`se_hist_dum_all'))

* ---- LM/Korea ----
capture {
    di "=== IHS + LM, 1946 ==="
    reghdfejl eduy c.ihs_rate##ib0.post1946 c.ihs_longmarch##ib0.post1946 minority i.wave, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_lm_ihs = _b[1.post1946#c.ihs_rate]
    local se_lm_ihs = _se[1.post1946#c.ihs_rate]
    local p_lm_ihs = 2*ttail(e(df_r), abs(`b_lm_ihs'/`se_lm_ihs'))

    di "=== IHS + Korea, 1946 ==="
    reghdfejl eduy c.ihs_rate##ib0.post1946 c.ihs_korea##ib0.post1946 minority i.wave, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_kr_ihs = _b[1.post1946#c.ihs_rate]
    local se_kr_ihs = _se[1.post1946#c.ihs_rate]
    local p_kr_ihs = 2*ttail(e(df_r), abs(`b_kr_ihs'/`se_kr_ihs'))

    di "=== IHS + LM + Korea, 1946 ==="
    reghdfejl eduy c.ihs_rate##ib0.post1946 c.ihs_longmarch##ib0.post1946 ///
        c.ihs_korea##ib0.post1946 minority i.wave, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_both_ihs = _b[1.post1946#c.ihs_rate]
    local se_both_ihs = _se[1.post1946#c.ihs_rate]
    local p_both_ihs = 2*ttail(e(df_r), abs(`b_both_ihs'/`se_both_ihs'))
}

*##############################################################
* OUTPUT: Historical controls table (1946)
*##############################################################
tempname fh
file open `fh' using "${outdir}/pooled_historical_controls_1946_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{7}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}\\" _n
file write `fh' "            &Baseline&+SDY&+Famine&+CR victims&+Grain&+Urban&All controls\\" _n
file write `fh' "\midrule" _n

* Panel A: IHS
file write `fh' "\multicolumn{8}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
_stars `p_base_ihs'
file write `fh' "Post(1946) $\times$ IHS(rate)&" %9.4f (`b_base_ihs') "\sym{`r(star)'}"
forvalues j = 1/5 {
    _stars `p_hist_ihs_`j''
    file write `fh' "&" %9.4f (`b_hist_ihs_`j'') "\sym{`r(star)'}"
}
_stars `p_hist_ihs_all'
file write `fh' "&" %9.4f (`b_hist_ihs_all') "\sym{`r(star)'}\\" _n
file write `fh' "            &(" %7.4f (`se_base_ihs') ")"
forvalues j = 1/5 {
    file write `fh' "&(" %7.4f (`se_hist_ihs_`j'') ")"
}
file write `fh' "&(" %7.4f (`se_hist_ihs_all') ")\\[0.5em]" _n

* Panel B: Dummy
file write `fh' "\multicolumn{8}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
_stars `p_base_dum'
file write `fh' "Post(1946) $\times$ High count&" %9.4f (`b_base_dum') "\sym{`r(star)'}"
forvalues j = 1/5 {
    _stars `p_hist_dum_`j''
    file write `fh' "&" %9.4f (`b_hist_dum_`j'') "\sym{`r(star)'}"
}
_stars `p_hist_dum_all'
file write `fh' "&" %9.4f (`b_hist_dum_all') "\sym{`r(star)'}\\" _n
file write `fh' "            &(" %7.4f (`se_base_dum') ")"
forvalues j = 1/5 {
    file write `fh' "&(" %7.4f (`se_hist_dum_`j'') ")"
}
file write `fh' "&(" %7.4f (`se_hist_dum_all') ")\\" _n

file write `fh' "\midrule" _n
file write `fh' "Minority control&\multicolumn{7}{c}{Yes}\\" _n
file write `fh' "County FE&\multicolumn{7}{c}{Yes}\\" _n
file write `fh' "Cohort FE&\multicolumn{7}{c}{Yes}\\" _n
file write `fh' "Wave FE&\multicolumn{7}{c}{Yes}\\" _n
file write `fh' "Treatment start&\multicolumn{7}{c}{1946}\\" _n
file write `fh' "Observations&" %12.0fc (`n_base')
forvalues j = 1/5 {
    file write `fh' "&" %12.0fc (`n_hist_`j'')
}
file write `fh' "&" %12.0fc (`n_hist_all') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Historical controls (1946) table saved ==="

*##############################################################
* Heterogeneity: Gender (1946)
*##############################################################
di ""
di "=== Gender heterogeneity (1946) ==="

* Need sex variable — check if available
capture confirm variable female
if _rc != 0 {
    di "female variable not available — skipping gender heterogeneity"
}
else {
    foreach g in 0 1 {
        if `g' == 0 local glabel "Male"
        if `g' == 1 local glabel "Female"

        di "=== `glabel', IHS, 1946 ==="
        reghdfejl eduy c.ihs_rate##ib0.post1946 minority i.wave if female == `g', ///
            absorb(county_num birth_i) vce(cluster county_num)
        local b_g`g'_ihs = _b[1.post1946#c.ihs_rate]
        local se_g`g'_ihs = _se[1.post1946#c.ihs_rate]
        local p_g`g'_ihs = 2*ttail(e(df_r), abs(`b_g`g'_ihs'/`se_g`g'_ihs'))
        local n_g`g' = e(N)

        di "=== `glabel', Dummy, 1946 ==="
        reghdfejl eduy i.d_count_high##ib0.post1946 ln_cohort_n minority i.wave if female == `g', ///
            absorb(county_num birth_i) vce(cluster county_num)
        local b_g`g'_dum = _b[1.d_count_high#1.post1946]
        local se_g`g'_dum = _se[1.d_count_high#1.post1946]
        local p_g`g'_dum = 2*ttail(e(df_r), abs(`b_g`g'_dum'/`se_g`g'_dum'))
    }
}

di ""
di "========================================="
di "  1946 CUTOFF REGRESSIONS COMPLETE"
di "========================================="
di ""
di "=== KEY RESULTS SUMMARY ==="
di "Baseline IHS (1946): b = " %7.4f (`b_base_ihs') " se = " %7.4f (`se_base_ihs')
di "Baseline Dummy (1946): b = " %7.4f (`b_base_dum') " se = " %7.4f (`se_base_dum')
di "All controls IHS (1946): b = " %7.4f (`b_hist_ihs_all') " se = " %7.4f (`se_hist_ihs_all')
di "All controls Dummy (1946): b = " %7.4f (`b_hist_dum_all') " se = " %7.4f (`se_hist_dum_all')

exit, clear
