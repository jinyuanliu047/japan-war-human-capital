*******************************************************
* Cohort-specific treatment coefficients by wave (RATIO)
* Drop cohort 1939
* Treated cohorts: 1940+
* Wave-specific end year (age-22 rule):
*   1982 -> 1960, 1990 -> 1968, 2000 -> 1978
* Intensity variable: martyr_per100k_1953 (NOT ln)
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _one_wave
program define _one_wave, rclass
    syntax , WAVE(string) DATAFILE(string) HI(integer)

    use "`datafile'", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr) == 1939
    keep if !missing(eduy_mean) & !missing(martyr_per100k_1953)
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

    quietly areg eduy_mean c.martyr_per100k_1953##ib0.post i.birth_i, ///
        absorb(county_num) vce(cluster county_num)
    quietly lincom 1.post#c.martyr_per100k_1953
    return scalar b_did = r(estimate)
    return scalar se_did = r(se)
    return scalar p_did = 2 * ttail(e(df_r), abs(r(estimate) / r(se)))

    * Base for identification is 1938 (1939 dropped).
    quietly areg eduy_mean c.martyr_per100k_1953##ib1938.birth_i i.birth_i, ///
        absorb(county_num) vce(cluster county_num)

    levelsof birth_i, local(years)

    local preterms
    local postterms
    foreach y of local years {
        if `y' <= 1937 {
            local preterms `preterms' `y'.birth_i#c.martyr_per100k_1953
        }
        if `y' >= 1940 {
            local postterms `postterms' `y'.birth_i#c.martyr_per100k_1953
        }
    }

    scalar p_pre_equal1938 = .
    scalar p_post_equal1938 = .
    capture noisily testparm `preterms'
    if _rc == 0 scalar p_pre_equal1938 = r(p)
    capture noisily testparm `postterms'
    if _rc == 0 scalar p_post_equal1938 = r(p)
    return scalar p_pre_equal1938 = p_pre_equal1938
    return scalar p_post_equal1938 = p_post_equal1938

    tempname ph
    tempfile coef
    postfile `ph' str6 wave int birthyr ///
        double coefficient se lb ub p_coef ///
        int startyr dropped sample_lo sample_hi ///
        using "`coef'", replace

    foreach y of local years {
        if `y' == 1938 {
            capture quietly lincom c.martyr_per100k_1953
        }
        else {
            capture quietly lincom c.martyr_per100k_1953 + `y'.birth_i#c.martyr_per100k_1953
        }
        if _rc == 0 {
            local p = 2 * ttail(e(df_r), abs(r(estimate) / r(se)))
            post `ph' ("`wave'") (`y') ///
                (r(estimate)) (r(se)) ///
                (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se)) ///
                (`p') ///
                (1940) (1939) (1920) (`hi')
        }
    }
    postclose `ph'

    use "`coef'", clear
    sort birthyr
    export delimited using "${proj}/data/temp/eventstudy_coefficient_drop1939_start1940_`wave'_ratio_v1.csv", replace
    save "${proj}/data/temp/eventstudy_coefficient_drop1939_start1940_`wave'_ratio_v1.dta", replace
end

tempname posth
tempfile out
postfile `posth' str6 wave int startyr dropped sample_lo sample_hi ///
    double b_did se_did p_did p_pre_equal1938 p_post_equal1938 ///
    long n_cells n_counties ///
    using "`out'", replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'" == "1990" local hi = 1968
    if "`w'" == "2000" local hi = 1978

    local d "${proj}/data/temp/did_`w'_county_birthyr_pop1953_unwt_v2.dta"
    quietly _one_wave, wave("`w'") datafile("`d'") hi(`hi')
    post `posth' ("`w'") (1940) (1939) (1920) (`hi') ///
        (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre_equal1938)) (r(p_post_equal1938)) ///
        (r(n_cells)) (r(n_counties))
}

postclose `posth'
use "`out'", clear
sort wave
export delimited using "${proj}/data/temp/eventstudy_coefficient_drop1939_start1940_wavecut_summary_ratio_v1.csv", replace
save "${proj}/data/temp/eventstudy_coefficient_drop1939_start1940_wavecut_summary_ratio_v1.dta", replace
list, clean noobs
