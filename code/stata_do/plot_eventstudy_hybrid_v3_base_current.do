*******************************************************
* Hybrid event-study plots (base = treatment start year)
* - schoolage / wartime: sacrifice treatment
* - postwar: native treatment
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _make_event_plot_h_cur
program define _make_event_plot_h_cur
    syntax , ///
        SAMPLECOND(string) ///
        TREATVAR(string) ///
        BASEYR(integer) ///
        OUTSTUB(string) ///
        TITLETXT(string) ///
        XLINE1(integer) ///
        XLINE2(integer) ///
        NOTETXT(string)

    use "${proj}/data/temp/did_1982_county_birthyr_martyr_hybrid_v3.dta", clear
    keep if `samplecond'
    keep if strict_share_wt >= 0.8

    reghdfe eduy_wmean ib`baseyr'.birthyr##c.`treatvar' [aw=wt_sum], ///
        absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)

    tempfile coef
    tempname posth
    postfile `posth' int birthyr double beta se lb ub using "`coef'", replace

    levelsof birthyr, local(years)
    foreach y of local years {
        if `y' == `baseyr' {
            post `posth' (`y') (0) (0) (0) (0)
        }
        else {
            capture quietly lincom `y'.birthyr#c.`treatvar'
            if _rc == 0 {
                post `posth' (`y') (r(estimate)) (r(se)) (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se))
            }
        }
    }
    postclose `posth'

    use "`coef'", clear
    sort birthyr
    export delimited using "${proj}/data/temp/`outstub'.csv", replace
    save "${proj}/data/temp/`outstub'.dta", replace

    twoway ///
        (rcap ub lb birthyr, lcolor(emerald%55) lwidth(vthin)) ///
        (line beta birthyr, lcolor(emerald%80) lwidth(medthin)) ///
        (scatter beta birthyr, mcolor(emerald) msymbol(circle) msize(vsmall)) ///
        (scatter beta birthyr if birthyr==`baseyr', mcolor(maroon) msymbol(diamond) msize(medlarge)), ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        xline(`baseyr', lcolor(black) lpattern(shortdash)) ///
        xline(`xline1' `xline2', lcolor(maroon) lpattern(shortdash)) ///
        xtitle("Birth year") ///
        ytitle("Effect relative to base cohort") ///
        title("`titletxt'", size(medsmall)) ///
        subtitle("Base cohort = treatment start year (`baseyr')", size(small)) ///
        note("`notetxt'", size(vsmall)) ///
        legend(off) ///
        graphregion(color(white))

    graph export "${proj}/result/figure/`outstub'.png", replace width(2600)
end

* Schoolage (sacrifice): treated 1925-1939, base 1925
_make_event_plot_h_cur, ///
    samplecond("inrange(birthyr,1915,1950)") ///
    treatvar("ln_martyr_sacrifice_count") ///
    baseyr(1925) ///
    outstub("birthyr_eventstudy_hybrid_schoolage_sac_v3_basecurrent") ///
    titletxt("Hybrid ES: schoolage (base = 1925)") ///
    xline1(1925) ///
    xline2(1939) ///
    notetxt("Red lines: treated cohort bounds (1925-1939).")

* Wartime birth (sacrifice): treated 1931-1945, base 1931
_make_event_plot_h_cur, ///
    samplecond("inrange(birthyr,1920,1950)") ///
    treatvar("ln_martyr_sacrifice_count") ///
    baseyr(1931) ///
    outstub("birthyr_eventstudy_hybrid_wartime_sac_v3_basecurrent") ///
    titletxt("Hybrid ES: wartime-birth (base = 1931)") ///
    xline1(1931) ///
    xline2(1945) ///
    notetxt("Red lines: treated cohort bounds (1931-1945).")

* Postwar birth baseline (native): treated 1946-1955, base 1946
_make_event_plot_h_cur, ///
    samplecond("inrange(birthyr,1938,1955)") ///
    treatvar("ln_martyr_native_count") ///
    baseyr(1946) ///
    outstub("birthyr_eventstudy_hybrid_postwar_birth_native_v3_basecurrent") ///
    titletxt("Hybrid ES: postwar-birth (base = 1946)") ///
    xline1(1946) ///
    xline2(1955) ///
    notetxt("Red lines: treated cohort bounds (1946-1955).")

* Postwar schooling-entry alternative (native): treated >=1943, base 1943
_make_event_plot_h_cur, ///
    samplecond("inrange(birthyr,1936,1955)") ///
    treatvar("ln_martyr_native_count") ///
    baseyr(1943) ///
    outstub("birthyr_eventstudy_hybrid_postwar_schentry49_native_v3_basecurrent") ///
    titletxt("Hybrid ES: postwar-school-entry (base = 1943)") ///
    xline1(1943) ///
    xline2(1955) ///
    notetxt("Red lines: cohorts with school entry in/after 1949 (birth>=1943).")
