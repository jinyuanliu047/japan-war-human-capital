/* ================================================================
   Updated pooled summary statistics table (adds dummy row)
   Loads the three wave mainvars files, appends, and computes.
   ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global outdir "${proj}/paper/assets/tables"

use "${proj}/data/temp/census_1982_mainvars_v1.dta", clear
gen wave = 1
append using "${proj}/data/temp/census_1990_mainvars_v1.dta"
replace wave = 2 if missing(wave)
append using "${proj}/data/temp/census_2000_mainvars_v1.dta"
replace wave = 3 if missing(wave)

describe, short

* Identify birth year variable
capture confirm variable birth_i
if _rc != 0 {
    capture gen birth_i = floor(birthyr)
    if _rc != 0 {
        di as error "No birth year variable found"
        exit 1
    }
}

* Create post if missing
capture confirm variable post1940
if _rc != 0 gen post1940 = (birth_i >= 1940)

* Check d_count_high
capture confirm variable d_count_high
if _rc != 0 {
    di "d_count_high missing — rebuilding from martyr_count"
    * Need to merge treatment
    tempfile main
    save `main'
    use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
    gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
    replace martyr_count = 0 if missing(martyr_count)
    summ martyr_count, detail
    gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
    gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
    keep countyid_curr6 d_count_high ihs_rate
    tempfile treat
    save `treat'
    use `main', clear
    capture confirm variable countyid_curr6
    if _rc != 0 {
        di "No countyid_curr6 in pooled data — constructing from countyid"
        capture confirm variable countyid
        if _rc != 0 {
            di as error "Neither countyid_curr6 nor countyid exists"
            exit 1
        }
        tostring countyid, gen(countyid_curr6) format("%06.0f")
    }
    merge m:1 countyid_curr6 using `treat', keep(master match) nogen
}

* Build minority indicator if missing
capture confirm variable minority
if _rc != 0 {
    capture confirm variable race
    if _rc == 0 gen minority = (race != 1) if !missing(race)
    else {
        capture confirm variable ethniccn
        if _rc == 0 gen minority = (ethniccn != 1) if !missing(ethniccn)
        else gen minority = .
    }
}

* Winsorise eduy
summ eduy, detail
scalar p1 = r(p1)
scalar p99 = r(p99)
replace eduy = p1 if eduy < p1
replace eduy = p99 if eduy > p99 & !missing(eduy)

* Keep the regression sample
keep if inrange(birth_i, 1920, 1956)

di "Pooled N = " _N

*---- compute stats
summ eduy
local m_edu = r(mean)
local sd_edu = r(sd)
summ minority
local m_min = r(mean)
local sd_min = r(sd)
summ post1940
local m_post = r(mean)
local sd_post = r(sd)
summ ihs_rate if !missing(ihs_rate)
local m_ihsr = r(mean)
local sd_ihsr = r(sd)
summ d_count_high if !missing(d_count_high)
local m_dum = r(mean)
local sd_dum = r(sd)
count
local n_all = r(N)

forvalues w = 1/3 {
    summ eduy if wave == `w'
    local m_edu_`w' = r(mean)
    local sd_edu_`w' = r(sd)
    summ minority if wave == `w'
    local m_min_`w' = r(mean)
    local sd_min_`w' = r(sd)
    summ post1940 if wave == `w'
    local m_post_`w' = r(mean)
    local sd_post_`w' = r(sd)
    summ ihs_rate if wave == `w' & !missing(ihs_rate)
    local m_ihsr_`w' = r(mean)
    local sd_ihsr_`w' = r(sd)
    summ d_count_high if wave == `w' & !missing(d_count_high)
    local m_dum_`w' = r(mean)
    local sd_dum_`w' = r(sd)
    count if wave == `w'
    local n_`w' = r(N)
}

tempname fh
file open `fh' using "${outdir}/summary_statistics_pooled_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{cc}}" _n
file write `fh' "\toprule" _n
file write `fh' "                    &\multicolumn{2}{c}{1982}&\multicolumn{2}{c}{1990}&\multicolumn{2}{c}{2000}&\multicolumn{2}{c}{Pooled}\\" _n
file write `fh' "                    &        mean&          sd&        mean&          sd&        mean&          sd&        mean&          sd\\" _n
file write `fh' "\midrule" _n
file write `fh' "Years of education  &" %12.3f (`m_edu_1') "&     (" %5.3f (`sd_edu_1') ")&" %12.3f (`m_edu_2') "&     (" %5.3f (`sd_edu_2') ")&" %12.3f (`m_edu_3') "&     (" %5.3f (`sd_edu_3') ")&" %12.3f (`m_edu') "&     (" %5.3f (`sd_edu') ")\\" _n
file write `fh' "Minority            &" %12.3f (`m_min_1') "&     (" %5.3f (`sd_min_1') ")&" %12.3f (`m_min_2') "&     (" %5.3f (`sd_min_2') ")&" %12.3f (`m_min_3') "&     (" %5.3f (`sd_min_3') ")&" %12.3f (`m_min') "&     (" %5.3f (`sd_min') ")\\" _n
file write `fh' "Post-war cohort     &" %12.3f (`m_post_1') "&     (" %5.3f (`sd_post_1') ")&" %12.3f (`m_post_2') "&     (" %5.3f (`sd_post_2') ")&" %12.3f (`m_post_3') "&     (" %5.3f (`sd_post_3') ")&" %12.3f (`m_post') "&     (" %5.3f (`sd_post') ")\\" _n
file write `fh' "IHS(martyrs/100k)   &" %12.3f (`m_ihsr_1') "&     (" %5.3f (`sd_ihsr_1') ")&" %12.3f (`m_ihsr_2') "&     (" %5.3f (`sd_ihsr_2') ")&" %12.3f (`m_ihsr_3') "&     (" %5.3f (`sd_ihsr_3') ")&" %12.3f (`m_ihsr') "&     (" %5.3f (`sd_ihsr') ")\\" _n
file write `fh' "High martyr county  &" %12.3f (`m_dum_1') "&     (" %5.3f (`sd_dum_1') ")&" %12.3f (`m_dum_2') "&     (" %5.3f (`sd_dum_2') ")&" %12.3f (`m_dum_3') "&     (" %5.3f (`sd_dum_3') ")&" %12.3f (`m_dum') "&     (" %5.3f (`sd_dum') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Observations        &  " %12.0fc (`n_1') "&            &  " %12.0fc (`n_2') "&            &  " %12.0fc (`n_3') "&            &  " %12.0fc (`n_all') "&            \\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Summary stats pooled v1 (with dummy) written ==="
exit, clear
