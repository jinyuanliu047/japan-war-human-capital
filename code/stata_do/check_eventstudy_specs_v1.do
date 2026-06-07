*******************************************************
* Compare event-study spec diagnostics (v1)
* Output: pre-trend and post joint test p-values
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _es_diag
program define _es_diag, rclass
    syntax , ///
        STARTYR(integer) ///
        SAMPLELO(integer) ///
        SAMPLEHI(integer) ///
        LEADBIN(integer) ///
        LAGBIN(integer) ///
        TREATVAR(name) ///
        POSTLO(integer) ///
        POSTHI(integer) ///
        ADDPROVFE(integer)

    use "${proj}/data/temp/did_1982_county_birthyr_martyr_hybrid_v3.dta", clear
    keep if inrange(birthyr, `samplelo', `samplehi')
    keep if strict_share_wt >= 0.8

    gen rel = birthyr - `startyr'
    gen rel_bin = rel
    replace rel_bin = -`leadbin' if rel <= -`leadbin'
    replace rel_bin = `lagbin' if rel >= `lagbin'
    gen rel_idx = rel_bin + 20

    gen post = inrange(birthyr, `postlo', `posthi')

    local absf "countyid_curr6 birthyr"
    if `addprovfe' == 1 {
        gen prov2 = real(substr(countyid_curr6,1,2))
        egen prov_birth = group(prov2 birthyr)
        local absf "countyid_curr6 prov_birth"
    }

    fvset base 19 rel_idx
    reghdfe eduy_wmean i.rel_idx##c.`treatvar' [aw=wt_sum], absorb(`absf') vce(cluster countyid_curr6)

    levelsof rel_bin, local(levels)
    local preterms
    local postterms
    foreach k of local levels {
        local kk = `k' + 20
        if `k' <= -2 local preterms `preterms' `kk'.rel_idx#c.`treatvar'
        if `k' >= 0  local postterms `postterms' `kk'.rel_idx#c.`treatvar'
    }
    testparm `preterms'
    return scalar p_pre = r(p)
    testparm `postterms'
    return scalar p_post = r(p)

    * Corresponding pooled DID in same sample.
    reghdfe eduy_wmean c.`treatvar'##i.post [aw=wt_sum], absorb(`absf') vce(cluster countyid_curr6)
    lincom 1.post#c.`treatvar'
    return scalar b_did = r(estimate)
    return scalar se_did = r(se)
    return scalar p_did = 2 * ttail(e(df_r), abs(r(estimate)/r(se)))
end

tempname posth
tempfile out
postfile `posth' str24 design str20 spec int addprovfe int startyr int lo int hi ///
    double p_pre p_post b_did se_did p_did using "`out'", replace

* 1) School-entry wide (1928-1960), baseline FE
quietly _es_diag, startyr(1943) samplelo(1928) samplehi(1960) leadbin(8) lagbin(8) ///
    treatvar(ln_martyr_native_count) postlo(1943) posthi(1960) addprovfe(0)
post `posth' ("schoolentry") ("wide") (0) (1943) (1928) (1960) ///
    (r(p_pre)) (r(p_post)) (r(b_did)) (r(se_did)) (r(p_did))

* 2) School-entry short (1938-1955), baseline FE
quietly _es_diag, startyr(1943) samplelo(1938) samplehi(1955) leadbin(5) lagbin(6) ///
    treatvar(ln_martyr_native_count) postlo(1943) posthi(1955) addprovfe(0)
post `posth' ("schoolentry") ("short") (0) (1943) (1938) (1955) ///
    (r(p_pre)) (r(p_post)) (r(b_did)) (r(se_did)) (r(p_did))

* 3) School-entry wide + province-by-birth FE
quietly _es_diag, startyr(1943) samplelo(1928) samplehi(1960) leadbin(8) lagbin(8) ///
    treatvar(ln_martyr_native_count) postlo(1943) posthi(1960) addprovfe(1)
post `posth' ("schoolentry") ("wide_provFE") (1) (1943) (1928) (1960) ///
    (r(p_pre)) (r(p_post)) (r(b_did)) (r(se_did)) (r(p_did))

* 4) Birth wide (1931-1960), baseline FE
quietly _es_diag, startyr(1946) samplelo(1931) samplehi(1960) leadbin(8) lagbin(8) ///
    treatvar(ln_martyr_native_count) postlo(1946) posthi(1960) addprovfe(0)
post `posth' ("birth") ("wide") (0) (1946) (1931) (1960) ///
    (r(p_pre)) (r(p_post)) (r(b_did)) (r(se_did)) (r(p_did))

* 5) Birth short (1940-1955), baseline FE
quietly _es_diag, startyr(1946) samplelo(1940) samplehi(1955) leadbin(5) lagbin(6) ///
    treatvar(ln_martyr_native_count) postlo(1946) posthi(1955) addprovfe(0)
post `posth' ("birth") ("short") (0) (1946) (1940) (1955) ///
    (r(p_pre)) (r(p_post)) (r(b_did)) (r(se_did)) (r(p_did))

* 6) Birth wide + province-by-birth FE
quietly _es_diag, startyr(1946) samplelo(1931) samplehi(1960) leadbin(8) lagbin(8) ///
    treatvar(ln_martyr_native_count) postlo(1946) posthi(1960) addprovfe(1)
post `posth' ("birth") ("wide_provFE") (1) (1946) (1931) (1960) ///
    (r(p_pre)) (r(p_post)) (r(b_did)) (r(se_did)) (r(p_did))

postclose `posth'
use "`out'", clear
sort design spec
export delimited using "${proj}/data/temp/eventstudy_spec_checks_v1.csv", replace
save "${proj}/data/temp/eventstudy_spec_checks_v1.dta", replace
list, abbrev(20)
