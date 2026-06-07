/*  ================================================================
    Sacrifice-place robustness (pooled 1982+1990+2000)
    Treatment: martyrs COUNTED BY PLACE OF DEATH (not native place).
    Base data: data/temp/master_pooled_ppml_v1.dta  (pre-pooled)
               data/scrape/chinamartyrs_outputs/
                 chinamartyrs_1931_1945_sacrifice_place_counts_merge_ready.csv

    Output (AER style .tex, 7 columns):
        paper/assets/tables/pooled_baseline_sacrifice_main_v1.tex      (cutoff 1940)
        paper/assets/tables/pooled_baseline_sacrifice_robust1946_v1.tex (cutoff 1946)
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj   "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global master "${proj}/data/temp/master_pooled_ppml_v1.dta"
global sac_csv "${proj}/data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_sacrifice_place_counts_merge_ready.csv"
global pop1953 "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta"
global outdir "${proj}/paper/assets/tables"

*==============================================================
* 1. Build sacrifice-place treatment at the 6-digit county level
*==============================================================

import delimited "${sac_csv}", clear varnames(1) stringcols(1 2 3)

* merge_place_id is a 12-digit county-code string (first 6 = county)
gen str6 countyid_curr6 = substr(merge_place_id, 1, 6)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"

destring martyr_count, replace force
replace martyr_count = 0 if missing(martyr_count)

collapse (sum) martyr_sac_count = martyr_count, by(countyid_curr6)
tempfile sac_county
save `sac_county'

*--------------------------------------------------------------
* Pull 1953 population denominator from the native-place
* treatment file so the rate uses the SAME denominator.
*--------------------------------------------------------------
use "${pop1953}", clear
keep countyid_curr6 pop_1953
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop countyid_curr6, force
tempfile pop53
save `pop53'

use `sac_county', clear
merge 1:1 countyid_curr6 using `pop53', keep(master match) nogen
replace pop_1953 = . if pop_1953 <= 0

gen martyr_sac_per100k_1953 = 100000 * martyr_sac_count / pop_1953
gen ln_martyr_sac_per100k_1953 = ln(martyr_sac_per100k_1953) if martyr_sac_per100k_1953 > 0 & !missing(martyr_sac_per100k_1953)
gen ihs_sac_count = ln(martyr_sac_count + sqrt(martyr_sac_count^2 + 1))
gen ihs_sac_rate  = ln(martyr_sac_per100k_1953 + sqrt(martyr_sac_per100k_1953^2 + 1)) if !missing(martyr_sac_per100k_1953)

summ martyr_sac_count, detail
gen d_sac_count_high = (martyr_sac_count > r(p50)) if !missing(martyr_sac_count)
summ martyr_sac_per100k_1953, detail
gen d_sac_rate_high  = (martyr_sac_per100k_1953 > r(p50)) if !missing(martyr_sac_per100k_1953)

keep countyid_curr6 martyr_sac_count martyr_sac_per100k_1953 ///
     ihs_sac_count ihs_sac_rate d_sac_count_high d_sac_rate_high ln_martyr_sac_per100k_1953
tempfile treat_sac
save `treat_sac'

*==============================================================
* 2. Load pre-pooled master data and merge sacrifice treatment
*==============================================================
use "${master}", clear

* master has countyid_curr6 already; enforce 6-char string format
tostring countyid_curr6, replace force
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)

merge m:1 countyid_curr6 using `treat_sac', keep(master match) nogen

di "=== POOLED SAC N = " _N " ==="

*==============================================================
* 3. Helper: stars
*==============================================================
capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01        return local star "***"
    else if `pval' < 0.05   return local star "**"
    else if `pval' < 0.10   return local star "*"
    else                    return local star ""
end

*==============================================================
* 4. Regressions: cutoffs 1940 and 1946
*    Columns:
*      (1) Dummy sacrifice count
*      (2) Dummy count + cohort ctrl
*      (3) Dummy sacrifice rate
*      (4) IHS(sacrifice count)
*      (5) IHS(count) + cohort ctrl
*      (6) IHS(sacrifice rate)
*      (7) ln(sac per 100k) reference
*==============================================================

foreach cutoff in 1940 1946 {
    local dropyr = `cutoff' - 1
    capture drop post drop_yr
    gen post = (birth_i >= `cutoff')
    gen byte drop_yr = (birth_i == `dropyr')

    /* (1) Dummy count */
    di "=== Sac cutoff `cutoff': (1) Dummy count ==="
    reghdfejl eduy i.d_sac_count_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_1_`cutoff'  = _b[1.d_sac_count_high#1.post]
    local se_1_`cutoff' = _se[1.d_sac_count_high#1.post]
    local p_1_`cutoff'  = 2*ttail(e(df_r), abs(`b_1_`cutoff''/`se_1_`cutoff''))
    local n_1_`cutoff'  = e(N)
    local r2_1_`cutoff' = e(r2)
    local nc_1_`cutoff' = e(N_clust)

    /* (2) Dummy count + cohort ctrl */
    di "=== Sac cutoff `cutoff': (2) Dummy count + cohort ==="
    reghdfejl eduy i.d_sac_count_high##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_2_`cutoff'  = _b[1.d_sac_count_high#1.post]
    local se_2_`cutoff' = _se[1.d_sac_count_high#1.post]
    local p_2_`cutoff'  = 2*ttail(e(df_r), abs(`b_2_`cutoff''/`se_2_`cutoff''))
    local n_2_`cutoff'  = e(N)
    local r2_2_`cutoff' = e(r2)

    /* (3) Dummy rate */
    di "=== Sac cutoff `cutoff': (3) Dummy rate ==="
    reghdfejl eduy i.d_sac_rate_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_3_`cutoff'  = _b[1.d_sac_rate_high#1.post]
    local se_3_`cutoff' = _se[1.d_sac_rate_high#1.post]
    local p_3_`cutoff'  = 2*ttail(e(df_r), abs(`b_3_`cutoff''/`se_3_`cutoff''))
    local n_3_`cutoff'  = e(N)
    local r2_3_`cutoff' = e(r2)

    /* (4) IHS count */
    di "=== Sac cutoff `cutoff': (4) IHS count ==="
    reghdfejl eduy c.ihs_sac_count##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_4_`cutoff'  = _b[1.post#c.ihs_sac_count]
    local se_4_`cutoff' = _se[1.post#c.ihs_sac_count]
    local p_4_`cutoff'  = 2*ttail(e(df_r), abs(`b_4_`cutoff''/`se_4_`cutoff''))
    local n_4_`cutoff'  = e(N)
    local r2_4_`cutoff' = e(r2)

    /* (5) IHS count + cohort ctrl */
    di "=== Sac cutoff `cutoff': (5) IHS count + cohort ==="
    reghdfejl eduy c.ihs_sac_count##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_5_`cutoff'  = _b[1.post#c.ihs_sac_count]
    local se_5_`cutoff' = _se[1.post#c.ihs_sac_count]
    local p_5_`cutoff'  = 2*ttail(e(df_r), abs(`b_5_`cutoff''/`se_5_`cutoff''))
    local n_5_`cutoff'  = e(N)
    local r2_5_`cutoff' = e(r2)

    /* (6) IHS rate */
    di "=== Sac cutoff `cutoff': (6) IHS rate ==="
    reghdfejl eduy c.ihs_sac_rate##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_6_`cutoff'  = _b[1.post#c.ihs_sac_rate]
    local se_6_`cutoff' = _se[1.post#c.ihs_sac_rate]
    local p_6_`cutoff'  = 2*ttail(e(df_r), abs(`b_6_`cutoff''/`se_6_`cutoff''))
    local n_6_`cutoff'  = e(N)
    local r2_6_`cutoff' = e(r2)

    /* (7) ln reference */
    di "=== Sac cutoff `cutoff': (7) ln per100k ref ==="
    reghdfejl eduy c.ln_martyr_sac_per100k_1953##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_7_`cutoff'  = _b[1.post#c.ln_martyr_sac_per100k_1953]
    local se_7_`cutoff' = _se[1.post#c.ln_martyr_sac_per100k_1953]
    local p_7_`cutoff'  = 2*ttail(e(df_r), abs(`b_7_`cutoff''/`se_7_`cutoff''))
    local n_7_`cutoff'  = e(N)
    local r2_7_`cutoff' = e(r2)

    drop post drop_yr
}

