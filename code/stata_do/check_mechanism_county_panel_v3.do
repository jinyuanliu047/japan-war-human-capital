/* ================================================================
   Mechanism: Government education investment
   County-year panel 1964-1990 outcomes:
     - Fiscal education spending
     - Primary / secondary schools
     - Primary / secondary teachers

   Unified table with TWO columns per outcome (IHS | Dummy),
   no Panel A/B structure.

   Also runs panel specs:
     - Cross-sectional OLS (collapsed averages)
     - Panel with province FE + year FE
     - Panel with county FE + treat x linear trend
   ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
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

*---- treatment
tempfile treat
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_raw
rename countyid_curr6 county_curr6
gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
summ martyr_count, detail
gen high_count = (martyr_count > r(p50)) if !missing(martyr_count)
save `treat'

*---- panel 1964-1990
use "${proj}/data/raw/county_year_data.dta", clear
keep countyid year school_primary school_secondary tch_pri_total tch_sec_total fiscal_edu prov
keep if inrange(year, 1964, 1990)
merge m:1 countyid using "${proj}/data/raw/county_data.dta", keepusing(region2000) nogen
drop if missing(region2000)
gen str6 county_curr6 = string(region2000, "%06.0f")
merge m:1 county_curr6 using `treat', keep(match) nogen

foreach y in school_primary school_secondary tch_pri_total tch_sec_total fiscal_edu {
    gen ln1p_`y' = ln(`y' + 1) if !missing(`y')
}

egen county_num = group(countyid)
gen trend = year - 1964

tempfile panel
save `panel'

*---- outcomes
local ylist "ln1p_fiscal_edu ln1p_school_primary ln1p_school_secondary ln1p_tch_pri_total ln1p_tch_sec_total"
local labs  `" "Avg. fiscal edu" "Primary schools" "Secondary schools" "Primary teachers" "Secondary teachers" "'

* ==============================================================
* SPEC 1: Cross-sectional OLS (collapsed averages)
* ==============================================================
preserve
    collapse (mean) ln1p_fiscal_edu ln1p_school_primary ln1p_school_secondary ///
        ln1p_tch_pri_total ln1p_tch_sec_total ihs_rate high_count, by(countyid)
    local k = 0
    foreach y of local ylist {
        local ++k
        quietly reg `y' ihs_rate, vce(robust)
        local b_cs_ihs_`k' = _b[ihs_rate]
        local se_cs_ihs_`k' = _se[ihs_rate]
        local p_cs_ihs_`k' = 2*ttail(e(df_r), abs(`b_cs_ihs_`k''/`se_cs_ihs_`k''))
        local n_cs_ihs_`k' = e(N)

        quietly reg `y' high_count, vce(robust)
        local b_cs_dum_`k' = _b[high_count]
        local se_cs_dum_`k' = _se[high_count]
        local p_cs_dum_`k' = 2*ttail(e(df_r), abs(`b_cs_dum_`k''/`se_cs_dum_`k''))
        local n_cs_dum_`k' = e(N)
    }
restore

* ==============================================================
* SPEC 2: Panel with province FE + year FE
* ==============================================================
local k = 0
foreach y of local ylist {
    local ++k
    quietly reghdfejl `y' ihs_rate, absorb(prov year) vce(cluster county_num)
    local b_py_ihs_`k' = _b[ihs_rate]
    local se_py_ihs_`k' = _se[ihs_rate]
    local p_py_ihs_`k' = 2*ttail(e(df_r), abs(`b_py_ihs_`k''/`se_py_ihs_`k''))
    local n_py_ihs_`k' = e(N)

    quietly reghdfejl `y' high_count, absorb(prov year) vce(cluster county_num)
    local b_py_dum_`k' = _b[high_count]
    local se_py_dum_`k' = _se[high_count]
    local p_py_dum_`k' = 2*ttail(e(df_r), abs(`b_py_dum_`k''/`se_py_dum_`k''))
    local n_py_dum_`k' = e(N)
}

* ==============================================================
* SPEC 3: Panel with COUNTY FE + treat x linear trend
* (Treatment is time-invariant; county FE absorbs level. Interact
* with trend to estimate differential growth.)
* ==============================================================
gen ihs_trend  = ihs_rate * trend
gen dum_trend  = high_count * trend

local k = 0
foreach y of local ylist {
    local ++k
    quietly reghdfejl `y' ihs_trend, absorb(county_num year) vce(cluster county_num)
    local b_cy_ihs_`k' = _b[ihs_trend]
    local se_cy_ihs_`k' = _se[ihs_trend]
    local p_cy_ihs_`k' = 2*ttail(e(df_r), abs(`b_cy_ihs_`k''/`se_cy_ihs_`k''))
    local n_cy_ihs_`k' = e(N)

    quietly reghdfejl `y' dum_trend, absorb(county_num year) vce(cluster county_num)
    local b_cy_dum_`k' = _b[dum_trend]
    local se_cy_dum_`k' = _se[dum_trend]
    local p_cy_dum_`k' = 2*ttail(e(df_r), abs(`b_cy_dum_`k''/`se_cy_dum_`k''))
    local n_cy_dum_`k' = e(N)
}

* ==============================================================
* Output: one table per outcome group
*
* Table 1: Fiscal education spending alone (outcome 1)
*   Columns: (1) IHS cross-sectional, (2) Dummy cross-sectional,
*            (3) IHS panel prov+year, (4) Dummy panel prov+year,
*            (5) IHS county FE x trend, (6) Dummy county FE x trend
* ==============================================================
tempname fh
file open `fh' using "${outdir}/mechanism_fiscal_edu_v2.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{6}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{Cross-sectional OLS}&\multicolumn{2}{c}{Panel: Prov+Year FE}&\multicolumn{2}{c}{Panel: County FE + Trend}\\" _n
file write `fh' "\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}" _n
file write `fh' "            &(1) IHS&(2) Dummy&(3) IHS&(4) Dummy&(5) IHS\$\times\$trend&(6) Dummy\$\times\$trend\\" _n
file write `fh' "\midrule" _n
_stars `p_cs_ihs_1'
local fb1 : di %9.4f `b_cs_ihs_1'
local s1 "`r(star)'"
_stars `p_cs_dum_1'
local fb2 : di %9.4f `b_cs_dum_1'
local s2 "`r(star)'"
_stars `p_py_ihs_1'
local fb3 : di %9.4f `b_py_ihs_1'
local s3 "`r(star)'"
_stars `p_py_dum_1'
local fb4 : di %9.4f `b_py_dum_1'
local s4 "`r(star)'"
_stars `p_cy_ihs_1'
local fb5 : di %9.4f `b_cy_ihs_1'
local s5 "`r(star)'"
_stars `p_cy_dum_1'
local fb6 : di %9.4f `b_cy_dum_1'
local s6 "`r(star)'"
local fse1 : di %7.4f `se_cs_ihs_1'
local fse2 : di %7.4f `se_cs_dum_1'
local fse3 : di %7.4f `se_py_ihs_1'
local fse4 : di %7.4f `se_py_dum_1'
local fse5 : di %7.4f `se_cy_ihs_1'
local fse6 : di %7.4f `se_cy_dum_1'
local fn1 : di %12.0fc `n_cs_ihs_1'
local fn2 : di %12.0fc `n_cs_dum_1'
local fn3 : di %12.0fc `n_py_ihs_1'
local fn4 : di %12.0fc `n_py_dum_1'
local fn5 : di %12.0fc `n_cy_ihs_1'
local fn6 : di %12.0fc `n_cy_dum_1'
file write `fh' "Treatment&`fb1'\sym{`s1'}&`fb2'\sym{`s2'}&`fb3'\sym{`s3'}&`fb4'\sym{`s4'}&`fb5'\sym{`s5'}&`fb6'\sym{`s6'}\\" _n
file write `fh' "            &(`fse1')&(`fse2')&(`fse3')&(`fse4')&(`fse5')&(`fse6')\\" _n
file write `fh' "\midrule" _n
file write `fh' "County FE&No&No&No&No&Yes&Yes\\" _n
file write `fh' "Province FE&No&No&Yes&Yes&No&No\\" _n
file write `fh' "Year FE&No&No&Yes&Yes&Yes&Yes\\" _n
file write `fh' "Observations&`fn1'&`fn2'&`fn3'&`fn4'&`fn5'&`fn6'\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Fiscal edu table written ==="

* ==============================================================
* Table 2: Schools and teachers (outcomes 2-5)
*   One row per outcome, two columns (IHS | Dummy)
*   Using the panel with COUNTY FE + treat x trend spec (strictest)
* ==============================================================
tempname fh
file open `fh' using "${outdir}/mechanism_school_teacher_panel_v2.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}\\" _n
file write `fh' "            &Primary schools&Secondary schools&Primary teachers&Secondary teachers\\" _n
file write `fh' "\midrule" _n

* Panel specification: Province + Year FE (levels)
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: Province + Year FE (levels)}}\\" _n
_stars `p_py_ihs_2'
local fb2 : di %9.4f `b_py_ihs_2'
local s2 "`r(star)'"
_stars `p_py_ihs_3'
local fb3 : di %9.4f `b_py_ihs_3'
local s3 "`r(star)'"
_stars `p_py_ihs_4'
local fb4 : di %9.4f `b_py_ihs_4'
local s4 "`r(star)'"
_stars `p_py_ihs_5'
local fb5 : di %9.4f `b_py_ihs_5'
local s5 "`r(star)'"
local fse2 : di %7.4f `se_py_ihs_2'
local fse3 : di %7.4f `se_py_ihs_3'
local fse4 : di %7.4f `se_py_ihs_4'
local fse5 : di %7.4f `se_py_ihs_5'
file write `fh' "IHS(rate)&`fb2'\sym{`s2'}&`fb3'\sym{`s3'}&`fb4'\sym{`s4'}&`fb5'\sym{`s5'}\\" _n
file write `fh' "            &(`fse2')&(`fse3')&(`fse4')&(`fse5')\\[0.3em]" _n

_stars `p_py_dum_2'
local fb2 : di %9.4f `b_py_dum_2'
local s2 "`r(star)'"
_stars `p_py_dum_3'
local fb3 : di %9.4f `b_py_dum_3'
local s3 "`r(star)'"
_stars `p_py_dum_4'
local fb4 : di %9.4f `b_py_dum_4'
local s4 "`r(star)'"
_stars `p_py_dum_5'
local fb5 : di %9.4f `b_py_dum_5'
local s5 "`r(star)'"
local fse2 : di %7.4f `se_py_dum_2'
local fse3 : di %7.4f `se_py_dum_3'
local fse4 : di %7.4f `se_py_dum_4'
local fse5 : di %7.4f `se_py_dum_5'
file write `fh' "High count&`fb2'\sym{`s2'}&`fb3'\sym{`s3'}&`fb4'\sym{`s4'}&`fb5'\sym{`s5'}\\" _n
file write `fh' "            &(`fse2')&(`fse3')&(`fse4')&(`fse5')\\[0.5em]" _n

* County FE with trend interaction
file write `fh' "\multicolumn{5}{l}{\textit{Panel B: County FE + Year FE, Treat\$\times\$Trend}}\\" _n
_stars `p_cy_ihs_2'
local fb2 : di %9.4f `b_cy_ihs_2'
local s2 "`r(star)'"
_stars `p_cy_ihs_3'
local fb3 : di %9.4f `b_cy_ihs_3'
local s3 "`r(star)'"
_stars `p_cy_ihs_4'
local fb4 : di %9.4f `b_cy_ihs_4'
local s4 "`r(star)'"
_stars `p_cy_ihs_5'
local fb5 : di %9.4f `b_cy_ihs_5'
local s5 "`r(star)'"
local fse2 : di %7.4f `se_cy_ihs_2'
local fse3 : di %7.4f `se_cy_ihs_3'
local fse4 : di %7.4f `se_cy_ihs_4'
local fse5 : di %7.4f `se_cy_ihs_5'
file write `fh' "IHS\$\times\$trend&`fb2'\sym{`s2'}&`fb3'\sym{`s3'}&`fb4'\sym{`s4'}&`fb5'\sym{`s5'}\\" _n
file write `fh' "            &(`fse2')&(`fse3')&(`fse4')&(`fse5')\\[0.3em]" _n

_stars `p_cy_dum_2'
local fb2 : di %9.4f `b_cy_dum_2'
local s2 "`r(star)'"
_stars `p_cy_dum_3'
local fb3 : di %9.4f `b_cy_dum_3'
local s3 "`r(star)'"
_stars `p_cy_dum_4'
local fb4 : di %9.4f `b_cy_dum_4'
local s4 "`r(star)'"
_stars `p_cy_dum_5'
local fb5 : di %9.4f `b_cy_dum_5'
local s5 "`r(star)'"
local fse2 : di %7.4f `se_cy_dum_2'
local fse3 : di %7.4f `se_cy_dum_3'
local fse4 : di %7.4f `se_cy_dum_4'
local fse5 : di %7.4f `se_cy_dum_5'
file write `fh' "Dummy\$\times\$trend&`fb2'\sym{`s2'}&`fb3'\sym{`s3'}&`fb4'\sym{`s4'}&`fb5'\sym{`s5'}\\" _n
file write `fh' "            &(`fse2')&(`fse3')&(`fse4')&(`fse5')\\" _n
file write `fh' "\midrule" _n
local fn2 : di %12.0fc `n_py_ihs_2'
local fn3 : di %12.0fc `n_py_ihs_3'
local fn4 : di %12.0fc `n_py_ihs_4'
local fn5 : di %12.0fc `n_py_ihs_5'
file write `fh' "Observations&`fn2'&`fn3'&`fn4'&`fn5'\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== School/teacher panel table written ==="

exit, clear
