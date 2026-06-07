/*  ================================================================
    ULTRA-FAST REGRESSIONS USING PRE-POOLED DATA
    ================================================================ */
clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global master_data "${proj}/data/temp/master_pooled_ppml_v1.dta"
global outdir "${proj}/paper/assets/tables"
set maxvar 10000

use "$master_data", clear
gen birth_i = floor(birthyr)

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*--------------------------------------------------------------
* 1. BASELINE COMPARISON (Table 1/A1 style)
*--------------------------------------------------------------
foreach cutoff in 1940 1946 {
    local dropyr = `cutoff' - 1
    gen post = (birth_i >= `cutoff')
    gen drop_yr = (birth_i == `dropyr')
    
    * IHS Rate
    ppmlhdfe eduy c.ihs_rate##ib0.post minority i.wave if !drop_yr, absorb(county_num birth_i) vce(cluster county_num)
    local b_ihs_`cutoff' = _b[1.post#c.ihs_rate]
    local se_ihs_`cutoff' = _se[1.post#c.ihs_rate]
    local p_ihs_`cutoff' = 2*ttail(e(df_r), abs(`b_ihs_`cutoff''/`se_ihs_`cutoff''))
    local n_ihs_`cutoff' = e(N)

    * Binary
    ppmlhdfe eduy i.d_count_high##ib0.post ln_cohort_n minority i.wave if !drop_yr, absorb(county_num birth_i) vce(cluster county_num)
    local b_dum_`cutoff' = _b[1.d_count_high#1.post]
    local se_dum_`cutoff' = _se[1.d_count_high#1.post]
    local p_dum_`cutoff' = 2*ttail(e(df_r), abs(`b_dum_`cutoff''/`se_dum_`cutoff''))
    local n_dum_`cutoff' = e(N)

    drop post drop_yr
}

* [Tex generation omitted for speed, will be in the script I run]
* ... (I'll add the tex output code in the next file write)
di "ALL REGRESSIONS COMPLETED."
exit, clear
