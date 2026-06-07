*******************************************************
* Multi-wave event-study spec scan (pop1953, unweighted)
* Waves: 1982 / 1990 / 2000
* Treatment: ln(1 + martyrs per 100k population in 1953)
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _one_scan
program define _one_scan, rclass
    syntax , ///
        WAVE(string) ///
        DATAFILE(string) ///
        SPEC(string) ///
        STARTYR(integer) ///
        BASEYR(integer) ///
        SAMPLELO(integer) ///
        SAMPLEHI(integer) ///
        LEADBIN(integer) ///
        LAGBIN(integer) ///
        [DROPYR(integer -999) ADDPROVFE(integer 0) SAVECOEF(integer 0)]

    use "`datafile'", clear
    keep if inrange(birthyr, `samplelo', `samplehi')
    keep if !missing(eduy_mean) & !missing(martyr_per100k_1953)
    if `dropyr' > -900 {
        drop if birthyr == `dropyr'
    }

    egen county_num = group(countyid_curr6)
    drop if missing(county_num)
    qui count
    return scalar n_cells = r(N)
    egen tag_county = tag(county_num)
    qui count if tag_county == 1
    return scalar n_counties = r(N)
    drop tag_county

    gen post = birthyr >= `startyr'
    local timefe "i.birthyr"
    if `addprovfe' == 1 {
        gen prov2 = real(substr(countyid_curr6, 1, 2))
        egen prov_birth = group(prov2 birthyr)
        local timefe "i.prov_birth"
    }

    capture noisily areg eduy_mean c.martyr_per100k_1953##ib0.post `timefe', ///
        absorb(county_num) vce(cluster county_num)
    if _rc == 0 {
        capture noisily lincom 1.post#c.martyr_per100k_1953
        if _rc == 0 {
            return scalar b_did = r(estimate)
            return scalar se_did = r(se)
            return scalar p_did = 2 * ttail(e(df_r), abs(r(estimate) / r(se)))
        }
        else {
            return scalar b_did = .
            return scalar se_did = .
            return scalar p_did = .
        }
    }
    else {
        return scalar b_did = .
        return scalar se_did = .
        return scalar p_did = .
    }

    gen rel = birthyr - `startyr'
    gen rel_bin = rel
    replace rel_bin = -`leadbin' if rel <= -`leadbin'
    replace rel_bin = `lagbin' if rel >= `lagbin'
    gen rel_idx = rel_bin + 50

    local base_rel = `baseyr' - `startyr'
    local base_idx = `base_rel' + 50

    capture noisily areg eduy_mean ib`base_idx'.rel_idx#c.martyr_per100k_1953 `timefe', ///
        absorb(county_num) vce(cluster county_num)
    if _rc != 0 {
        return scalar p_pre = .
        return scalar p_pre_near = .
        return scalar p_post = .
        exit
    }

    levelsof rel_bin, local(levels)
    local preterms
    local preterms_near
    local postterms
    foreach k of local levels {
        local kk = `k' + 50
        if `k' < `base_rel' {
            local preterms `preterms' `kk'.rel_idx#c.martyr_per100k_1953
            if inrange(`k', -5, -2) {
                local preterms_near `preterms_near' `kk'.rel_idx#c.martyr_per100k_1953
            }
        }
        if `k' >= 0 {
            local postterms `postterms' `kk'.rel_idx#c.martyr_per100k_1953
        }
    }

    scalar p_pre = .
    scalar p_pre_near = .
    scalar p_post = .

    capture noisily testparm `preterms'
    if _rc == 0 scalar p_pre = r(p)
    capture noisily testparm `preterms_near'
    if _rc == 0 scalar p_pre_near = r(p)
    capture noisily testparm `postterms'
    if _rc == 0 scalar p_post = r(p)

    return scalar p_pre = p_pre
    return scalar p_pre_near = p_pre_near
    return scalar p_post = p_post

    if `savecoef' == 1 {
        tempname ph
        tempfile coef_tmp
        postfile `ph' str6 wave str40 spec int birthyr int rel_bin ///
            double beta se lb ub ///
            int startyr baseyr sample_lo sample_hi ///
            using "`coef_tmp'", replace

        foreach k of local levels {
            local by = `startyr' + `k'
            if `k' == `base_rel' {
                post `ph' ("`wave'") ("`spec'") (`by') (`k') (0) (0) (0) (0) ///
                    (`startyr') (`baseyr') (`samplelo') (`samplehi')
            }
            else {
                local kk = `k' + 50
                capture quietly lincom `kk'.rel_idx#c.martyr_per100k_1953
                if _rc == 0 {
                    post `ph' ("`wave'") ("`spec'") (`by') (`k') ///
                        (r(estimate)) (r(se)) ///
                        (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se)) ///
                        (`startyr') (`baseyr') (`samplelo') (`samplehi')
                }
            }
        }
        postclose `ph'

        use "`coef_tmp'", clear
        sort birthyr
        local outstub = "eventstudy_coef_pop1953_ratio_`wave'_`spec'"
        export delimited using "${proj}/data/temp/`outstub'.csv", replace
        save "${proj}/data/temp/`outstub'.dta", replace
    }
