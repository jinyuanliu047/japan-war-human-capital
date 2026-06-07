*******************************************************
* Event-study check: base 1939, treated cohorts >=1940
* Waves: 1982 / 1990 / 2000
* Sample window: 1931-1960
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _one_run
program define _one_run, rclass
    syntax , WAVE(string) DATAFILE(string)

    use "`datafile'", clear
    keep if inrange(birthyr, 1931, 1960)
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="000000"

    egen county_num = group(countyid_curr6)
    gen post = birthyr >= 1940

    quietly areg eduy_mean c.ln_martyr_per100k_1953##ib0.post i.birthyr, ///
        absorb(county_num) vce(cluster county_num)
    quietly lincom 1.post#c.ln_martyr_per100k_1953
    return scalar b_did = r(estimate)
    return scalar se_did = r(se)
    return scalar p_did = 2 * ttail(e(df_r), abs(r(estimate) / r(se)))

    gen rel = birthyr - 1940
    gen rel_bin = rel
    replace rel_bin = -8 if rel <= -8
    replace rel_bin = 8 if rel >= 8
    gen rel_idx = rel_bin + 50

    * base cohort = 1939 => rel=-1 => idx=49
    quietly areg eduy_mean ib49.rel_idx#c.ln_martyr_per100k_1953 i.birthyr, ///
        absorb(county_num) vce(cluster county_num)

    levelsof rel_bin, local(levels)
    local preterms
    local postterms
    foreach k of local levels {
        local kk = `k' + 50
        if `k' <= -2 local preterms `preterms' `kk'.rel_idx#c.ln_martyr_per100k_1953
        if `k' >= 0  local postterms `postterms' `kk'.rel_idx#c.ln_martyr_per100k_1953
    }
    quietly testparm `preterms'
    return scalar p_pre = r(p)
    quietly testparm `postterms'
    return scalar p_post = r(p)

    tempname ph
    tempfile coef
    postfile `ph' str6 wave int birthyr int rel_bin ///
        double beta se lb ub ///
        int startyr baseyr sample_lo sample_hi ///
        using "`coef'", replace

    foreach k of local levels {
        local yy = 1940 + `k'
        if `k' == -1 {
            post `ph' ("`wave'") (`yy') (`k') (0) (0) (0) (0) (1940) (1939) (1931) (1960)
        }
        else {
            local kk = `k' + 50
            capture quietly lincom `kk'.rel_idx#c.ln_martyr_per100k_1953
            if _rc == 0 {
                post `ph' ("`wave'") (`yy') (`k') ///
                    (r(estimate)) (r(se)) ///
                    (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se)) ///
                    (1940) (1939) (1931) (1960)
            }
        }
    }
    postclose `ph'

    use "`coef'", clear
    sort birthyr
    export delimited using "${proj}/data/temp/eventstudy_coef_base1939_start1940_main_`wave'_v1.csv", replace
    save "${proj}/data/temp/eventstudy_coef_base1939_start1940_main_`wave'_v1.dta", replace
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
    keep if inrange(birthyr, 1931, 1960)
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="000000"
    quietly count
    scalar n_cells = r(N)
    egen county_num = group(countyid_curr6)
    egen tag_county = tag(county_num)
    quietly count if tag_county==1
    scalar n_counties = r(N)

    post `posth' ("`w'") (1940) (1939) (1931) (1960) ///
        (`b_did') (`se_did') (`p_did') (`p_pre') (`p_post') ///
        (n_cells) (n_counties)
}

postclose `posth'
use "`out'", clear
sort wave
export delimited using "${proj}/data/temp/eventstudy_base1939_start1940_main_summary_v1.csv", replace
save "${proj}/data/temp/eventstudy_base1939_start1940_main_summary_v1.dta", replace
list, clean noobs

