clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global outdir "${proj}/paper/assets/tables"

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

tempfile treat panel

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 martyr_count_1931_1945
rename countyid_curr6 county_curr6
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
summ martyr_count_1931_1945, detail
gen high_count = (martyr_count_1931_1945 > r(p50)) if !missing(martyr_count_1931_1945)
save `treat'

use "${proj}/data/raw/county_year_data.dta", clear
keep countyid year school_primary school_secondary tch_pri_total tch_sec_total prov
keep if inrange(year, 1964, 1990)
merge m:1 countyid using "${proj}/data/raw/county_data.dta", keepusing(region2000) nogen
drop if missing(region2000)
gen str6 county_curr6 = string(region2000, "%06.0f")
merge m:1 county_curr6 using `treat', keep(match) nogen

foreach y in school_primary school_secondary tch_pri_total tch_sec_total {
    gen ln1p_`y' = ln(`y' + 1) if !missing(`y')
}

save `panel'

local ylist "ln1p_school_primary ln1p_school_secondary ln1p_tch_pri_total ln1p_tch_sec_total"
local xlist "ihs_rate high_count"

foreach x of local xlist {
    local tag = cond("`x'"=="ihs_rate", "ihs", "dum")
    local i = 0
    foreach y of local ylist {
        local ++i
        quietly reg `y' `x' i.year i.prov, vce(cluster countyid)
        local b_`tag'_`i' = _b[`x']
        local se_`tag'_`i' = _se[`x']
        local p_`tag'_`i' = 2*ttail(e(df_r), abs(`b_`tag'_`i''/`se_`tag'_`i''))
        local n_`tag'_`i' = e(N)
        local fb_`tag'_`i' : di %9.4f `b_`tag'_`i''
        local fse_`tag'_`i' : di %7.4f `se_`tag'_`i''
        local fn_`tag'_`i' : di %12.0fc `n_`tag'_`i''
        _stars `p_`tag'_`i''
        local s_`tag'_`i' "`r(star)'"
    }
}

tempname fh
file open `fh' using "${outdir}/mechanism_school_teacher_panel_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}\\" _n
file write `fh' "            &Primary schools&Secondary schools&Primary teachers&Secondary teachers\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
file write `fh' "IHS(rate)&`fb_ihs_1'\sym{`s_ihs_1'}&`fb_ihs_2'\sym{`s_ihs_2'}&`fb_ihs_3'\sym{`s_ihs_3'}&`fb_ihs_4'\sym{`s_ihs_4'}\\" _n
file write `fh' "            &( `fse_ihs_1')&( `fse_ihs_2')&( `fse_ihs_3')&( `fse_ihs_4')\\[0.5em]" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
file write `fh' "High count&`fb_dum_1'\sym{`s_dum_1'}&`fb_dum_2'\sym{`s_dum_2'}&`fb_dum_3'\sym{`s_dum_3'}&`fb_dum_4'\sym{`s_dum_4'}\\" _n
file write `fh' "            &( `fse_dum_1')&( `fse_dum_2')&( `fse_dum_3')&( `fse_dum_4')\\" _n
file write `fh' "\midrule" _n
file write `fh' "Province FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Year FE&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Obs (IHS)&`fn_ihs_1'&`fn_ihs_2'&`fn_ihs_3'&`fn_ihs_4'\\" _n
file write `fh' "Obs (Dummy)&`fn_dum_1'&`fn_dum_2'&`fn_dum_3'&`fn_dum_4'\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

di as text "Written: ${outdir}/mechanism_school_teacher_panel_v1.tex"
exit, clear
