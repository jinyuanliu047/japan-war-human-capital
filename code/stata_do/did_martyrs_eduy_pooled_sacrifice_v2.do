/*  ================================================================
    SACRIFICE-PLACE ROBUSTNESS — COMPREHENSIVE APPENDIX B
    Pooled 1982+1990+2000 census microdata
    Treatment: martyrs counted by PLACE OF DEATH (sacrifice place)

    Produces:
      - pooled_baseline_sacrifice_main_v1.tex           (B1, cutoff 1940)      [regen]
      - pooled_baseline_sacrifice_robust1946_v1.tex     (B2, cutoff 1946)      [regen]
      - sacrifice_histcontrols_v1.tex                   (B3, with hist ctrls)  [new]
      - sacrifice_lmkplacebo_v1.tex                     (B4, LM/Korea control) [new]
      - sacrifice_het_individual_v1.tex                 (B5, gender/base-edu)  [new]
      - sacrifice_het_county_v1.tex                     (B6, clan/treaty)      [new]
      - sacrifice_mech_v1.tex                           (B7, fiscal spending)  [new]
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global master  "${proj}/data/temp/master_pooled_ppml_v1.dta"
global sac_csv "${proj}/data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_sacrifice_place_counts_merge_ready.csv"
global pop1953 "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta"
global clan    "${proj}/data/temp/county_clan_quake_controls_v1.dta"
global outdir  "${proj}/paper/assets/tables"

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*==============================================================
* STEP 1: Build sacrifice-place treatment at 6-digit county level
*==============================================================
import delimited "${sac_csv}", clear varnames(1) stringcols(1 2 3)
gen str6 countyid_curr6 = substr(merge_place_id, 1, 6)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"
destring martyr_count, replace force
replace martyr_count = 0 if missing(martyr_count)
collapse (sum) martyr_sac_count = martyr_count, by(countyid_curr6)
tempfile sac_county
save `sac_county'

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
* STEP 2: Load pre-pooled master; merge sacrifice + clan
*==============================================================
use "${master}", clear
tostring countyid_curr6, replace force
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)

merge m:1 countyid_curr6 using `treat_sac', keep(master match) nogen
merge m:1 countyid_curr6 using "${clan}", keep(master match) nogen keepusing(clan_num ln_clan)
gen clan_any = (clan_num > 0 & !missing(clan_num))

gen str4 pref4 = substr(countyid_curr6, 1, 4)
gen treaty_port_pref = 0
foreach p in 1201 1202 1301 2101 2102 2201 2301 3101 3201 3202 3203 3204 3205 3206 3207 3210 3211 3301 3302 3304 3305 3307 3402 3501 3502 3601 3701 3702 3706 3707 4101 4201 4202 4301 4401 4402 4403 4404 4405 4406 4419 4420 4501 4504 5001 5101 5301 5401 6201 6501 {
    replace treaty_port_pref = 1 if pref4 == "`p'"
}

di "=== POOLED SAC N = " _N " ==="

gen post1940 = (birth_i >= 1940)
gen post1946 = (birth_i >= 1946)
gen byte drop1939 = (birth_i == 1939)
gen byte drop1945 = (birth_i == 1945)

*==============================================================
* STEP 3: Baseline (7 cols x 2 cutoffs)  — regenerate v1 tables
*==============================================================
foreach cutoff in 1940 1946 {
    local dropyr = `cutoff' - 1
    capture drop post drop_yr
    gen post = (birth_i >= `cutoff')
    gen byte drop_yr = (birth_i == `dropyr')

    /* (1) Dummy count */
    reghdfejl eduy i.d_sac_count_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_1_`cutoff'  = _b[1.d_sac_count_high#1.post]
    local se_1_`cutoff' = _se[1.d_sac_count_high#1.post]
    local p_1_`cutoff'  = 2*ttail(e(df_r), abs(`b_1_`cutoff''/`se_1_`cutoff''))
    local n_1_`cutoff'  = e(N)
    local r2_1_`cutoff' = e(r2)
    local nc_1_`cutoff' = e(N_clust)

    /* (2) Dummy count + cohort ctrl */
    reghdfejl eduy i.d_sac_count_high##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_2_`cutoff'  = _b[1.d_sac_count_high#1.post]
    local se_2_`cutoff' = _se[1.d_sac_count_high#1.post]
    local p_2_`cutoff'  = 2*ttail(e(df_r), abs(`b_2_`cutoff''/`se_2_`cutoff''))
    local n_2_`cutoff'  = e(N)
    local r2_2_`cutoff' = e(r2)

    /* (3) Dummy rate */
    reghdfejl eduy i.d_sac_rate_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_3_`cutoff'  = _b[1.d_sac_rate_high#1.post]
    local se_3_`cutoff' = _se[1.d_sac_rate_high#1.post]
    local p_3_`cutoff'  = 2*ttail(e(df_r), abs(`b_3_`cutoff''/`se_3_`cutoff''))
    local n_3_`cutoff'  = e(N)
    local r2_3_`cutoff' = e(r2)

    /* (4) IHS count */
    reghdfejl eduy c.ihs_sac_count##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_4_`cutoff'  = _b[1.post#c.ihs_sac_count]
    local se_4_`cutoff' = _se[1.post#c.ihs_sac_count]
    local p_4_`cutoff'  = 2*ttail(e(df_r), abs(`b_4_`cutoff''/`se_4_`cutoff''))
    local n_4_`cutoff'  = e(N)
    local r2_4_`cutoff' = e(r2)

    /* (5) IHS count + cohort ctrl */
    reghdfejl eduy c.ihs_sac_count##ib0.post c.ln_cohort_n##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_5_`cutoff'  = _b[1.post#c.ihs_sac_count]
    local se_5_`cutoff' = _se[1.post#c.ihs_sac_count]
    local p_5_`cutoff'  = 2*ttail(e(df_r), abs(`b_5_`cutoff''/`se_5_`cutoff''))
    local n_5_`cutoff'  = e(N)
    local r2_5_`cutoff' = e(r2)

    /* (6) IHS rate */
    reghdfejl eduy c.ihs_sac_rate##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_6_`cutoff'  = _b[1.post#c.ihs_sac_rate]
    local se_6_`cutoff' = _se[1.post#c.ihs_sac_rate]
    local p_6_`cutoff'  = 2*ttail(e(df_r), abs(`b_6_`cutoff''/`se_6_`cutoff''))
    local n_6_`cutoff'  = e(N)
    local r2_6_`cutoff' = e(r2)

    /* (7) ln reference */
    reghdfejl eduy c.ln_martyr_sac_per100k_1953##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_7_`cutoff'  = _b[1.post#c.ln_martyr_sac_per100k_1953]
    local se_7_`cutoff' = _se[1.post#c.ln_martyr_sac_per100k_1953]
    local p_7_`cutoff'  = 2*ttail(e(df_r), abs(`b_7_`cutoff''/`se_7_`cutoff''))
    local n_7_`cutoff'  = e(N)
    local r2_7_`cutoff' = e(r2)

    drop post drop_yr
}

