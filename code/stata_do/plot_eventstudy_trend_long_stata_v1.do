*******************************************************
* Long-horizon event-study trend plots (Stata only)
* - No cohort dropped
* - Longer pre-period window
* - Base cohort: 1945 (t=-1 relative to 1946 start)
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _es_plot_long
program define _es_plot_long, rclass
    syntax , ///
        WAVE(string) ///
        LO(integer) ///
        HI(integer) ///
        COLOR(string) ///
        GNAME(name) ///
        TITLE(string asis)

    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, `lo', `hi')
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)

    egen county_num = group(countyid_curr6)
    gen rel = birthyr - 1946
    gen rel_idx = rel + 60

    * Base: t=-1 (birthyr=1945 -> rel_idx=59)
    quietly areg eduy_mean ib59.rel_idx#c.ln_martyr_per100k_1953 i.birthyr, ///
        absorb(county_num) vce(cluster county_num)

    levelsof rel, local(levels)
    local preterms
    local postterms
    foreach k of local levels {
        local kk = `k' + 60
        if `k' <= -2 local preterms `preterms' `kk'.rel_idx#c.ln_martyr_per100k_1953
        if `k' >= 0  local postterms `postterms' `kk'.rel_idx#c.ln_martyr_per100k_1953
    }

    scalar p_pre = .
    scalar p_post = .
    capture noisily testparm `preterms'
    if _rc == 0 scalar p_pre = r(p)
    capture noisily testparm `postterms'
    if _rc == 0 scalar p_post = r(p)

    tempname ph
    tempfile coef
    postfile `ph' int birthyr int rel ///
        double beta se lb ub double p_pre p_post ///
        using "`coef'", replace

    foreach k of local levels {
        local yy = 1946 + `k'
        if `k' == -1 {
            post `ph' (`yy') (`k') (0) (0) (0) (0) (p_pre) (p_post)
        }
        else {
            local kk = `k' + 60
            capture quietly lincom `kk'.rel_idx#c.ln_martyr_per100k_1953
            if _rc == 0 {
                post `ph' (`yy') (`k') ///
                    (r(estimate)) (r(se)) ///
                    (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se)) ///
                    (p_pre) (p_post)
            }
        }
    }
    postclose `ph'

    use "`coef'", clear
    sort birthyr
    export delimited using "${proj}/data/temp/eventstudy_trend_long_stata_`wave'_v1.csv", replace
    save "${proj}/data/temp/eventstudy_trend_long_stata_`wave'_v1.dta", replace

    twoway ///
        (rarea ub lb birthyr if birthyr >= 1946, color(`color'%16) lcolor(none)) ///
        (line beta birthyr, lcolor(`color') lwidth(medthick)) ///
        (scatter beta birthyr, mcolor(`color') msymbol(circle) msize(vsmall)), ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        xline(1945, lcolor(black) lpattern(shortdash)) ///
        xline(1946, lcolor(maroon) lpattern(shortdash)) ///
        xtitle("Birth cohort") ///
        ytitle("Relative effect (base cohort = 1945)") ///
        title(`"`title'"', size(medsmall)) ///
        subtitle("Long window `lo'-`hi' (no cohort dropped)", size(vsmall)) ///
        note("Pre-joint p = " + string(p_pre, "%6.4f") + " ; Post-joint p = " + string(p_post, "%6.4f"), size(vsmall)) ///
        legend(off) ///
        graphregion(color(white)) ///
        name(`gname', replace)

    return scalar p_pre = p_pre
    return scalar p_post = p_post
end

tempname sh
tempfile sout
postfile `sh' str6 wave int sample_lo sample_hi double p_pre p_post using "`sout'", replace

quietly _es_plot_long, wave("1982") lo(1920) hi(1975) color(navy) gname(g82) title("A. Census 1982")
post `sh' ("1982") (1920) (1975) (r(p_pre)) (r(p_post))

quietly _es_plot_long, wave("1990") lo(1920) hi(1975) color(orange_red) gname(g90) title("B. Census 1990")
post `sh' ("1990") (1920) (1975) (r(p_pre)) (r(p_post))

quietly _es_plot_long, wave("2000") lo(1920) hi(1975) color(forest_green) gname(g00) title("C. Census 2000")
post `sh' ("2000") (1920) (1975) (r(p_pre)) (r(p_post))

postclose `sh'
use "`sout'", clear
sort wave
export delimited using "${proj}/data/temp/eventstudy_trend_long_stata_summary_v1.csv", replace
save "${proj}/data/temp/eventstudy_trend_long_stata_summary_v1.dta", replace
list, clean noobs

graph combine g82 g90 g00, ///
    col(3) ///
    graphregion(color(white)) ///
    title("Long-Horizon Event Study (Stata)", size(medium))

graph export "${proj}/result/figure/eventstudy_trend_long_stata_v1.png", replace width(3200)
graph export "${proj}/result/figure/eventstudy_trend_long_stata_v1.pdf", replace