*==============================================================
* 5. Write .tex tables (mirror pooled_baseline layout)
*==============================================================

foreach cutoff in 1940 1946 {

    forvalues c = 1/7 {
        _stars `p_`c'_`cutoff''
        local s_`c'_`cutoff' "`r(star)'"
    }

    local suffix = cond(`cutoff'==1940, "main", "robust1946")

    tempname fh
    file open `fh' using "${outdir}/pooled_baseline_sacrifice_`suffix'_v1.tex", write replace

    file write `fh' "{" _n
    file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
    file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{7}{c}}" _n
    file write `fh' "\toprule" _n
    file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}\\" _n
    file write `fh' "            &\multicolumn{3}{c}{Binary (above median)}&\multicolumn{3}{c}{Inverse hyperbolic sine}&\multicolumn{1}{c}{Log}\\" _n
    file write `fh' "            \cmidrule(lr){2-4}\cmidrule(lr){5-7}\cmidrule(lr){8-8}" _n

    /* Row: Dummy sac count */
    file write `fh' "Post $\times$ High sacrifice count&" ///
        %12.4f (`b_1_`cutoff'') "\sym{`s_1_`cutoff''}&" ///
        %12.4f (`b_2_`cutoff'') "\sym{`s_2_`cutoff''}&" ///
        "            &            &            &            &            \\" _n
    file write `fh' "            &" ///
        "(" %7.4f (`se_1_`cutoff'') ")&" ///
        "(" %7.4f (`se_2_`cutoff'') ")&" ///
        "            &            &            &            &            \\" _n

    /* Row: Dummy sac rate */
    file write `fh' "Post $\times$ High sacrifice rate&" ///
        "            &            &" ///
        %12.4f (`b_3_`cutoff'') "\sym{`s_3_`cutoff''}&" ///
        "            &            &            &            \\" _n
    file write `fh' "            &" ///
        "            &            &" ///
        "(" %7.4f (`se_3_`cutoff'') ")&" ///
        "            &            &            &            \\[0.3em]" _n

    /* Row: IHS sac count */
    file write `fh' "Post $\times$ IHS(sac count)&" ///
        "            &            &            &" ///
        %12.4f (`b_4_`cutoff'') "\sym{`s_4_`cutoff''}&" ///
        %12.4f (`b_5_`cutoff'') "\sym{`s_5_`cutoff''}&" ///
        "            &            \\" _n
    file write `fh' "            &" ///
        "            &            &            &" ///
        "(" %7.4f (`se_4_`cutoff'') ")&" ///
        "(" %7.4f (`se_5_`cutoff'') ")&" ///
        "            &            \\" _n

    /* Row: IHS sac rate */
    file write `fh' "Post $\times$ IHS(sac rate)&" ///
        "            &            &            &" ///
        "            &            &" ///
        %12.4f (`b_6_`cutoff'') "\sym{`s_6_`cutoff''}&" ///
        "            \\" _n
    file write `fh' "            &" ///
        "            &            &            &" ///
        "            &            &" ///
        "(" %7.4f (`se_6_`cutoff'') ")&" ///
        "            \\[0.3em]" _n

    /* Row: ln sac reference */
    file write `fh' "Post $\times$ $\ln$(sac per 100k)&" ///
        "            &            &            &" ///
        "            &            &            &" ///
        %12.4f (`b_7_`cutoff'') "\sym{`s_7_`cutoff''}\\" _n
    file write `fh' "            &" ///
        "            &            &            &" ///
        "            &            &            &" ///
        "(" %7.4f (`se_7_`cutoff'') ")\\" _n

    file write `fh' "\midrule" _n
    file write `fh' "Cohort size control&" ///
        "            &     Yes         &            &" ///
        "            &     Yes         &            &            \\" _n
    file write `fh' "Minority control&" ///
        "     Yes         &     Yes         &     Yes         &" ///
        "     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "County FE   &" ///
        "     Yes         &     Yes         &     Yes         &" ///
        "     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "Cohort FE   &" ///
        "     Yes         &     Yes         &     Yes         &" ///
        "     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "Wave FE     &" ///
        "     Yes         &     Yes         &     Yes         &" ///
        "     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "Cohort window&" ///
        " [1920, 1956] & [1920, 1956] & [1920, 1956] &" ///
        " [1920, 1956] & [1920, 1956] & [1920, 1956] & [1920, 1956] \\" _n
    file write `fh' "Treatment start&" ///
        "     `cutoff'         &     `cutoff'         &     `cutoff'         &" ///
        "     `cutoff'         &     `cutoff'         &     `cutoff'         &     `cutoff'         \\" _n
    file write `fh' "Observations&" ///
        %12.0fc (`n_1_`cutoff'') "&" ///
        %12.0fc (`n_2_`cutoff'') "&" ///
        %12.0fc (`n_3_`cutoff'') "&" ///
        %12.0fc (`n_4_`cutoff'') "&" ///
        %12.0fc (`n_5_`cutoff'') "&" ///
        %12.0fc (`n_6_`cutoff'') "&" ///
        %12.0fc (`n_7_`cutoff'') "\\" _n
    file write `fh' "R-squared   &" ///
        %12.3f (`r2_1_`cutoff'') "&" ///
        %12.3f (`r2_2_`cutoff'') "&" ///
        %12.3f (`r2_3_`cutoff'') "&" ///
        %12.3f (`r2_4_`cutoff'') "&" ///
        %12.3f (`r2_5_`cutoff'') "&" ///
        %12.3f (`r2_6_`cutoff'') "&" ///
        %12.3f (`r2_7_`cutoff'') "\\" _n
    file write `fh' "Counties    &" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "&" ///
        %12.0fc (`nc_1_`cutoff'') "\\" _n
    file write `fh' "\bottomrule" _n
    file write `fh' "\end{tabular*}" _n
    file write `fh' "}" _n

    file close `fh'

    di "=== Table saved: pooled_baseline_sacrifice_`suffix'_v1.tex ==="
}

di ""
di "=== ALL SACRIFICE-PLACE TABLES SAVED ==="

exit, clear