end

tempname posth
tempfile out
postfile `posth' str6 wave str40 spec int startyr baseyr sample_lo sample_hi ///
    int leadbin lagbin dropyr addprovfe ///
    double b_did se_did p_did p_pre p_pre_near p_post ///
    long n_cells n_counties ///
    using "`out'", replace

*******************************************************
* 1982 wave
*******************************************************
local d82 "${proj}/data/temp/did_1982_county_birthyr_pop1953_unwt_v2.dta"

quietly _one_scan, wave("1982") datafile("`d82'") spec("post_w60_base45") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(-999) addprovfe(0) savecoef(1)
post `posth' ("1982") ("post_w60_base45") (1946) (1945) (1931) (1960) ///
    (8) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1982") datafile("`d82'") spec("post_w60_base46") ///
    startyr(1946) baseyr(1946) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(-999) addprovfe(0) savecoef(0)
post `posth' ("1982") ("post_w60_base46") (1946) (1946) (1931) (1960) ///
    (8) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1982") datafile("`d82'") spec("post_w60_drop1945") ///
    startyr(1946) baseyr(1944) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(1945) addprovfe(0) savecoef(0)
post `posth' ("1982") ("post_w60_drop1945") (1946) (1944) (1931) (1960) ///
    (8) (8) (1945) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1982") datafile("`d82'") spec("post_narrow40_60") ///
    startyr(1946) baseyr(1945) samplelo(1940) samplehi(1960) ///
    leadbin(5) lagbin(8) dropyr(-999) addprovfe(0) savecoef(0)
post `posth' ("1982") ("post_narrow40_60") (1946) (1945) (1940) (1960) ///
    (5) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1982") datafile("`d82'") spec("post_w65_base45") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1965) ///
    leadbin(10) lagbin(12) dropyr(-999) addprovfe(0) savecoef(1)
post `posth' ("1982") ("post_w65_base45") (1946) (1945) (1931) (1965) ///
    (10) (12) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1982") datafile("`d82'") spec("post_w60_base45_provfe") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(-999) addprovfe(1) savecoef(0)
post `posth' ("1982") ("post_w60_base45_provfe") (1946) (1945) (1931) (1960) ///
    (8) (8) (-999) (1) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1982") datafile("`d82'") spec("wartime_31_45") ///
    startyr(1937) baseyr(1936) samplelo(1931) samplehi(1945) ///
    leadbin(6) lagbin(8) dropyr(-999) addprovfe(0) savecoef(0)
post `posth' ("1982") ("wartime_31_45") (1937) (1936) (1931) (1945) ///
    (6) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

*******************************************************
* 1990 wave
*******************************************************
local d90 "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta"

quietly _one_scan, wave("1990") datafile("`d90'") spec("post_w60_base45") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(-999) addprovfe(0) savecoef(1)
post `posth' ("1990") ("post_w60_base45") (1946) (1945) (1931) (1960) ///
    (8) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1990") datafile("`d90'") spec("post_w60_base46") ///
    startyr(1946) baseyr(1946) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(-999) addprovfe(0) savecoef(0)
post `posth' ("1990") ("post_w60_base46") (1946) (1946) (1931) (1960) ///
    (8) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1990") datafile("`d90'") spec("post_w60_drop1945") ///
    startyr(1946) baseyr(1944) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(1945) addprovfe(0) savecoef(0)
post `posth' ("1990") ("post_w60_drop1945") (1946) (1944) (1931) (1960) ///
    (8) (8) (1945) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1990") datafile("`d90'") spec("post_narrow40_60") ///
    startyr(1946) baseyr(1945) samplelo(1940) samplehi(1960) ///
    leadbin(5) lagbin(8) dropyr(-999) addprovfe(0) savecoef(0)
post `posth' ("1990") ("post_narrow40_60") (1946) (1945) (1940) (1960) ///
    (5) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1990") datafile("`d90'") spec("post_w65_base45") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1965) ///
    leadbin(10) lagbin(12) dropyr(-999) addprovfe(0) savecoef(1)
