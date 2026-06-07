/*  ================================================================
    FAST PPML: Baseline (Table 3 & 4)
    ================================================================ */
clear all
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global outdir "${proj}/paper/assets/tables"
set maxvar 10000

use "${proj}/data/temp/master_pooled_ppml_v1.dta", clear

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

foreach cutoff in 1940 1946 {
    local dropyr = `cutoff' - 1
    gen post = (birth_i >= `cutoff')
    gen drop_yr = (birth_i == `dropyr')
    
    /* PPML IHS(rate) */
    ppmlhdfe eduy c.ihs_rate##ib0.post minority i.wave if !drop_yr, absorb(county_num birth_i) vce(cluster county_num)
    local b_ihs_`cutoff' = _b[1.post#c.ihs_rate]
    local se_ihs_`cutoff' = _se[1.post#c.ihs_rate]
    local p_ihs_`cutoff' = 2*ttail(e(df_r), abs(`b_ihs_`cutoff''/`se_ihs_`cutoff''))
    local n_ihs_`cutoff' = e(N)

    /* PPML Dummy */
    ppmlhdfe eduy i.d_count_high##ib0.post ln_cohort_n minority i.wave if !drop_yr, absorb(county_num birth_i) vce(cluster county_num)
    local b_dum_`cutoff' = _b[1.d_count_high#1.post]
    local se_dum_`cutoff' = _se[1.d_count_high#1.post]
    local p_dum_`cutoff' = 2*ttail(e(df_r), abs(`b_dum_`cutoff''/`se_dum_`cutoff''))
    local n_dum_`cutoff' = e(N)

    drop post drop_yr
}

/* TABLE PPML COMPARISON */
tempname fh
file open `fh' using "${outdir}/pooled_ppml_comparison_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{IHS(rate) Treatment}&\multicolumn{2}{c}{Binary Treatment}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &Cutoff 1940&Cutoff 1946&Cutoff 1940&Cutoff 1946\\" _n
file write `fh' "\midrule" _n

_stars `p_ihs_1940'
file write `fh' "Post $\times$ Treatment&" %9.4f (`b_ihs_1940') "\sym{`r(star)'}"
_stars `p_ihs_1946'
file write `fh' "&" %9.4f (`b_ihs_1946') "\sym{`r(star)'}"
_stars `p_dum_1940'
file write `fh' "&" %9.4f (`b_dum_1940') "\sym{`r(star)'}"
_stars `p_dum_1946'
file write `fh' "&" %9.4f (`b_dum_1946') "\sym{`r(star)'}\\" _n

file write `fh' "            &(" %7.4f (`se_ihs_1940') ")&(" %7.4f (`se_ihs_1946') ")&(" %7.4f (`se_dum_1940') ")&(" %7.4f (`se_dum_1946') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Observations&" %12.0fc (`n_ihs_1940') "&" %12.0fc (`n_ihs_1946') "&" %12.0fc (`n_dum_1940') "&" %12.0fc (`n_dum_1946') "\\" _n
file write `fh' "County \& Birth-yr FE & Yes & Yes & Yes & Yes \\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

di "=== FAST PPML BASELINE COMPLETE ==="