/* Write baseline tables (same 7-col layout) */
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
    file write `fh' "Post $\times$ High sacrifice count&" %12.4f (`b_1_`cutoff'') "\sym{`s_1_`cutoff''}&" %12.4f (`b_2_`cutoff'') "\sym{`s_2_`cutoff''}&            &            &            &            &            \\" _n
    file write `fh' "            &(" %7.4f (`se_1_`cutoff'') ")&(" %7.4f (`se_2_`cutoff'') ")&            &            &            &            &            \\" _n
    file write `fh' "Post $\times$ High sacrifice rate&            &            &" %12.4f (`b_3_`cutoff'') "\sym{`s_3_`cutoff''}&            &            &            &            \\" _n
    file write `fh' "            &            &            &(" %7.4f (`se_3_`cutoff'') ")&            &            &            &            \\[0.3em]" _n
    file write `fh' "Post $\times$ IHS(sac count)&            &            &            &" %12.4f (`b_4_`cutoff'') "\sym{`s_4_`cutoff''}&" %12.4f (`b_5_`cutoff'') "\sym{`s_5_`cutoff''}&            &            \\" _n
    file write `fh' "            &            &            &            &(" %7.4f (`se_4_`cutoff'') ")&(" %7.4f (`se_5_`cutoff'') ")&            &            \\" _n
    file write `fh' "Post $\times$ IHS(sac rate)&            &            &            &            &            &" %12.4f (`b_6_`cutoff'') "\sym{`s_6_`cutoff''}&            \\" _n
    file write `fh' "            &            &            &            &            &            &(" %7.4f (`se_6_`cutoff'') ")&            \\[0.3em]" _n
    file write `fh' "Post $\times$ $\ln$(sac per 100k)&            &            &            &            &            &            &" %12.4f (`b_7_`cutoff'') "\sym{`s_7_`cutoff''}\\" _n
    file write `fh' "            &            &            &            &            &            &            &(" %7.4f (`se_7_`cutoff'') ")\\" _n
    file write `fh' "\midrule" _n
    file write `fh' "Cohort size control&            &     Yes         &            &            &     Yes         &            &            \\" _n
    file write `fh' "Minority control&     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "County FE   &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "Cohort FE   &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "Wave FE     &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         \\" _n
    file write `fh' "Cohort window& [1920, 1956] & [1920, 1956] & [1920, 1956] & [1920, 1956] & [1920, 1956] & [1920, 1956] & [1920, 1956] \\" _n
    file write `fh' "Treatment start&     `cutoff'         &     `cutoff'         &     `cutoff'         &     `cutoff'         &     `cutoff'         &     `cutoff'         &     `cutoff'         \\" _n
    file write `fh' "Observations&" %12.0fc (`n_1_`cutoff'') "&" %12.0fc (`n_2_`cutoff'') "&" %12.0fc (`n_3_`cutoff'') "&" %12.0fc (`n_4_`cutoff'') "&" %12.0fc (`n_5_`cutoff'') "&" %12.0fc (`n_6_`cutoff'') "&" %12.0fc (`n_7_`cutoff'') "\\" _n
    file write `fh' "R-squared   &" %12.3f (`r2_1_`cutoff'') "&" %12.3f (`r2_2_`cutoff'') "&" %12.3f (`r2_3_`cutoff'') "&" %12.3f (`r2_4_`cutoff'') "&" %12.3f (`r2_5_`cutoff'') "&" %12.3f (`r2_6_`cutoff'') "&" %12.3f (`r2_7_`cutoff'') "\\" _n
    file write `fh' "Counties    &" %12.0fc (`nc_1_`cutoff'') "&" %12.0fc (`nc_1_`cutoff'') "&" %12.0fc (`nc_1_`cutoff'') "&" %12.0fc (`nc_1_`cutoff'') "&" %12.0fc (`nc_1_`cutoff'') "&" %12.0fc (`nc_1_`cutoff'') "&" %12.0fc (`nc_1_`cutoff'') "\\" _n
    file write `fh' "\bottomrule" _n
    file write `fh' "\end{tabular*}" _n
    file write `fh' "}" _n
    file close `fh'
}

*==============================================================
* STEP 4: Historical controls augmentation (cutoff 1940 & 1946)
*   4 cols: IHS baseline, IHS+ctrls, Dummy baseline, Dummy+ctrls
*==============================================================
capture drop post drop_yr
gen post = (birth_i >= 1940)
gen byte drop_yr = (birth_i == 1939)

local hist_ctrls "c.sdy_density##ib0.post c.ins_famine##ib0.post c.ln_victims_cr##ib0.post c.ln_grain_output##ib0.post c.urbanratio64##ib0.post"

foreach cutoff in 1940 1946 {
    local dropyr = `cutoff' - 1
    capture drop post drop_yr
    gen post = (birth_i >= `cutoff')
    gen byte drop_yr = (birth_i == `dropyr')

    /* IHS rate, no ctrls */
    reghdfejl eduy c.ihs_sac_rate##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_h1_`cutoff' = _b[1.post#c.ihs_sac_rate]
    local se_h1_`cutoff' = _se[1.post#c.ihs_sac_rate]
    local p_h1_`cutoff' = 2*ttail(e(df_r), abs(`b_h1_`cutoff''/`se_h1_`cutoff''))
    local n_h1_`cutoff' = e(N)

    /* IHS rate + hist ctrls */
    reghdfejl eduy c.ihs_sac_rate##ib0.post `hist_ctrls' minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_h2_`cutoff' = _b[1.post#c.ihs_sac_rate]
    local se_h2_`cutoff' = _se[1.post#c.ihs_sac_rate]
    local p_h2_`cutoff' = 2*ttail(e(df_r), abs(`b_h2_`cutoff''/`se_h2_`cutoff''))
    local n_h2_`cutoff' = e(N)

    /* Dummy, no ctrls */
    reghdfejl eduy i.d_sac_count_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_h3_`cutoff' = _b[1.d_sac_count_high#1.post]
    local se_h3_`cutoff' = _se[1.d_sac_count_high#1.post]
    local p_h3_`cutoff' = 2*ttail(e(df_r), abs(`b_h3_`cutoff''/`se_h3_`cutoff''))
    local n_h3_`cutoff' = e(N)

    /* Dummy + hist ctrls */
    reghdfejl eduy i.d_sac_count_high##ib0.post `hist_ctrls' minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_h4_`cutoff' = _b[1.d_sac_count_high#1.post]
    local se_h4_`cutoff' = _se[1.d_sac_count_high#1.post]
    local p_h4_`cutoff' = 2*ttail(e(df_r), abs(`b_h4_`cutoff''/`se_h4_`cutoff''))
    local n_h4_`cutoff' = e(N)

    drop post drop_yr
}

/* Write hist controls table (4 cols x 2 cutoffs = 4+4=8 cols) */
forvalues j = 1/4 {
    foreach cutoff in 1940 1946 {
        _stars `p_h`j'_`cutoff''
        local sh`j'_`cutoff' "`r(star)'"
    }
}

tempname fh
file open `fh' using "${outdir}/sacrifice_histcontrols_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{Cutoff 1940}&\multicolumn{2}{c}{Cutoff 1946}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &No ctrls&+Hist ctrls&No ctrls&+Hist ctrls\\" _n
file write `fh' "\midrule" _n
file write `fh' "Post $\times$ IHS(sac rate)&" %9.4f (`b_h1_1940') "\sym{`sh1_1940'}&" %9.4f (`b_h2_1940') "\sym{`sh2_1940'}&" %9.4f (`b_h1_1946') "\sym{`sh1_1946'}&" %9.4f (`b_h2_1946') "\sym{`sh2_1946'}\\" _n
file write `fh' "            &(" %7.4f (`se_h1_1940') ")&(" %7.4f (`se_h2_1940') ")&(" %7.4f (`se_h1_1946') ")&(" %7.4f (`se_h2_1946') ")\\[0.3em]" _n
file write `fh' "Post $\times$ High sacrifice count&" %9.4f (`b_h3_1940') "\sym{`sh3_1940'}&" %9.4f (`b_h4_1940') "\sym{`sh4_1940'}&" %9.4f (`b_h3_1946') "\sym{`sh3_1946'}&" %9.4f (`b_h4_1946') "\sym{`sh4_1946'}\\" _n
file write `fh' "            &(" %7.4f (`se_h3_1940') ")&(" %7.4f (`se_h4_1940') ")&(" %7.4f (`se_h3_1946') ")&(" %7.4f (`se_h4_1946') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Historical controls&No&Yes&No&Yes\\" _n
file write `fh' "Minority control&Yes&Yes&Yes&Yes\\" _n
file write `fh' "County FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Cohort FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Wave FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Observations&" %12.0fc (`n_h1_1940') "&" %12.0fc (`n_h2_1940') "&" %12.0fc (`n_h1_1946') "&" %12.0fc (`n_h2_1946') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

