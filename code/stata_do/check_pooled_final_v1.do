/*  ================================================================
    Final pooled regressions - focused specs with table output
    Birth cohort: 1920-1956, pooled 1982+1990+2000
    Cutoffs: 1940, 1946
    eduy: 1% winsorised
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")
global outdir "${proj}/paper/assets/tables"

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
keep old6 county_curr6 route_final
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'
global cw1982_tmp "`cw1982'"

*--------------------------------------------------------------
* resolve program
*--------------------------------------------------------------
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

*--------------------------------------------------------------
* treatment
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw pop_1953

gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)

/* IHS */
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

/* dummy: above median */
summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
summ martyr_per100k_1953, detail
gen d_rate_high = (martyr_per100k_1953 > r(p50)) if !missing(martyr_per100k_1953)

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
use county age_c age educ using "$c1990", clear
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

use uid birthyr eduyr using "$c2000", clear
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
*  Load each wave: 1920-1956
*==============================================================
* ---- 1982 ----
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
di "1982 N = " _N

* ---- 1990 ----
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
di "1990 N = " _N

* ---- 2000 ----
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
di "2000 N = " _N

*==============================================================
*  Pool & winsorize
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'
egen county_num = group(countyid_curr6)

/* 1% winsorize eduy */
summ eduy, detail
scalar eduy_p1  = r(p1)
scalar eduy_p99 = r(p99)
replace eduy = eduy_p1  if eduy < eduy_p1
replace eduy = eduy_p99 if eduy > eduy_p99 & !missing(eduy)

/* county×cohort×wave cell size */
bysort countyid_curr6 birth_i wave: gen cohort_n = _N
gen ln_cohort_n = ln(cohort_n)

di "=== Pooled N = " _N
tab wave

*==============================================================
*  _stars helper
*==============================================================
capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01 {
        return local star "\sym{***}"
    }
    else if `pval' < 0.05 {
        return local star "\sym{**}"
    }
    else if `pval' < 0.10 {
        return local star "\sym{*}"
    }
    else {
        return local star ""
    }
end

*==============================================================
*  Regressions: 6 columns
*  (1) Dummy count, cutoff 1940
*  (2) Dummy count + cohort ctrl, cutoff 1940
*  (3) Dummy rate, cutoff 1940
*  (4) Dummy count, cutoff 1946
*  (5) Dummy count + cohort ctrl, cutoff 1946
*  (6) Dummy rate, cutoff 1946
*==============================================================

