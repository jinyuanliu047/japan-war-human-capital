*******************************************************
* Absolute cohort-specific treatment effect (vs 0)
* Setting: base cohort marker at 1931, treated cohorts >= 1940
* Sample window: 1920-1975
* Output betas are absolute slopes (not normalized to base=0 in plot)
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _one_abs
program define _one_abs, rclass
    syntax , WAVE(string) DATAFILE(string)

    use "`datafile'", clear
    keep if inrange(birthyr, 1920, 1975)
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="000000"

    gen birth_i = floor(birthyr)
    egen county_num = group(countyid_curr6)
    gen post = birth_i >= 1940

    quietly count
    return scalar n_cells = r(N)
    egen tag_county = tag(county_num)
    quietly count if tag_county==1
    return scalar n_counties = r(N)
    drop tag_county

    * DID for reference.
    quietly areg eduy_mean c.ln_martyr_per100k_1953##ib0.post i.birth_i, ///
        absorb(county_num) vce(cluster county_num)
    quietly lincom 1.post#c.ln_martyr_per100k_1953
    return scalar b_did = r(estimate)
    return scalar se_did = r(se)
    return scalar p_did = 2 * ttail(e(df_r), abs(r(estimate) / r(se)))

    * Cohort-specific absolute slope:
    * beta_y = d(eduy)/d(treat) at cohort y.
    quietly areg eduy_mean c.ln_martyr_per100k_1953##ib1931.birth_i i.birth_i, ///
        absorb(county_num) vce(cluster county_num)

    levelsof birth_i, local(years)

    * Pre-trend equality (all pre years equal to base-year slope).
    local preterms
    foreach y of local years {
        if `y' <= 1939 & `y' != 1931 {
            local preterms `preterms' `y'.birth_i#c.ln_martyr_per100k_1953
        }
    }
    scalar p_pre_equalbase = .
    capture noisily testparm `preterms'
    if _rc == 0 scalar p_pre_equalbase = r(p)
    return scalar p_pre_equalbase = p_pre_equalbase

    tempname ph
    tempfile coef
    postfile `ph' str6 wave int birthyr ///
        double beta se lb ub p_beta ///
        int startyr baseyr sample_lo sample_hi ///
        using "`coef'", replace

    foreach y of local years {
        if `y' == 1931 {
            capture quietly lincom c.ln_martyr_per100k_1953
        }
        else {
            capture quietly lincom c.ln_martyr_per100k_1953 + `y'.birth_i#c.ln_martyr_per100k_1953
        }
        if _rc == 0 {
            local p = 2 * ttail(e(df_r), abs(r(estimate) / r(se)))
            post `ph' ("`wave'") (`y') ///
                (r(estimate)) (r(se)) ///
                (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se)) ///
                (`p') ///
                (1940) (1931) (1920) (1975)
        }
    }
    postclose `ph'

    use "`coef'", clear
    sort birthyr
    export delimited using "${proj}/data/temp/eventstudy_abszero_base1931_start1940_long_`wave'_v1.csv", replace
    save "${proj}/data/temp/eventstudy_abszero_base1931_start1940_long_`wave'_v1.dta", replace
end

tempname posth
tempfile out
postfile `posth' str6 wave int startyr baseyr sample_lo sample_hi ///
    double b_did se_did p_did p_pre_equalbase long n_cells n_counties ///
    using "`out'", replace

foreach w in 1982 1990 2000 {
    local d "${proj}/data/temp/did_`w'_county_birthyr_pop1953_unwt_v2.dta"
    quietly _one_abs, wave("`w'") datafile("`d'")
    post `posth' ("`w'") (1940) (1931) (1920) (1975) ///
        (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre_equalbase)) ///
        (r(n_cells)) (r(n_counties))
}

postclose `posth'
use "`out'", clear
sort wave
export delimited using "${proj}/data/temp/eventstudy_abszero_base1931_start1940_long_summary_v1.csv", replace
save "${proj}/data/temp/eventstudy_abszero_base1931_start1940_long_summary_v1.dta", replace
list, clean noobs

