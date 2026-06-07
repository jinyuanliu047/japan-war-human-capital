/*  ================================================================
    CONSOLIDATED ULTRA-FAST PPML (FIXED VARIABLE NAMES)
    ================================================================ */
clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global outdir "${proj}/paper/assets/tables"
set maxvar 10000

*--------------------------------------------------------------
* 1. PREP TREATMENT
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw pop_1953
gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
merge 1:1 countyid_curr6 using "${proj}/data/temp/county_controls_full_v1.dta", keep(master match) nogen
merge 1:1 countyid_curr6 using "${proj}/data/temp/revolutionary_proxy_controls_v1.dta", keep(master match) nogen
gen ln_victims_cr = ln(1 + victims_cr) if !missing(victims_cr)
gen ln_grain_output = ln(1 + grain_output) if !missing(grain_output)
gen ihs_longmarch = ln(longmarch_martyr_per100k + sqrt(longmarch_martyr_per100k^2 + 1)) if !missing(longmarch_martyr_per100k)
gen ihs_korea     = ln(korea_war_martyr_per100k + sqrt(korea_war_martyr_per100k^2 + 1)) if !missing(korea_war_martyr_per100k)
foreach v in sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 ihs_longmarch ihs_korea {
    replace `v' = 0 if missing(`v')
}
tempfile treat
save `treat'

*--------------------------------------------------------------
* 2. DATA POOLING (ALIGNED WITH MAINVARS VARNAMES)
*--------------------------------------------------------------
import delimited "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", clear varnames(1) stringcols(_all)
rename countyid_old6 old6
rename countyid_curr6_final countyid_curr6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace countyid_curr6 = subinstr(countyid_curr6, ".0", "", .)
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop old6, force
tempfile cw82
save `cw82'

/* 1982 */
use countyid birthyr eduy ethniccn using "${proj}/data/temp/census_1982_mainvars_v1.dta", clear
keep if inrange(birthyr, 1920, 1956)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using `cw82', keep(match) nogen
gen female = .
gen wave = 1
tempfile w1
save `w1'

/* 1990: age and age_c instead of birthyr */
use county age age_c eduy ethniccn using "${proj}/data/temp/census_1990_mainvars_v1.dta", clear
gen birthyr = 1000 + age_c*100 + age
keep if inrange(birthyr, 1920, 1956)
rename county countyid_curr6
gen female = .
gen wave = 2
tempfile w2
save `w2'

/* 2000: uid and birthyr */
use uid birthyr eduy ethniccn using "${proj}/data/temp/census_2000_mainvars_v1.dta", clear
keep if inrange(birthyr, 1920, 1956)
rename uid countyid_curr6
gen female = .
gen wave = 3
append using `w1'
append using `w2'

gen minority = (ethniccn != 1) if !missing(ethniccn)
gen birth_i = floor(birthyr)
summ eduy, detail
replace eduy = r(p1) if eduy < r(p1)
replace eduy = r(p99) if eduy > r(p99) & !missing(eduy)
merge m:1 countyid_curr6 using `treat', keep(match) nogen
encode countyid_curr6, gen(county_num)
bysort county_num birth_i wave: gen cohort_n = _N
gen ln_cohort_n = ln(cohort_n)

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*--------------------------------------------------------------
* 3. REGRESSIONS
*--------------------------------------------------------------
foreach cutoff in 1940 1946 {
    local dropyr = `cutoff' - 1
    gen post = (birth_i >= `cutoff')
    gen drop_yr = (birth_i == `dropyr')
    ppmlhdfe eduy c.ihs_rate##ib0.post minority i.wave if !drop_yr, absorb(county_num birth_i) vce(cluster county_num)
    local b_ihs_`cutoff' = _b[1.post#c.ihs_rate]
    local se_ihs_`cutoff' = _se[1.post#c.ihs_rate]
    local p_ihs_`cutoff' = 2*ttail(e(df_r), abs(`b_ihs_`cutoff''/`se_ihs_`cutoff''))
    local n_ihs_`cutoff' = e(N)
    ppmlhdfe eduy i.d_count_high##ib0.post ln_cohort_n minority i.wave if !drop_yr, absorb(county_num birth_i) vce(cluster county_num)
    local b_dum_`cutoff' = _b[1.d_count_high#1.post]
    local se_dum_`cutoff' = _se[1.d_count_high#1.post]
    local p_dum_`cutoff' = 2*ttail(e(df_r), abs(`b_dum_`cutoff''/`se_dum_`cutoff''))
    local n_dum_`cutoff' = e(N)
    drop post drop_yr
}

tempname fh
file open `fh' using "$outdir/pooled_ppml_comparison_v1.tex", write replace
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

* HISTORICAL
local controls "sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64"
gen post1940 = (birth_i >= 1940)
gen drop1939 = (birth_i == 1939)

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
local n_ihs_all = e(N)
local p_ihs_all = 2*ttail(e(df_r), abs(`b_ihs_all'/`se_ihs_all'))

tempname fh2
file open `fh2' using "$outdir/pooled_ppml_historical_controls_expanded_v1.tex", write replace
file write `fh2' "{" _n
file write `fh2' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh2' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{7}{c}}" _n
file write `fh2' "\toprule" _n
file write `fh2' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}\\" _n
file write `fh2' "\midrule" _n
_stars `p_ihs_base'
file write `fh2' "Post $\times$ IHS(rate)&" %9.4f (`b_ihs_base') "\sym{`r(star)'}"
forvalues j = 1/5 {
    _stars `p_ihs_`j''
    file write `fh2' "&" %9.4f (`b_ihs_`j'') "\sym{`r(star)'}"
}
_stars `p_ihs_all'
file write `fh2' "&" %9.4f (`b_ihs_all') "\sym{`r(star)'}\\" _n
file write `fh2' "\bottomrule\end{tabular*}}" _n
file close `fh2'

di "DONE ALL."
exit, clear
