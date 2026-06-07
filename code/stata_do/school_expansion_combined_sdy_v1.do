/* ================================================================
   Combined school expansion (primary+secondary) + SDY intensity
   ================================================================ */

clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

* ---------------------------------------------------------------
* Step 1: Build crosswalk county_data → treatment
* ---------------------------------------------------------------
use "${proj}/data/raw/county_data.dta", clear
gen str6 countyid_curr6 = string(region2000, "%06.0f") if !missing(region2000)

preserve
    use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
    keep countyid_curr6 martyr_per100k_1953 ln_martyr_raw
    gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
    replace martyr_count = 0 if missing(martyr_count)
    gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
    summ martyr_count, detail
    local med = r(p50)
    gen high_count = (martyr_count > `med') if !missing(martyr_count)
    tempfile treat
    save `treat'
restore

merge m:1 countyid_curr6 using `treat'
keep if _merge == 3
drop _merge
keep countyid ihs_rate high_count martyr_per100k_1953 sdy sdy_density pop1964

* ---------------------------------------------------------------
* Step 2: Merge school expansion
* ---------------------------------------------------------------
merge 1:1 countyid using "${proj}/data/raw/rural_school_expansion.dta"
keep if _merge == 3
drop _merge

di "=== Combined school expansion + SDY + treatment ==="
di "N matched: " _N

* ---------------------------------------------------------------
* Step 3: Create combined school expansion variable
* ---------------------------------------------------------------
gen total_speed = primary_speed + secondary_speed
label var total_speed "Combined school expansion speed (primary + secondary)"

* Also try average
gen avg_speed = (primary_speed + secondary_speed) / 2
label var avg_speed "Average school expansion speed"

summ primary_speed secondary_speed total_speed avg_speed sdy_density ihs_rate high_count

* ---------------------------------------------------------------
* Step 4: Regressions — Combined school expansion
* ---------------------------------------------------------------
di ""
di "========================================"
di "  COMBINED SCHOOL EXPANSION (primary + secondary)"
di "========================================"

di "--- IHS treatment ---"
reg total_speed ihs_rate, robust
est store comb_ihs

di "--- Dummy treatment ---"
reg total_speed high_count, robust
est store comb_dum

di ""
di "========================================"
di "  SEPARATE: PRIMARY SCHOOL"
di "========================================"
di "--- IHS ---"
reg primary_speed ihs_rate, robust
est store pri_ihs

di "--- Dummy ---"
reg primary_speed high_count, robust
est store pri_dum

di ""
di "========================================"
di "  SEPARATE: SECONDARY SCHOOL"
di "========================================"
di "--- IHS ---"
reg secondary_speed ihs_rate, robust
est store sec_ihs

di "--- Dummy ---"
reg secondary_speed high_count, robust
est store sec_dum

* ---------------------------------------------------------------
* Step 5: SDY intensity as outcome
* ---------------------------------------------------------------
di ""
di "========================================"
di "  SDY INTENSITY AS OUTCOME"
di "========================================"

* sdy_density = sdy / pop1964
summ sdy_density, detail
summ sdy, detail

* Also create IHS(sdy_density)
gen ihs_sdy = ln(sdy_density + sqrt(sdy_density^2 + 1)) if !missing(sdy_density)

di "--- SDY density ~ IHS(rate) ---"
reg sdy_density ihs_rate, robust
est store sdy_ihs

di "--- SDY density ~ Dummy ---"
reg sdy_density high_count, robust
est store sdy_dum

di "--- IHS(SDY) ~ IHS(rate) ---"
reg ihs_sdy ihs_rate, robust
est store ihssdy_ihs

di "--- IHS(SDY) ~ Dummy ---"
reg ihs_sdy high_count, robust
est store ihssdy_dum

di "--- ln(SDY+1) ~ IHS(rate) ---"
gen ln_sdy = ln(sdy + 1) if !missing(sdy)
reg ln_sdy ihs_rate, robust
est store lnsdy_ihs

di "--- ln(SDY+1) ~ Dummy ---"
reg ln_sdy high_count, robust
est store lnsdy_dum

* ---------------------------------------------------------------
* Step 6: Output combined table
* ---------------------------------------------------------------
capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

* Collect results for LaTeX table
tempname fh
file open `fh' using "${proj}/paper/assets/tables/mechanism_school_sdy_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}\\" _n
file write `fh' "            &Primary&Secondary&Combined&SDY density\\" _n
file write `fh' "\midrule" _n

* Panel A: IHS treatment
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n

foreach spec in pri sec comb sdy {
    est restore `spec'_ihs
}

est restore pri_ihs
local b1 = _b[ihs_rate]
local se1 = _se[ihs_rate]
local p1 = 2*ttail(e(df_r), abs(`b1'/`se1'))
local n1 = e(N)

