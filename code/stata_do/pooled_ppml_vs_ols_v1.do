/*  ================================================================
    POOLED PPML vs OLS: Appendix B comparison table (single-panel,
    individual-level, pooled 1982+1990+2000 microdata)
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

gen post = (birth_i >= 1940)
gen drop_yr = (birth_i == 1939)

/* ===== OLS: IHS(rate) ===== */
reghdfejl eduy c.ihs_rate##ib0.post minority if !drop_yr, absorb(county_num birth_i wave) cluster(county_num)
local b_ols_ihs  = _b[1.post#c.ihs_rate]
local se_ols_ihs = _se[1.post#c.ihs_rate]
local p_ols_ihs  = 2*ttail(e(df_r), abs(`b_ols_ihs'/`se_ols_ihs'))
local n_ols_ihs  = e(N)

/* ===== OLS: Binary ===== */
reghdfejl eduy i.d_count_high##ib0.post minority if !drop_yr, absorb(county_num birth_i wave) cluster(county_num)
local b_ols_dum  = _b[1.d_count_high#1.post]
local se_ols_dum = _se[1.d_count_high#1.post]
local p_ols_dum  = 2*ttail(e(df_r), abs(`b_ols_dum'/`se_ols_dum'))
local n_ols_dum  = e(N)

/* ===== PPML: IHS(rate) ===== */
ppmlhdfe eduy c.ihs_rate##ib0.post minority if !drop_yr, absorb(county_num birth_i wave) vce(cluster county_num)
local b_ppml_ihs  = _b[1.post#c.ihs_rate]
local se_ppml_ihs = _se[1.post#c.ihs_rate]
local p_ppml_ihs  = 2*ttail(e(df_r), abs(`b_ppml_ihs'/`se_ppml_ihs'))
local n_ppml_ihs  = e(N)

/* ===== PPML: Binary ===== */
ppmlhdfe eduy i.d_count_high##ib0.post minority if !drop_yr, absorb(county_num birth_i wave) vce(cluster county_num)
local b_ppml_dum  = _b[1.d_count_high#1.post]
local se_ppml_dum = _se[1.d_count_high#1.post]
local p_ppml_dum  = 2*ttail(e(df_r), abs(`b_ppml_dum'/`se_ppml_dum'))
local n_ppml_dum  = e(N)

/* ===== WRITE TABLE ===== */
tempname fh
file open `fh' using "${outdir}/pooled_ppml_vs_ols_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{IHS(rate)}&\multicolumn{2}{c}{Above-median dummy}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &OLS&PPML&OLS&PPML\\" _n
file write `fh' "\midrule" _n

_stars `p_ols_ihs'
local s_ols_ihs = "`r(star)'"
_stars `p_ppml_ihs'
local s_ppml_ihs = "`r(star)'"
_stars `p_ols_dum'
local s_ols_dum = "`r(star)'"
_stars `p_ppml_dum'
local s_ppml_dum = "`r(star)'"

file write `fh' "Post $\times$ Treatment"
file write `fh' "&" %9.4f (`b_ols_ihs')  "\sym{`s_ols_ihs'}"
file write `fh' "&" %9.4f (`b_ppml_ihs') "\sym{`s_ppml_ihs'}"
file write `fh' "&" %9.4f (`b_ols_dum')  "\sym{`s_ols_dum'}"
file write `fh' "&" %9.4f (`b_ppml_dum') "\sym{`s_ppml_dum'}\\" _n

file write `fh' "            &(" %7.4f (`se_ols_ihs') ")"
file write `fh' "&(" %7.4f (`se_ppml_ihs') ")"
file write `fh' "&(" %7.4f (`se_ols_dum') ")"
file write `fh' "&(" %7.4f (`se_ppml_dum') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Minority control&Yes&Yes&Yes&Yes\\" _n
file write `fh' "County FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Cohort FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Wave FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Observations&" %12.0fc (`n_ols_ihs') "&" %12.0fc (`n_ppml_ihs') "&" %12.0fc (`n_ols_dum') "&" %12.0fc (`n_ppml_dum') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

di "=== POOLED PPML vs OLS TABLE COMPLETE ==="
