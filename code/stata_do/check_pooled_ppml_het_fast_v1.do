/*  ================================================================
    FAST PPML: Heterogeneity
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

tempname memhold
postfile `memhold' str20 subgroup beta se pval n_obs using "${proj}/data/temp/pooled_ppml_het_results.dta", replace

foreach cutoff in 1940 1946 {
    gen post = (birth_i >= `cutoff')
    gen drop_yr = (birth_i == `cutoff' - 1)

    /* Male */
    ppmlhdfe eduy i.d_count_high##ib0.post minority i.wave if !drop_yr & female==0, absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    post `memhold' ("male_`cutoff'") (`b') (`se') (`p') (e(N))

    /* Female */
    ppmlhdfe eduy i.d_count_high##ib0.post minority i.wave if !drop_yr & female==1, absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    post `memhold' ("female_`cutoff'") (`b') (`se') (`p') (e(N))

    /* Low Base Edu */
    ppmlhdfe eduy i.d_count_high##ib0.post minority i.wave if !drop_yr & high_base_edu==0, absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    post `memhold' ("lowbase_`cutoff'") (`b') (`se') (`p') (e(N))

    /* High Base Edu */
    ppmlhdfe eduy i.d_count_high##ib0.post minority i.wave if !drop_yr & high_base_edu==1, absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    post `memhold' ("highbase_`cutoff'") (`b') (`se') (`p') (e(N))

    drop post drop_yr
}
postclose `memhold'

/* TABLE GENERATION */
use "${proj}/data/temp/pooled_ppml_het_results.dta", clear
tempname fh
file open `fh' using "${outdir}/pooled_ppml_heterogeneity_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "                    &\multicolumn{2}{c}{Cutoff 1940}  &\multicolumn{2}{c}{Cutoff 1946}  \\" _n
file write `fh' "                    & Coeff. & Obs. & Coeff. & Obs.  \\" _n
file write `fh' "\midrule" _n

local row = 1
foreach grp in "male" "female" "lowbase" "highbase" {
    if "`grp'" == "male" file write `fh' "\multicolumn{5}{l}{\textit{A. Gender}} \\[0.2em]" _n
    if "`grp'" == "lowbase" file write `fh' "\multicolumn{5}{l}{\textit{B. County pre-war education}} \\[0.2em]" _n
    
    local lab = cond("`grp'"=="male","Male",cond("`grp'"=="female","Female",cond("`grp'"=="lowbase","Low base education","High base education")))
    
    foreach cut in 1940 1946 {
        summ beta if subgroup == "`grp'_`cut'"
        local b`cut' = r(mean)
        summ se if subgroup == "`grp'_`cut'"
        local se`cut' = r(mean)
        summ pval if subgroup == "`grp'_`cut'"
        local p`cut' = r(mean)
        summ n_obs if subgroup == "`grp'_`cut'"
        local n`cut' = r(mean)
        _stars `p`cut''
        local s`cut' "`r(star)'"
    }
    file write `fh' "`lab'  &" %8.3f (`b1940') "\sym{`s1940'}  &" %12.0fc (`n1940') "  &" %8.3f (`b1946') "\sym{`s1946'}  &" %12.0fc (`n1946') "  \\" _n
    file write `fh' "                    & (" %5.3f (`se1940') ")  &  & (" %5.3f (`se1946') ")  &  \\" _n
    if "`grp'" == "female" | "`grp'" == "highbase" file write `fh' "[0.3em]" _n
}

file write `fh' "\midrule" _n
file write `fh' "Controls& \multicolumn{4}{c}{Minority, County FE, Birth cohort FE, Wave FE} \\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

di "=== FAST PPML HET COMPLETE ==="