post `posth' ("1990") ("post_w65_base45") (1946) (1945) (1931) (1965) ///
    (10) (12) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1990") datafile("`d90'") spec("post_w75_base45") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1975) ///
    leadbin(10) lagbin(20) dropyr(-999) addprovfe(0) savecoef(1)
post `posth' ("1990") ("post_w75_base45") (1946) (1945) (1931) (1975) ///
    (10) (20) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1990") datafile("`d90'") spec("post_w60_base45_provfe") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(-999) addprovfe(1) savecoef(0)
post `posth' ("1990") ("post_w60_base45_provfe") (1946) (1945) (1931) (1960) ///
    (8) (8) (-999) (1) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("1990") datafile("`d90'") spec("wartime_31_45") ///
    startyr(1937) baseyr(1936) samplelo(1931) samplehi(1945) ///
    leadbin(6) lagbin(8) dropyr(-999) addprovfe(0) savecoef(0)
post `posth' ("1990") ("wartime_31_45") (1937) (1936) (1931) (1945) ///
    (6) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

*******************************************************
* 2000 wave
*******************************************************
local d00 "${proj}/data/temp/did_2000_county_birthyr_pop1953_unwt_v2.dta"

quietly _one_scan, wave("2000") datafile("`d00'") spec("post_w60_base45") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(-999) addprovfe(0) savecoef(1)
post `posth' ("2000") ("post_w60_base45") (1946) (1945) (1931) (1960) ///
    (8) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("2000") datafile("`d00'") spec("post_w60_base46") ///
    startyr(1946) baseyr(1946) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(-999) addprovfe(0) savecoef(0)
post `posth' ("2000") ("post_w60_base46") (1946) (1946) (1931) (1960) ///
    (8) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("2000") datafile("`d00'") spec("post_w60_drop1945") ///
    startyr(1946) baseyr(1944) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(1945) addprovfe(0) savecoef(0)
post `posth' ("2000") ("post_w60_drop1945") (1946) (1944) (1931) (1960) ///
    (8) (8) (1945) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("2000") datafile("`d00'") spec("post_narrow40_60") ///
    startyr(1946) baseyr(1945) samplelo(1940) samplehi(1960) ///
    leadbin(5) lagbin(8) dropyr(-999) addprovfe(0) savecoef(0)
post `posth' ("2000") ("post_narrow40_60") (1946) (1945) (1940) (1960) ///
    (5) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("2000") datafile("`d00'") spec("post_w65_base45") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1965) ///
    leadbin(10) lagbin(12) dropyr(-999) addprovfe(0) savecoef(1)
post `posth' ("2000") ("post_w65_base45") (1946) (1945) (1931) (1965) ///
    (10) (12) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("2000") datafile("`d00'") spec("post_w75_base45") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1975) ///
    leadbin(10) lagbin(20) dropyr(-999) addprovfe(0) savecoef(1)
post `posth' ("2000") ("post_w75_base45") (1946) (1945) (1931) (1975) ///
    (10) (20) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("2000") datafile("`d00'") spec("post_w60_base45_provfe") ///
    startyr(1946) baseyr(1945) samplelo(1931) samplehi(1960) ///
    leadbin(8) lagbin(8) dropyr(-999) addprovfe(1) savecoef(0)
post `posth' ("2000") ("post_w60_base45_provfe") (1946) (1945) (1931) (1960) ///
    (8) (8) (-999) (1) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

quietly _one_scan, wave("2000") datafile("`d00'") spec("wartime_31_45") ///
    startyr(1937) baseyr(1936) samplelo(1931) samplehi(1945) ///
    leadbin(6) lagbin(8) dropyr(-999) addprovfe(0) savecoef(0)
post `posth' ("2000") ("wartime_31_45") (1937) (1936) (1931) (1945) ///
    (6) (8) (-999) (0) ///
    (r(b_did)) (r(se_did)) (r(p_did)) (r(p_pre)) (r(p_pre_near)) (r(p_post)) ///
    (r(n_cells)) (r(n_counties))

postclose `posth'

use "`out'", clear
sort wave spec
order wave spec startyr baseyr sample_lo sample_hi leadbin lagbin dropyr addprovfe ///
    b_did se_did p_did p_pre p_pre_near p_post n_cells n_counties

export delimited using "${proj}/data/temp/eventstudy_spec_scan_pop1953_ratio_multiwave_v1.csv", replace
save "${proj}/data/temp/eventstudy_spec_scan_pop1953_ratio_multiwave_v1.dta", replace

list, abbrev(30)