foreach cutoff in 1940 1946 {
    local dropyr = `cutoff' - 1
    capture drop post drop_yr
    gen post = (birth_i >= `cutoff')
    gen byte drop_yr = (birth_i == `dropyr')

    /* (a) Dummy count */
    di "=== Cutoff `cutoff': Dummy count ==="
    reghdfejl eduy i.d_count_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_dc_`cutoff'  = _b[1.d_count_high#1.post]
    local se_dc_`cutoff' = _se[1.d_count_high#1.post]
    local p_dc_`cutoff'  = 2*ttail(e(df_r), abs(`b_dc_`cutoff''/`se_dc_`cutoff''))
    local n_dc_`cutoff'  = e(N)
    local nc_dc_`cutoff' = e(N_clust)

    /* (b) Dummy count + cohort ctrl */
    di "=== Cutoff `cutoff': Dummy count + cohort ==="
    reghdfejl eduy i.d_count_high##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_dcc_`cutoff'  = _b[1.d_count_high#1.post]
    local se_dcc_`cutoff' = _se[1.d_count_high#1.post]
    local p_dcc_`cutoff'  = 2*ttail(e(df_r), abs(`b_dcc_`cutoff''/`se_dcc_`cutoff''))
    local n_dcc_`cutoff'  = e(N)

    /* (c) Dummy rate */
    di "=== Cutoff `cutoff': Dummy rate ==="
    reghdfejl eduy i.d_rate_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_dr_`cutoff'  = _b[1.d_rate_high#1.post]
    local se_dr_`cutoff' = _se[1.d_rate_high#1.post]
    local p_dr_`cutoff'  = 2*ttail(e(df_r), abs(`b_dr_`cutoff''/`se_dr_`cutoff''))
    local n_dr_`cutoff'  = e(N)

    /* (d) IHS count */
    di "=== Cutoff `cutoff': IHS count ==="
    reghdfejl eduy c.ihs_count##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_ic_`cutoff'  = _b[1.post#c.ihs_count]
    local se_ic_`cutoff' = _se[1.post#c.ihs_count]
    local p_ic_`cutoff'  = 2*ttail(e(df_r), abs(`b_ic_`cutoff''/`se_ic_`cutoff''))
    local n_ic_`cutoff'  = e(N)

    /* (e) IHS count + cohort ctrl */
    di "=== Cutoff `cutoff': IHS count + cohort ==="
    reghdfejl eduy c.ihs_count##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_icc_`cutoff'  = _b[1.post#c.ihs_count]
    local se_icc_`cutoff' = _se[1.post#c.ihs_count]
    local p_icc_`cutoff'  = 2*ttail(e(df_r), abs(`b_icc_`cutoff''/`se_icc_`cutoff''))
    local n_icc_`cutoff'  = e(N)

    /* (f) IHS rate */
    di "=== Cutoff `cutoff': IHS rate ==="
    reghdfejl eduy c.ihs_rate##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_ir_`cutoff'  = _b[1.post#c.ihs_rate]
    local se_ir_`cutoff' = _se[1.post#c.ihs_rate]
    local p_ir_`cutoff'  = 2*ttail(e(df_r), abs(`b_ir_`cutoff''/`se_ir_`cutoff''))
    local n_ir_`cutoff'  = e(N)

    /* (g) ln per100k reference */
    di "=== Cutoff `cutoff': ln per100k ref ==="
    reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_ln_`cutoff'  = _b[1.post#c.ln_martyr_per100k_1953]
    local se_ln_`cutoff' = _se[1.post#c.ln_martyr_per100k_1953]
    local p_ln_`cutoff'  = 2*ttail(e(df_r), abs(`b_ln_`cutoff''/`se_ln_`cutoff''))
    local n_ln_`cutoff'  = e(N)

    drop post drop_yr
}

*==============================================================
*  Output: three-line table (.tex)
*  7 columns: (1-3) cutoff 1940, (4-6) cutoff 1946, + ref ln
*==============================================================

/* Stars */
foreach cutoff in 1940 1946 {
    foreach spec in dc dcc dr ic icc ir ln {
        _stars `p_`spec'_`cutoff''
        local s_`spec'_`cutoff' "`r(star)'"
    }
}

tempname fh
file open `fh' using "${outdir}/pooled_treatment_exploration_v1.tex", write replace

file write `fh' "\begin{table}[H]" _n
file write `fh' "\centering" _n
file write `fh' "\caption{Alternative Treatment Measures: Pooled Census (1982+1990+2000)}" _n
file write `fh' "\label{tab:treatment_exploration}" _n
file write `fh' "\small" _n
file write `fh' "\begin{tabular}{l*{7}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' " & \multicolumn{3}{c}{Cutoff: 1940} & & \multicolumn{3}{c}{Cutoff: 1946} \\" _n
file write `fh' "\cmidrule(lr){2-4} \cmidrule(lr){6-8}" _n
file write `fh' " & (1) & (2) & (3) & & (4) & (5) & (6) \\" _n
file write `fh' "\midrule" _n

/* Panel A: Dummy */
file write `fh' "\multicolumn{8}{l}{\textit{Panel A: Dummy (above median)}} \\" _n
file write `fh' "[0.3em]" _n

/* Row: 1{Post × High count} */
file write `fh' "Post $\times$ High count"
file write `fh' " & " %7.3f (`b_dc_1940') "`s_dc_1940'"
file write `fh' " & " %7.3f (`b_dcc_1940') "`s_dcc_1940'"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & " %7.3f (`b_dc_1946') "`s_dc_1946'"
file write `fh' " & " %7.3f (`b_dcc_1946') "`s_dcc_1946'"
file write `fh' " & "
file write `fh' " \\" _n

/* SE */
file write `fh' " & (" %7.3f (`se_dc_1940') ")"
file write `fh' " & (" %7.3f (`se_dcc_1940') ")"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & (" %7.3f (`se_dc_1946') ")"
file write `fh' " & (" %7.3f (`se_dcc_1946') ")"
file write `fh' " & "
file write `fh' " \\" _n

