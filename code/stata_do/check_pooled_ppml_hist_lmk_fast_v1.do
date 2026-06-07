/*  ================================================================
    FAST PPML: Historical controls + Long March/Korea
    ================================================================ */
clear all
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global outdir "${proj}/paper/assets/tables"
set maxvar 10000

use "${proj}/data/temp/master_pooled_ppml_v1.dta", clear

gen post1940 = (birth_i >= 1940)
gen drop1939 = (birth_i == 1939)

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*--------------------------------------------------------------
*  regs
*--------------------------------------------------------------
local controls "sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64"

/* Panel A: IHS */
ppmlhdfe eduy c.ihs_rate##ib0.post1940 minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_ihs_base = _b[1.post1940#c.ihs_rate]
local se_ihs_base = _se[1.post1940#c.ihs_rate]
local p_ihs_base = 2*ttail(e(df_r), abs(`b_ihs_base'/`se_ihs_base'))
local n_ihs_base = e(N)

local col = 0
foreach ctrl of local controls {
    local col = `col' + 1
    ppmlhdfe eduy c.ihs_rate##ib0.post1940 c.`ctrl'##ib0.post1940 minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
    local b_ihs_`col' = _b[1.post1940#c.ihs_rate]
    local se_ihs_`col' = _se[1.post1940#c.ihs_rate]
    local p_ihs_`col' = 2*ttail(e(df_r), abs(`b_ihs_`col''/`se_ihs_`col''))
    local n_ihs_`col' = e(N)
}

ppmlhdfe eduy c.ihs_rate##ib0.post1940 c.sdy_density##ib0.post1940 c.ins_famine##ib0.post1940 c.ln_victims_cr##ib0.post1940 c.ln_grain_output##ib0.post1940 c.urbanratio64##ib0.post1940 minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_ihs_all = _b[1.post1940#c.ihs_rate]
local se_ihs_all = _se[1.post1940#c.ihs_rate]
local p_ihs_all = 2*ttail(e(df_r), abs(`b_ihs_all'/`se_ihs_all'))
local n_ihs_all = e(N)

/* Panel B: Dummy */
ppmlhdfe eduy i.d_count_high##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_dum_base = _b[1.d_count_high#1.post1940]
local se_dum_base = _se[1.d_count_high#1.post1940]
local p_dum_base = 2*ttail(e(df_r), abs(`b_dum_base'/`se_dum_base'))
local n_dum_base = e(N)

local col = 0
foreach ctrl of local controls {
    local col = `col' + 1
    ppmlhdfe eduy i.d_count_high##ib0.post1940 c.`ctrl'##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
    local b_dum_`col' = _b[1.d_count_high#1.post1940]
    local se_dum_`col' = _se[1.d_count_high#1.post1940]
    local p_dum_`col' = 2*ttail(e(df_r), abs(`b_dum_`col''/`se_dum_`col''))
    local n_dum_`col' = e(N)
}

ppmlhdfe eduy i.d_count_high##ib0.post1940 c.sdy_density##ib0.post1940 c.ins_famine##ib0.post1940 c.ln_victims_cr##ib0.post1940 c.ln_grain_output##ib0.post1940 c.urbanratio64##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_dum_all = _b[1.d_count_high#1.post1940]
local se_dum_all = _se[1.d_count_high#1.post1940]
local p_dum_all = 2*ttail(e(df_r), abs(`b_dum_all'/`se_dum_all'))
local n_dum_all = e(N)

/* OUT TEX (Historical) */
tempname fh
file open `fh' using "${outdir}/pooled_ppml_historical_controls_expanded_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{7}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}\\" _n
file write `fh' "            &Baseline&+SDY&+Famine&+CR victims&+Grain&+Urban&+All five\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{8}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
_stars `p_ihs_base'
file write `fh' "Post $\times$ IHS(rate)&" %9.4f (`b_ihs_base') "\sym{`r(star)'}"
forvalues j = 1/5 {
    _stars `p_ihs_`j''
    file write `fh' "&" %9.4f (`b_ihs_`j'') "\sym{`r(star)'}"
}
_stars `p_ihs_all'
file write `fh' "&" %9.4f (`b_ihs_all') "\sym{`r(star)'}\\" _n
file write `fh' "            &(" %7.4f (`se_ihs_base') ")"
forvalues j = 1/5 {
    file write `fh' "&(" %7.4f (`se_ihs_`j'') ")"
}
file write `fh' "&(" %7.4f (`se_ihs_all') ")\\[0.5em]" _n
file write `fh' "\multicolumn{8}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
_stars `p_dum_base'
file write `fh' "Post $\times$ High count&" %9.4f (`b_dum_base') "\sym{`r(star)'}"
forvalues j = 1/5 {
    _stars `p_dum_`j''
    file write `fh' "&" %9.4f (`b_dum_`j'') "\sym{`r(star)'}"
}
_stars `p_dum_all'
file write `fh' "&" %9.4f (`b_dum_all') "\sym{`r(star)'}\\" _n
file write `fh' "            &(" %7.4f (`se_dum_base') ")"
forvalues j = 1/5 {
    file write `fh' "&(" %7.4f (`se_dum_`j'') ")"
}
file write `fh' "&(" %7.4f (`se_dum_all') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Historical control&None&SDY density&Famine&CR victims&Grain output&Urban ratio&All five\\" _n
file write `fh' "Cohort size control&     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_ihs_base')
forvalues j = 1/5 {
    file write `fh' "&" %12.0fc (`n_ihs_`j'')
}
file write `fh' "&" %12.0fc (`n_ihs_all') "\\" _n
file write `fh' "Obs (Dummy)&" %12.0fc (`n_dum_base')
forvalues j = 1/5 {
    file write `fh' "&" %12.0fc (`n_dum_`j'')
}
file write `fh' "&" %12.0fc (`n_dum_all') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

*--------------------------------------------------------------
* LM/K
*--------------------------------------------------------------
ppmlhdfe eduy c.ihs_rate##ib0.post1940 minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_i1 = _b[1.post1940#c.ihs_rate]
local se_i1 = _se[1.post1940#c.ihs_rate]
local p_i1 = 2*ttail(e(df_r), abs(`b_i1'/`se_i1'))
local n_i1 = e(N)

ppmlhdfe eduy c.ihs_rate##ib0.post1940 c.ihs_longmarch##ib0.post1940 minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_i2 = _b[1.post1940#c.ihs_rate]
local se_i2 = _se[1.post1940#c.ihs_rate]
local p_i2 = 2*ttail(e(df_r), abs(`b_i2'/`se_i2'))
local n_i2 = e(N)

ppmlhdfe eduy c.ihs_rate##ib0.post1940 c.ihs_korea##ib0.post1940 minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_i3 = _b[1.post1940#c.ihs_rate]
local se_i3 = _se[1.post1940#c.ihs_rate]
local p_i3 = 2*ttail(e(df_r), abs(`b_i3'/`se_i3'))
local n_i3 = e(N)

ppmlhdfe eduy c.ihs_rate##ib0.post1940 c.ihs_longmarch##ib0.post1940 c.ihs_korea##ib0.post1940 minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_i4 = _b[1.post1940#c.ihs_rate]
local se_i4 = _se[1.post1940#c.ihs_rate]
local p_i4 = 2*ttail(e(df_r), abs(`b_i4'/`se_i4'))
local n_i4 = e(N)

/* Dummy */
ppmlhdfe eduy i.d_count_high##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_d1 = _b[1.d_count_high#1.post1940]
local se_d1 = _se[1.d_count_high#1.post1940]
local p_d1 = 2*ttail(e(df_r), abs(`b_d1'/`se_d1'))
local n_d1 = e(N)

ppmlhdfe eduy i.d_count_high##ib0.post1940 c.ihs_longmarch##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_d2 = _b[1.d_count_high#1.post1940]
local se_d2 = _se[1.d_count_high#1.post1940]
local p_d2 = 2*ttail(e(df_r), abs(`b_d2'/`se_d2'))
local n_d2 = e(N)

ppmlhdfe eduy i.d_count_high##ib0.post1940 c.ihs_korea##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_d3 = _b[1.d_count_high#1.post1940]
local se_d3 = _se[1.d_count_high#1.post1940]
local p_d3 = 2*ttail(e(df_r), abs(`b_d3'/`se_d3'))
local n_d3 = e(N)

ppmlhdfe eduy i.d_count_high##ib0.post1940 c.ihs_longmarch##ib0.post1940 c.ihs_korea##ib0.post1940 ln_cohort_n minority i.wave if !drop1939, absorb(county_num birth_i) vce(cluster county_num)
local b_d4 = _b[1.d_count_high#1.post1940]
local se_d4 = _se[1.d_count_high#1.post1940]
local p_d4 = 2*ttail(e(df_r), abs(`b_d4'/`se_d4'))
local n_d4 = e(N)

/* OUT TEX (LM/K) */
tempname fh
file open `fh' using "${outdir}/pooled_ppml_longmarch_korea_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}\\" _n
file write `fh' "            &Baseline&+Long March&+Korean War&+Both\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
forvalues j = 1/4 {
    _stars `p_i`j''
    file write `fh' "&" %9.4f (`b_i`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            "
forvalues j = 1/4 {
    file write `fh' "&(" %7.4f (`se_i`j'') ")"
}
file write `fh' "\\[0.5em]" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
forvalues j = 1/4 {
    _stars `p_d`j''
    file write `fh' "&" %9.4f (`b_d`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            "
forvalues j = 1/4 {
    file write `fh' "&(" %7.4f (`se_d`j'') ")"
}
file write `fh' "\\" _n
file write `fh' "\midrule" _n
file write `fh' "Long March (IHS)&            &     Yes         &            &     Yes         \\" _n
file write `fh' "Korean War (IHS)&            &            &     Yes         &     Yes         \\" _n
file write `fh' "Cohort size control&     Yes         &     Yes         &     Yes         &     Yes         \\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_i1') "&" %12.0fc (`n_i2') "&" %12.0fc (`n_i3') "&" %12.0fc (`n_i4') "\\" _n
file write `fh' "Obs (Dummy)&" %12.0fc (`n_d1') "&" %12.0fc (`n_d2') "&" %12.0fc (`n_d3') "&" %12.0fc (`n_d4') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

di "=== FAST PPML HIST COMPLETE ==="
