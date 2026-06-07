*******************************************************
* Postwar-main event-study coefficient export (v4)
* Output is consumed by Python plotting script.
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _make_es_post_v4
program define _make_es_post_v4
    syntax , ///
        SAMPLECOND(string) ///
        BASEYR(integer) ///
        TSTART(integer) ///
        TEND(integer) ///
        OUTSTUB(string)

    use "${proj}/data/temp/did_1982_county_birthyr_martyr_hybrid_v3.dta", clear
    keep if `samplecond'
    keep if strict_share_wt >= 0.8

    reghdfe eduy_wmean ib`baseyr'.birthyr##c.ln_martyr_native_count [aw=wt_sum], ///
        absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)

    tempfile coef
    tempname posth
    postfile `posth' int birthyr double beta se lb ub int baseyr tstart tend using "`coef'", replace

    levelsof birthyr, local(years)
    foreach y of local years {
        if `y' == `baseyr' {
            post `posth' (`y') (0) (0) (0) (0) (`baseyr') (`tstart') (`tend')
        }
        else {
            capture quietly lincom `y'.birthyr#c.ln_martyr_native_count
            if _rc == 0 {
                post `posth' (`y') (r(estimate)) (r(se)) (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se)) (`baseyr') (`tstart') (`tend')
            }
        }
    }
    postclose `posth'

    use "`coef'", clear
    sort birthyr
    export delimited using "${proj}/data/temp/`outstub'.csv", replace
    save "${proj}/data/temp/`outstub'.dta", replace
end

* A. Postwar birth (wide), pre-period base
* sample: 1931-1960 ; treated: 1946-1960 ; base: 1945
_make_es_post_v4, ///
    samplecond("inrange(birthyr,1931,1960)") ///
    baseyr(1945) ///
    tstart(1946) ///
    tend(1960) ///
    outstub("es_postwar_birth_wide_prebase_v4")

* B. Postwar school-entry (wide), pre-period base
* sample: 1928-1960 ; treated: 1943-1960 ; base: 1942
_make_es_post_v4, ///
    samplecond("inrange(birthyr,1928,1960)") ///
    baseyr(1942) ///
    tstart(1943) ///
    tend(1960) ///
    outstub("es_postwar_schentry_wide_prebase_v4")

* C. Postwar birth (wide), current-period base
* sample: 1931-1960 ; treated: 1946-1960 ; base: 1946
_make_es_post_v4, ///
    samplecond("inrange(birthyr,1931,1960)") ///
    baseyr(1946) ///
    tstart(1946) ///
    tend(1960) ///
    outstub("es_postwar_birth_wide_currentbase_v4")

* D. Postwar school-entry (wide), current-period base
* sample: 1928-1960 ; treated: 1943-1960 ; base: 1943
_make_es_post_v4, ///
    samplecond("inrange(birthyr,1928,1960)") ///
    baseyr(1943) ///
    tstart(1943) ///
    tend(1960) ///
    outstub("es_postwar_schentry_wide_currentbase_v4")