/* Row: Post × High rate */
file write `fh' "Post $\times$ High rate"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & " %7.3f (`b_dr_1940') "`s_dr_1940'"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & "
file write `fh' " & " %7.3f (`b_dr_1946') "`s_dr_1946'"
file write `fh' " \\" _n

file write `fh' " & "
file write `fh' " & "
file write `fh' " & (" %7.3f (`se_dr_1940') ")"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & "
file write `fh' " & (" %7.3f (`se_dr_1946') ")"
file write `fh' " \\" _n

file write `fh' "[0.5em]" _n

/* Panel B: IHS */
file write `fh' "\multicolumn{8}{l}{\textit{Panel B: Inverse Hyperbolic Sine}} \\" _n
file write `fh' "[0.3em]" _n

file write `fh' "Post $\times$ IHS(count)"
file write `fh' " & " %7.3f (`b_ic_1940') "`s_ic_1940'"
file write `fh' " & " %7.3f (`b_icc_1940') "`s_icc_1940'"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & " %7.3f (`b_ic_1946') "`s_ic_1946'"
file write `fh' " & " %7.3f (`b_icc_1946') "`s_icc_1946'"
file write `fh' " & "
file write `fh' " \\" _n

file write `fh' " & (" %7.3f (`se_ic_1940') ")"
file write `fh' " & (" %7.3f (`se_icc_1940') ")"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & (" %7.3f (`se_ic_1946') ")"
file write `fh' " & (" %7.3f (`se_icc_1946') ")"
file write `fh' " & "
file write `fh' " \\" _n

file write `fh' "Post $\times$ IHS(rate)"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & " %7.3f (`b_ir_1940') "`s_ir_1940'"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & "
file write `fh' " & " %7.3f (`b_ir_1946') "`s_ir_1946'"
file write `fh' " \\" _n

file write `fh' " & "
file write `fh' " & "
file write `fh' " & (" %7.3f (`se_ir_1940') ")"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & "
file write `fh' " & (" %7.3f (`se_ir_1946') ")"
file write `fh' " \\" _n

file write `fh' "[0.5em]" _n

/* Panel C: ln reference */
file write `fh' "\multicolumn{8}{l}{\textit{Panel C: Log (reference)}} \\" _n
file write `fh' "[0.3em]" _n

