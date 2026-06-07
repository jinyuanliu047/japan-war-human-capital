*******************************************************
* Event-study (long window): base=1931, treated>=1940
* Waves: 1982 / 1990 / 2000
* Sample window: 1920-1975
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _one_run
program define _one_run, rclass
    syntax , WAVE(string) DATAFILE(string)

    use "`datafile'", clear
    keep if inrange(birthyr, 1920, 1975)
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="000000"

    gen birth_i = floor(birthyr)
    egen county_num = group(countyid_curr6)
    gen post = birth_i >= 1940

    quietly count if birth_i == 1931
    if r(N) == 0 {
        di as error "Base cohort 1931 not found for wave `wave'."
        exit 459
    }

    * Pooled DID with post=1940+.
    quietly areg eduy_mean c.ln_martyr_per100k_1953##ib0.post i.birth_i, ///
        absorb(county_num) vce(cluster county_num)
    quietly lincom 1.post#c.ln_martyr_per100k_1953
    return scalar b_did = r(estimate)
    return scalar se_did = r(se)
    return scalar p_did = 2 * ttail(e(df_r), abs(r(estimate) / r(se)))

    * Event-study relative to base cohort 1931.
    quietly areg eduy_mean ib1931.birth_i#c.ln_martyr_per100k_1953 i.birth_i, ///
        absorb(county_num) vce(cluster county_num)

    levelsof birth_i, local(years)
    local preterms
    local postterms
    foreach y of local years {
        if `y' != 1931 {
            if `y' <= 1939 local preterms `preterms' `y'.birth_i#c.ln_martyr_per100k_1953
            if `y' >= 1940 local postterms `postterms' `y'.birth_i#c.ln_martyr_per100k_1953
        }
    }

    scalar p_pre = .
    scalar p_post = .
    capture noisily testparm `preterms'
    if _rc == 0 scalar p_pre = r(p)
    capture noisily testparm `postterms'
    if _rc == 0 scalar p_post = r(p)

    return scalar p_pre = p_pre
    return scalar p_post = p_post

    tempname ph
    tempfile coef
    postfile `ph' str6 wave int birthyr ///
        double beta se lb ub ///
        int startyr baseyr sample_lo sample_hi ///
        using "`coef'", replace

    foreach y of local years {
        if `y' == 1931 {
            post `ph' ("`wave'") (`y') (0) (0) (0) (0) (1940) (1931) (1920) (1975)
        }
        else {
            capture quietly lincom `y'.birth_i#c.ln_martyr_per100k_1953
            if _rc == 0 {
                post `ph' ("`wave'") (`y') ///
                    (r(estimate)) (r(se)) ///
                    (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se)) ///
                    (1940) (1931) (1920) (1975)
            }
        }
    }
    postclose `ph'

    use "`coef'", clear
    sort birthyr
    export delimited using "${proj}/data/temp/eventstudy_coef_base1931_start1940_long_`wave'_v1.csv", replace
    save "${proj}/data/temp/eventstudy_coef_base1931_start1940_long_`wave'_v1.dta", replace
end

tempname posth
tempfile out
postfile `posth' str6 wave int startyr baseyr sample_lo sample_hi ///
    double b_did se_did p_did p_pre p_post long n_cells n_counties ///
    using "`out'", replace

foreach w in 1982 1990 2000 {
    local d "${proj}/data/temp/did_`w'_county_birthyr_pop1953_unwt_v2.dta"
    quietly _one_run, wave("`w'") datafile("`d'")

    local b_did = r(b_did)
    local se_did = r(se_did)
    local p_did = r(p_did)
    local p_pre = r(p_pre)
    local p_post = r(p_post)

    use "`d'", clear
    keep if inrange(birthyr, 1920, 1975)
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="000000"
    quietly count
    scalar n_cells = r(N)
    egen county_num = group(countyid_curr6)
    egen tag_county = tag(county_num)
    quietly count if tag_county==1
    scalar n_counties = r(N)

    post `posth' ("`w'") (1940) (1931) (1920) (1975) ///
        (`b_did') (`se_did') (`p_did') (`p_pre') (`p_post') ///
        (n_cells) (n_counties)
}

postclose `posth'
use "`out'", clear
sort wave
export delimited using "${proj}/data/temp/eventstudy_base1931_start1940_long_summary_v1.csv", replace
save "${proj}/data/temp/eventstudy_base1931_start1940_long_summary_v1.dta", replace
list, clean noobs

