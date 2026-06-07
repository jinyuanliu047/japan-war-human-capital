/*  ================================================================
    ULTRA-FAST PPML: Baseline (Comparison of main specs)
    ================================================================ */
clear all
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global outdir "${proj}/paper/assets/tables"
set maxvar 10000

/* Load via mainvars if possible (User's hint) */
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")

*--------------------------------------------------------------
* Treatment prep
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw pop_1953
gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
tempfile treat
save `treat'

*--------------------------------------------------------------
* Pooling (Using mainvars)
*--------------------------------------------------------------
use countyid birthyr eduy ethniccn using "$c1982", clear
keep if inrange(birthyr, 1920, 1956)
gen str6 old6 = string(countyid, "%06.0f")
/* merge crosswalk for 1982 */
merge m:1 old6 using "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", keep(match) nogen
rename countyid_curr6_final countyid_curr6
replace countyid_curr6 = subinstr(countyid_curr6, ".0", "", .)
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
gen wave = 1
tempfile w1
save `w1'

use county birthyr eduy ethniccn using "$c1990", clear
keep if inrange(birthyr, 1920, 1956)
rename county countyid_curr6
gen wave = 2
tempfile w2
save `w2'

use uid birthyr eduy ethniccn using "$c2000", clear
keep if inrange(birthyr, 1920, 1956)
rename uid countyid_curr6
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

*--------------------------------------------------------------
* Regressions
*--------------------------------------------------------------
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
di "DONE."