file write `fh' "Post $\times$ ln(per 100k)"
file write `fh' " & " %7.3f (`b_ln_1940') "`s_ln_1940'"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & "
file write `fh' " & " %7.3f (`b_ln_1946') "`s_ln_1946'"
file write `fh' " & "
file write `fh' " & "
file write `fh' " \\" _n

file write `fh' " & (" %7.3f (`se_ln_1940') ")"
file write `fh' " & "
file write `fh' " & "
file write `fh' " & "
file write `fh' " & (" %7.3f (`se_ln_1946') ")"
file write `fh' " & "
file write `fh' " & "
file write `fh' " \\" _n

file write `fh' "\midrule" _n
file write `fh' "Cohort size control & & \checkmark & & & & \checkmark & \\" _n
file write `fh' "Minority control & \checkmark & \checkmark & \checkmark & & \checkmark & \checkmark & \checkmark \\" _n
file write `fh' "County FE & \checkmark & \checkmark & \checkmark & & \checkmark & \checkmark & \checkmark \\" _n
file write `fh' "Birth cohort FE & \checkmark & \checkmark & \checkmark & & \checkmark & \checkmark & \checkmark \\" _n
file write `fh' "Wave FE & \checkmark & \checkmark & \checkmark & & \checkmark & \checkmark & \checkmark \\" _n

/* Observations row */
file write `fh' "Observations"
file write `fh' " & " %12.0fc (`n_dc_1940')
file write `fh' " & " %12.0fc (`n_dcc_1940')
file write `fh' " & " %12.0fc (`n_dr_1940')
file write `fh' " & "
file write `fh' " & " %12.0fc (`n_dc_1946')
file write `fh' " & " %12.0fc (`n_dcc_1946')
file write `fh' " & " %12.0fc (`n_dr_1946')
file write `fh' " \\" _n

file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular}" _n
file write `fh' "\end{table}" _n

file close `fh'

*==============================================================
*  Summary
*==============================================================
di ""
di "========================================="
di "  RESULTS SUMMARY"
di "========================================="
di ""
di "CUTOFF 1940:"
di "  Dummy count:           b = " %7.4f `b_dc_1940'  "  se = " %7.4f `se_dc_1940'  "  p = " %6.4f `p_dc_1940'
di "  Dummy count + cohort:  b = " %7.4f `b_dcc_1940' "  se = " %7.4f `se_dcc_1940' "  p = " %6.4f `p_dcc_1940'
di "  Dummy rate:            b = " %7.4f `b_dr_1940'  "  se = " %7.4f `se_dr_1940'  "  p = " %6.4f `p_dr_1940'
di "  IHS count:             b = " %7.4f `b_ic_1940'  "  se = " %7.4f `se_ic_1940'  "  p = " %6.4f `p_ic_1940'
di "  IHS count + cohort:    b = " %7.4f `b_icc_1940' "  se = " %7.4f `se_icc_1940' "  p = " %6.4f `p_icc_1940'
di "  IHS rate:              b = " %7.4f `b_ir_1940'  "  se = " %7.4f `se_ir_1940'  "  p = " %6.4f `p_ir_1940'
di "  ln per100k (ref):      b = " %7.4f `b_ln_1940'  "  se = " %7.4f `se_ln_1940'  "  p = " %6.4f `p_ln_1940'
di ""
di "CUTOFF 1946:"
di "  Dummy count:           b = " %7.4f `b_dc_1946'  "  se = " %7.4f `se_dc_1946'  "  p = " %6.4f `p_dc_1946'
di "  Dummy count + cohort:  b = " %7.4f `b_dcc_1946' "  se = " %7.4f `se_dcc_1946' "  p = " %6.4f `p_dcc_1946'
di "  Dummy rate:            b = " %7.4f `b_dr_1946'  "  se = " %7.4f `se_dr_1946'  "  p = " %6.4f `p_dr_1946'
di "  IHS count:             b = " %7.4f `b_ic_1946'  "  se = " %7.4f `se_ic_1946'  "  p = " %6.4f `p_ic_1946'
di "  IHS count + cohort:    b = " %7.4f `b_icc_1946' "  se = " %7.4f `se_icc_1946' "  p = " %6.4f `p_icc_1946'
di "  IHS rate:              b = " %7.4f `b_ir_1946'  "  se = " %7.4f `se_ir_1946'  "  p = " %6.4f `p_ir_1946'
di "  ln per100k (ref):      b = " %7.4f `b_ln_1946'  "  se = " %7.4f `se_ln_1946'  "  p = " %6.4f `p_ln_1946'

di ""
di "Birth cohort: 1920-1956"
di "Pooled: 1982 + 1990 + 2000"
di "eduy: 1% winsorised"

exit, clear
