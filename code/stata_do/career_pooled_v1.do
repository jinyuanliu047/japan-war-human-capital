* Pooled career / occupational sorting regression (1982+1990+2000)
* Outcome: indicator for each ISCO-88 major group (occisco 1-9), among employed.
* Spec mirrors baseline: absorb(county_num birth_i) + i.wave + minority, cluster county.
clear all
set more off
local master "/tmp/japan_war_local/data/temp/master.dta"

use occisco employed_occ birthyr wave county_num minority ihs_rate d_count_high ///
    using "`master'", clear

keep if inrange(birthyr,1920,1956)
capture confirm variable birth_i
if _rc gen birth_i = floor(birthyr)
gen post = (birth_i >= 1940)
gen byte drop_yr = (birth_i == 1939)

* employed with a valid ISCO major group
keep if employed_occ==1 & inrange(occisco,1,9)
keep if !missing(minority, ihs_rate, d_count_high, county_num)

tempname fh
file open `fh' using "/tmp/career_pooled_results.csv", write replace
file write `fh' "grp,share,b_ihs,se_ihs,p_ihs,n_ihs,b_bin,se_bin,p_bin,n_bin" _n

forvalues g = 1/9 {
    capture drop occ_g
    gen byte occ_g = (occisco==`g')
    quietly summarize occ_g
    local share = r(mean)

    quietly reghdfe occ_g c.post#c.ihs_rate minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local bi = _b[c.post#c.ihs_rate]
    local si = _se[c.post#c.ihs_rate]
    local pi = 2*ttail(e(df_r), abs(`bi'/`si'))
    local ni = e(N)

    quietly reghdfe occ_g c.post#c.d_count_high minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local bb = _b[c.post#c.d_count_high]
    local sb = _se[c.post#c.d_count_high]
    local pb = 2*ttail(e(df_r), abs(`bb'/`sb'))
    local nb = e(N)

    file write `fh' "`g',`share',`bi',`si',`pi',`ni',`bb',`sb',`pb',`nb'" _n
}
file close `fh'
di "DONE career_pooled"
