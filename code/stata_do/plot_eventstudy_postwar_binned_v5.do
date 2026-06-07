*******************************************************
* Postwar event-study (binned, base t=-1) v5
* Goal: stabilize noisy year-by-year ES and test pre-trends.
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _run_es_binned
program define _run_es_binned
    syntax , ///
        STARTYR(integer) ///
        SAMPLELO(integer) ///
        SAMPLEHI(integer) ///
        LEADBIN(integer) ///
        LAGBIN(integer) ///
        TREATVAR(name) ///
        OUTSTUB(string) ///
        TITLETXT(string)

    use "${proj}/data/temp/did_1982_county_birthyr_martyr_hybrid_v3.dta", clear
    keep if inrange(birthyr, `samplelo', `samplehi')
    keep if strict_share_wt >= 0.8

    gen rel = birthyr - `startyr'
    gen rel_bin = rel
    replace rel_bin = -`leadbin' if rel <= -`leadbin'
    replace rel_bin = `lagbin' if rel >= `lagbin'
    gen rel_idx = rel_bin + 20

    fvset base 19 rel_idx
    reghdfe eduy_wmean i.rel_idx##c.`treatvar' [aw=wt_sum], ///
        absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)

    * Joint pre-trend test: all leads <= -2.
    levelsof rel_bin, local(levels)
    local preterms
    local postterms
    foreach k of local levels {
        local kk = `k' + 20
        if `k' <= -2 {
            local preterms `preterms' `kk'.rel_idx#c.`treatvar'
        }
        if `k' >= 0 {
            local postterms `postterms' `kk'.rel_idx#c.`treatvar'
        }
    }
    capture noisily testparm `preterms'
    scalar p_pre = .
    if _rc == 0 scalar p_pre = r(p)

    capture noisily testparm `postterms'
    scalar p_post = .
    if _rc == 0 scalar p_post = r(p)

    tempfile coef
    tempname posth
    postfile `posth' int rel_bin double beta se lb ub double p_pre p_post using "`coef'", replace

    foreach k of local levels {
        if `k' == -1 {
            post `posth' (`k') (0) (0) (0) (0) (p_pre) (p_post)
        }
        else {
            local kk = `k' + 20
            capture quietly lincom `kk'.rel_idx#c.`treatvar'
            if _rc == 0 {
                post `posth' (`k') (r(estimate)) (r(se)) (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se)) (p_pre) (p_post)
            }
        }
    }
    postclose `posth'

    use "`coef'", clear
    sort rel_bin
    export delimited using "${proj}/data/temp/`outstub'.csv", replace
    save "${proj}/data/temp/`outstub'.dta", replace

    twoway ///
        (rarea ub lb rel_bin if rel_bin>=0, color(orange%16) lcolor(none)) ///
        (rcap ub lb rel_bin, lcolor(navy%60) lwidth(vthin)) ///
        (line beta rel_bin, lcolor(navy) lwidth(medthin)) ///
        (scatter beta rel_bin, mcolor(navy) msymbol(circle) msize(vsmall)) ///
        (scatter beta rel_bin if rel_bin==-1, mcolor(maroon) msymbol(diamond) msize(medlarge)), ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        xline(-1, lcolor(black) lpattern(shortdash)) ///
        xline(0, lcolor(maroon) lpattern(shortdash)) ///
        xtitle("Event time (t = birth year - `startyr')") ///
        ytitle("Effect relative to t=-1") ///
        title("`titletxt'", size(medsmall)) ///
        subtitle("Base = t-1; binned tails: <=-`leadbin' and >=`lagbin'", size(small)) ///
        note("Pre-trend joint p = " + string(p_pre, "%5.3f") + " ; Post joint p = " + string(p_post, "%5.3f"), size(vsmall)) ///
        legend(off) ///
        graphregion(color(white))

    graph export "${proj}/result/figure/`outstub'.png", replace width(2600)
end

* A) School-entry postwar (wide): treatment starts 1943
_run_es_binned, ///
    startyr(1943) ///
    samplelo(1928) ///
    samplehi(1960) ///
    leadbin(8) ///
    lagbin(8) ///
    treatvar(ln_martyr_native_count) ///
    outstub("eventstudy_postwar_schoolentry_binned_v5") ///
    titletxt("Postwar School-entry ES (binned)")

* B) Postwar birth (wide): treatment starts 1946
_run_es_binned, ///
    startyr(1946) ///
    samplelo(1931) ///
    samplehi(1960) ///
    leadbin(8) ///
    lagbin(8) ///
    treatvar(ln_martyr_native_count) ///
    outstub("eventstudy_postwar_birth_binned_v5") ///
    titletxt("Postwar Birth ES (binned)")