*==============================================================
* STEP 5: LM/Korea placebo as control (cutoff 1940)
*   Baseline sacrifice effect vs. after controlling for
*   native-place Long March and Korea per-capita rates
*==============================================================
capture drop post drop_yr
gen post = (birth_i >= 1940)
gen byte drop_yr = (birth_i == 1939)

/* Col 1: sacrifice IHS rate baseline (no LM/Korea) */
reghdfejl eduy c.ihs_sac_rate##ib0.post minority i.wave if !drop_yr, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_p1 = _b[1.post#c.ihs_sac_rate]
local se_p1 = _se[1.post#c.ihs_sac_rate]
local p_p1 = 2*ttail(e(df_r), abs(`b_p1'/`se_p1'))
local n_p1 = e(N)

/* Col 2: sacrifice + LM (native-place) */
reghdfejl eduy c.ihs_sac_rate##ib0.post c.ihs_longmarch##ib0.post minority i.wave if !drop_yr, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_p2  = _b[1.post#c.ihs_sac_rate]
local se_p2 = _se[1.post#c.ihs_sac_rate]
local p_p2  = 2*ttail(e(df_r), abs(`b_p2'/`se_p2'))
local b_p2lm = _b[1.post#c.ihs_longmarch]
local se_p2lm = _se[1.post#c.ihs_longmarch]
local p_p2lm  = 2*ttail(e(df_r), abs(`b_p2lm'/`se_p2lm'))
local n_p2 = e(N)

/* Col 3: sacrifice + Korea */
reghdfejl eduy c.ihs_sac_rate##ib0.post c.ihs_korea##ib0.post minority i.wave if !drop_yr, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_p3 = _b[1.post#c.ihs_sac_rate]
local se_p3 = _se[1.post#c.ihs_sac_rate]
local p_p3 = 2*ttail(e(df_r), abs(`b_p3'/`se_p3'))
local b_p3ko = _b[1.post#c.ihs_korea]
local se_p3ko = _se[1.post#c.ihs_korea]
local p_p3ko = 2*ttail(e(df_r), abs(`b_p3ko'/`se_p3ko'))
local n_p3 = e(N)

/* Col 4: sacrifice + LM + Korea */
reghdfejl eduy c.ihs_sac_rate##ib0.post c.ihs_longmarch##ib0.post c.ihs_korea##ib0.post minority i.wave if !drop_yr, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_p4 = _b[1.post#c.ihs_sac_rate]
local se_p4 = _se[1.post#c.ihs_sac_rate]
local p_p4 = 2*ttail(e(df_r), abs(`b_p4'/`se_p4'))
local b_p4lm = _b[1.post#c.ihs_longmarch]
local se_p4lm = _se[1.post#c.ihs_longmarch]
local p_p4lm = 2*ttail(e(df_r), abs(`b_p4lm'/`se_p4lm'))
local b_p4ko = _b[1.post#c.ihs_korea]
local se_p4ko = _se[1.post#c.ihs_korea]
local p_p4ko = 2*ttail(e(df_r), abs(`b_p4ko'/`se_p4ko'))
local n_p4 = e(N)

forvalues j = 1/4 {
    _stars `p_p`j''
    local s_p`j' "`r(star)'"
}
foreach j in 2lm 3ko 4lm 4ko {
    _stars `p_p`j''
    local s_p`j' "`r(star)'"
}

tempname fh
file open `fh' using "${outdir}/sacrifice_lmkplacebo_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}\\" _n
file write `fh' "            &Baseline&+ Long March&+ Korea&+ Both\\" _n
file write `fh' "\midrule" _n
file write `fh' "Post $\times$ IHS(sac rate)&" %9.4f (`b_p1') "\sym{`s_p1'}&" %9.4f (`b_p2') "\sym{`s_p2'}&" %9.4f (`b_p3') "\sym{`s_p3'}&" %9.4f (`b_p4') "\sym{`s_p4'}\\" _n
file write `fh' "            &(" %7.4f (`se_p1') ")&(" %7.4f (`se_p2') ")&(" %7.4f (`se_p3') ")&(" %7.4f (`se_p4') ")\\[0.3em]" _n
file write `fh' "Post $\times$ IHS(Long March)&            &" %9.4f (`b_p2lm') "\sym{`s_p2lm'}&            &" %9.4f (`b_p4lm') "\sym{`s_p4lm'}\\" _n
file write `fh' "            &            &(" %7.4f (`se_p2lm') ")&            &(" %7.4f (`se_p4lm') ")\\[0.3em]" _n
file write `fh' "Post $\times$ IHS(Korea)&            &            &" %9.4f (`b_p3ko') "\sym{`s_p3ko'}&" %9.4f (`b_p4ko') "\sym{`s_p4ko'}\\" _n
file write `fh' "            &            &            &(" %7.4f (`se_p3ko') ")&(" %7.4f (`se_p4ko') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Minority control&Yes&Yes&Yes&Yes\\" _n
file write `fh' "County FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Cohort FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Wave FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Observations&" %12.0fc (`n_p1') "&" %12.0fc (`n_p2') "&" %12.0fc (`n_p3') "&" %12.0fc (`n_p4') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

*==============================================================
* STEP 6: Individual heterogeneity — gender, base-edu
*   Cutoff 1940; IHS rate and Dummy count
*==============================================================
capture drop post drop_yr
gen post = (birth_i >= 1940)
gen byte drop_yr = (birth_i == 1939)

/* Gender: only 1990 and 2000 waves have female */
foreach g in 0 1 {
    di "=== Gender `g' (0=male, 1=female) ==="
    reghdfejl eduy c.ihs_sac_rate##ib0.post minority i.wave if !drop_yr & female==`g', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_g`g'_ihs = _b[1.post#c.ihs_sac_rate]
    local se_g`g'_ihs = _se[1.post#c.ihs_sac_rate]
    local p_g`g'_ihs = 2*ttail(e(df_r), abs(`b_g`g'_ihs'/`se_g`g'_ihs'))
    local n_g`g'_ihs = e(N)

    reghdfejl eduy i.d_sac_count_high##ib0.post minority i.wave if !drop_yr & female==`g', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_g`g'_dum = _b[1.d_sac_count_high#1.post]
    local se_g`g'_dum = _se[1.d_sac_count_high#1.post]
    local p_g`g'_dum = 2*ttail(e(df_r), abs(`b_g`g'_dum'/`se_g`g'_dum'))
    local n_g`g'_dum = e(N)
}

/* Base education */
foreach be in 0 1 {
    di "=== Base edu `be' (0=low, 1=high) ==="
    reghdfejl eduy c.ihs_sac_rate##ib0.post minority i.wave if !drop_yr & high_base_edu==`be', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_be`be'_ihs = _b[1.post#c.ihs_sac_rate]
    local se_be`be'_ihs = _se[1.post#c.ihs_sac_rate]
    local p_be`be'_ihs = 2*ttail(e(df_r), abs(`b_be`be'_ihs'/`se_be`be'_ihs'))
    local n_be`be'_ihs = e(N)

    reghdfejl eduy i.d_sac_count_high##ib0.post minority i.wave if !drop_yr & high_base_edu==`be', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_be`be'_dum = _b[1.d_sac_count_high#1.post]
    local se_be`be'_dum = _se[1.d_sac_count_high#1.post]
    local p_be`be'_dum = 2*ttail(e(df_r), abs(`b_be`be'_dum'/`se_be`be'_dum'))
    local n_be`be'_dum = e(N)
}

foreach tag in g0_ihs g0_dum g1_ihs g1_dum be0_ihs be0_dum be1_ihs be1_dum {
    _stars `p_`tag''
    local s_`tag' "`r(star)'"
}

tempname fh
file open `fh' using "${outdir}/sacrifice_het_individual_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: Gender}}\\" _n
file write `fh' "            &\multicolumn{2}{c}{Male}&\multicolumn{2}{c}{Female}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &IHS(rate)&Dummy&IHS(rate)&Dummy\\" _n
file write `fh' "\midrule" _n
file write `fh' "Post $\times$ Sacrifice&" %9.4f (`b_g0_ihs') "\sym{`s_g0_ihs'}&" %9.4f (`b_g0_dum') "\sym{`s_g0_dum'}&" %9.4f (`b_g1_ihs') "\sym{`s_g1_ihs'}&" %9.4f (`b_g1_dum') "\sym{`s_g1_dum'}\\" _n
file write `fh' "            &(" %7.4f (`se_g0_ihs') ")&(" %7.4f (`se_g0_dum') ")&(" %7.4f (`se_g1_ihs') ")&(" %7.4f (`se_g1_dum') ")\\" _n
file write `fh' "Observations&" %12.0fc (`n_g0_ihs') "&" %12.0fc (`n_g0_dum') "&" %12.0fc (`n_g1_ihs') "&" %12.0fc (`n_g1_dum') "\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Pre-war educational base}}\\" _n
file write `fh' "            &\multicolumn{2}{c}{Low base}&\multicolumn{2}{c}{High base}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &IHS(rate)&Dummy&IHS(rate)&Dummy\\" _n
file write `fh' "\midrule" _n
file write `fh' "Post $\times$ Sacrifice&" %9.4f (`b_be0_ihs') "\sym{`s_be0_ihs'}&" %9.4f (`b_be0_dum') "\sym{`s_be0_dum'}&" %9.4f (`b_be1_ihs') "\sym{`s_be1_ihs'}&" %9.4f (`b_be1_dum') "\sym{`s_be1_dum'}\\" _n
file write `fh' "            &(" %7.4f (`se_be0_ihs') ")&(" %7.4f (`se_be0_dum') ")&(" %7.4f (`se_be1_ihs') ")&(" %7.4f (`se_be1_dum') ")\\" _n
file write `fh' "Observations&" %12.0fc (`n_be0_ihs') "&" %12.0fc (`n_be0_dum') "&" %12.0fc (`n_be1_ihs') "&" %12.0fc (`n_be1_dum') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

*==============================================================
* STEP 7: County heterogeneity — clan, treaty port
*==============================================================
foreach cl in 0 1 {
    di "=== clan=`cl' ==="
    reghdfejl eduy c.ihs_sac_rate##ib0.post minority i.wave if !drop_yr & clan_any==`cl', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_cl`cl'_ihs = _b[1.post#c.ihs_sac_rate]
    local se_cl`cl'_ihs = _se[1.post#c.ihs_sac_rate]
    local p_cl`cl'_ihs = 2*ttail(e(df_r), abs(`b_cl`cl'_ihs'/`se_cl`cl'_ihs'))
    local n_cl`cl'_ihs = e(N)

    reghdfejl eduy i.d_sac_count_high##ib0.post minority i.wave if !drop_yr & clan_any==`cl', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_cl`cl'_dum = _b[1.d_sac_count_high#1.post]
    local se_cl`cl'_dum = _se[1.d_sac_count_high#1.post]
    local p_cl`cl'_dum = 2*ttail(e(df_r), abs(`b_cl`cl'_dum'/`se_cl`cl'_dum'))
    local n_cl`cl'_dum = e(N)
}

foreach tp in 0 1 {
    di "=== treaty=`tp' ==="
    reghdfejl eduy c.ihs_sac_rate##ib0.post minority i.wave if !drop_yr & treaty_port_pref==`tp', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_tp`tp'_ihs = _b[1.post#c.ihs_sac_rate]
    local se_tp`tp'_ihs = _se[1.post#c.ihs_sac_rate]
    local p_tp`tp'_ihs = 2*ttail(e(df_r), abs(`b_tp`tp'_ihs'/`se_tp`tp'_ihs'))
    local n_tp`tp'_ihs = e(N)

    reghdfejl eduy i.d_sac_count_high##ib0.post minority i.wave if !drop_yr & treaty_port_pref==`tp', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_tp`tp'_dum = _b[1.d_sac_count_high#1.post]
    local se_tp`tp'_dum = _se[1.d_sac_count_high#1.post]
    local p_tp`tp'_dum = 2*ttail(e(df_r), abs(`b_tp`tp'_dum'/`se_tp`tp'_dum'))
    local n_tp`tp'_dum = e(N)
}

foreach tag in cl0_ihs cl0_dum cl1_ihs cl1_dum tp0_ihs tp0_dum tp1_ihs tp1_dum {
    _stars `p_`tag''
    local s_`tag' "`r(star)'"
}

tempname fh
file open `fh' using "${outdir}/sacrifice_het_county_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: Ancestral clan presence}}\\" _n
file write `fh' "            &\multicolumn{2}{c}{No clans}&\multicolumn{2}{c}{Has clans}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &IHS(rate)&Dummy&IHS(rate)&Dummy\\" _n
file write `fh' "\midrule" _n
file write `fh' "Post $\times$ Sacrifice&" %9.4f (`b_cl0_ihs') "\sym{`s_cl0_ihs'}&" %9.4f (`b_cl0_dum') "\sym{`s_cl0_dum'}&" %9.4f (`b_cl1_ihs') "\sym{`s_cl1_ihs'}&" %9.4f (`b_cl1_dum') "\sym{`s_cl1_dum'}\\" _n
file write `fh' "            &(" %7.4f (`se_cl0_ihs') ")&(" %7.4f (`se_cl0_dum') ")&(" %7.4f (`se_cl1_ihs') ")&(" %7.4f (`se_cl1_dum') ")\\" _n
file write `fh' "Observations&" %12.0fc (`n_cl0_ihs') "&" %12.0fc (`n_cl0_dum') "&" %12.0fc (`n_cl1_ihs') "&" %12.0fc (`n_cl1_dum') "\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Treaty-port prefecture}}\\" _n
file write `fh' "            &\multicolumn{2}{c}{Non-treaty}&\multicolumn{2}{c}{Treaty port}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &IHS(rate)&Dummy&IHS(rate)&Dummy\\" _n
file write `fh' "\midrule" _n
file write `fh' "Post $\times$ Sacrifice&" %9.4f (`b_tp0_ihs') "\sym{`s_tp0_ihs'}&" %9.4f (`b_tp0_dum') "\sym{`s_tp0_dum'}&" %9.4f (`b_tp1_ihs') "\sym{`s_tp1_ihs'}&" %9.4f (`b_tp1_dum') "\sym{`s_tp1_dum'}\\" _n
file write `fh' "            &(" %7.4f (`se_tp0_ihs') ")&(" %7.4f (`se_tp0_dum') ")&(" %7.4f (`se_tp1_ihs') ")&(" %7.4f (`se_tp1_dum') ")\\" _n
file write `fh' "Observations&" %12.0fc (`n_tp0_ihs') "&" %12.0fc (`n_tp0_dum') "&" %12.0fc (`n_tp1_ihs') "&" %12.0fc (`n_tp1_dum') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

*==============================================================
* STEP 8: Mechanism — primary/junior-high completion
*   (fiscal spending uses different county data not in master;
*    completion rates are in the pooled microdata)
*==============================================================
capture drop prim_done jhigh_done
gen prim_done = (eduy >= 6) if !missing(eduy)
gen jhigh_done = (eduy >= 9) if !missing(eduy)

/* Primary, IHS rate */
reghdfejl prim_done c.ihs_sac_rate##ib0.post minority i.wave if !drop_yr, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_m1_ihs = _b[1.post#c.ihs_sac_rate]
local se_m1_ihs = _se[1.post#c.ihs_sac_rate]
local p_m1_ihs = 2*ttail(e(df_r), abs(`b_m1_ihs'/`se_m1_ihs'))
local n_m1_ihs = e(N)

/* Primary, Dummy */
reghdfejl prim_done i.d_sac_count_high##ib0.post minority i.wave if !drop_yr, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_m1_dum = _b[1.d_sac_count_high#1.post]
local se_m1_dum = _se[1.d_sac_count_high#1.post]
local p_m1_dum = 2*ttail(e(df_r), abs(`b_m1_dum'/`se_m1_dum'))
local n_m1_dum = e(N)

/* Junior-high, IHS rate */
reghdfejl jhigh_done c.ihs_sac_rate##ib0.post minority i.wave if !drop_yr, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_m2_ihs = _b[1.post#c.ihs_sac_rate]
local se_m2_ihs = _se[1.post#c.ihs_sac_rate]
local p_m2_ihs = 2*ttail(e(df_r), abs(`b_m2_ihs'/`se_m2_ihs'))
local n_m2_ihs = e(N)

/* Junior-high, Dummy */
reghdfejl jhigh_done i.d_sac_count_high##ib0.post minority i.wave if !drop_yr, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b_m2_dum = _b[1.d_sac_count_high#1.post]
local se_m2_dum = _se[1.d_sac_count_high#1.post]
local p_m2_dum = 2*ttail(e(df_r), abs(`b_m2_dum'/`se_m2_dum'))
local n_m2_dum = e(N)

foreach tag in m1_ihs m1_dum m2_ihs m2_dum {
    _stars `p_`tag''
    local s_`tag' "`r(star)'"
}

tempname fh
file open `fh' using "${outdir}/sacrifice_mech_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{Primary completion ($\geq 6$ yr)}&\multicolumn{2}{c}{Junior-high completion ($\geq 9$ yr)}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &IHS(rate)&Dummy&IHS(rate)&Dummy\\" _n
file write `fh' "\midrule" _n
file write `fh' "Post $\times$ Sacrifice&" %9.4f (`b_m1_ihs') "\sym{`s_m1_ihs'}&" %9.4f (`b_m1_dum') "\sym{`s_m1_dum'}&" %9.4f (`b_m2_ihs') "\sym{`s_m2_ihs'}&" %9.4f (`b_m2_dum') "\sym{`s_m2_dum'}\\" _n
file write `fh' "            &(" %7.4f (`se_m1_ihs') ")&(" %7.4f (`se_m1_dum') ")&(" %7.4f (`se_m2_ihs') ")&(" %7.4f (`se_m2_dum') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Minority control&Yes&Yes&Yes&Yes\\" _n
file write `fh' "County FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Cohort FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Wave FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Observations&" %12.0fc (`n_m1_ihs') "&" %12.0fc (`n_m1_dum') "&" %12.0fc (`n_m2_ihs') "&" %12.0fc (`n_m2_dum') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

di ""
di "=== ALL SACRIFICE-PLACE TABLES SAVED ==="

exit, clear