est restore sec_ihs
local b2 = _b[ihs_rate]
local se2 = _se[ihs_rate]
local p2 = 2*ttail(e(df_r), abs(`b2'/`se2'))
local n2 = e(N)

est restore comb_ihs
local b3 = _b[ihs_rate]
local se3 = _se[ihs_rate]
local p3 = 2*ttail(e(df_r), abs(`b3'/`se3'))
local n3 = e(N)

est restore sdy_ihs
local b4 = _b[ihs_rate]
local se4 = _se[ihs_rate]
local p4 = 2*ttail(e(df_r), abs(`b4'/`se4'))
local n4 = e(N)

_stars `p1'
local s1 "`r(star)'"
_stars `p2'
local s2 "`r(star)'"
_stars `p3'
local s3 "`r(star)'"
_stars `p4'
local s4 "`r(star)'"

file write `fh' "IHS(rate)&" %9.4f (`b1') "\sym{`s1'}&" %9.4f (`b2') "\sym{`s2'}&" %9.4f (`b3') "\sym{`s3'}&" %9.4f (`b4') "\sym{`s4'}\\" _n
file write `fh' "            &(" %7.4f (`se1') ")&(" %7.4f (`se2') ")&(" %7.4f (`se3') ")&(" %7.4f (`se4') ")\\" _n
file write `fh' "\\[0.5em]" _n

* Panel B: Dummy treatment
file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n

est restore pri_dum
local b1 = _b[high_count]
local se1 = _se[high_count]
local p1 = 2*ttail(e(df_r), abs(`b1'/`se1'))

est restore sec_dum
local b2 = _b[high_count]
local se2 = _se[high_count]
local p2 = 2*ttail(e(df_r), abs(`b2'/`se2'))

est restore comb_dum
local b3 = _b[high_count]
local se3 = _se[high_count]
local p3 = 2*ttail(e(df_r), abs(`b3'/`se3'))

est restore sdy_dum
local b4 = _b[high_count]
local se4 = _se[high_count]
local p4 = 2*ttail(e(df_r), abs(`b4'/`se4'))

_stars `p1'
local s1 "`r(star)'"
_stars `p2'
local s2 "`r(star)'"
_stars `p3'
local s3 "`r(star)'"
_stars `p4'
local s4 "`r(star)'"

file write `fh' "High count&" %9.4f (`b1') "\sym{`s1'}&" %9.4f (`b2') "\sym{`s2'}&" %9.4f (`b3') "\sym{`s3'}&" %9.4f (`b4') "\sym{`s4'}\\" _n
file write `fh' "            &(" %7.4f (`se1') ")&(" %7.4f (`se2') ")&(" %7.4f (`se3') ")&(" %7.4f (`se4') ")\\" _n

file write `fh' "\midrule" _n
file write `fh' "Observations&" %12.0fc (`n1') "&" %12.0fc (`n2') "&" %12.0fc (`n3') "&" %12.0fc (`n4') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== School expansion + SDY table saved ==="

exit, clear
