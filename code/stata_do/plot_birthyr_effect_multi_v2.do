*******************************************************
* Event-study style plots by birth cohort
* Coef: ln(1+martyr native count) x cohort dummy
* with county FE + birth-year FE
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _make_event_plot
program define _make_event_plot
    syntax , ///
        SAMPLECOND(string) ///
        BASEYR(integer) ///
        OUTSTUB(string) ///
        TITLETXT(string) ///
        XLINE1(integer) ///
        XLINE2(integer) ///
        NOTETXT(string)

    use "${proj}/data/temp/did_1982_county_birthyr_martyr_native_v2.dta", clear
    keep if `samplecond'
    keep if strict_share_wt >= 0.8

    * Event-study specification for continuous treatment:
    * y_cb = county FE + birthyr FE + sum_{k!=base} beta_k * Treat_c * 1[birthyr=k] + e_cb
    reghdfe eduy_wmean ib`baseyr'.birthyr##c.ln_martyr_native_count [aw=wt_sum], ///
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
            capture quietly lincom `y'.birthyr#c.ln_martyr_native_count
            if _rc == 0 {
                post `posth' (`y') (r(estimate)) (r(se)) (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se))
            }
        }
    }
    postclose `posth'

    use "`coef'", clear
    sort birthyr
    label var beta "Event-study coefficient (relative to base cohort)"
    label var birthyr "Birth year"

    export delimited using "${proj}/data/temp/`outstub'.csv", replace
    save "${proj}/data/temp/`outstub'.dta", replace

    twoway ///
        (rcap ub lb birthyr, lcolor(navy%55) lwidth(vthin)) ///
        (line beta birthyr, lcolor(navy%80) lwidth(medthin)) ///
        (scatter beta birthyr, mcolor(navy) msymbol(circle) msize(vsmall)) ///
        (scatter beta birthyr if birthyr==`baseyr', mcolor(maroon) msymbol(diamond) msize(medlarge)), ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        xline(`baseyr', lcolor(black) lpattern(shortdash)) ///
        xline(`xline1' `xline2', lcolor(maroon) lpattern(shortdash)) ///
        xtitle("Birth year") ///
        ytitle("Effect relative to base cohort") ///
        title("`titletxt'", size(medsmall)) ///
        subtitle("Base cohort = `baseyr'; points with 95% CI", size(small)) ///
        note("`notetxt'", size(vsmall)) ///
        legend(off) ///
        graphregion(color(white))

    graph export "${proj}/result/figure/`outstub'.png", replace width(2600)
end

* 1) School-age cohort definition used in DID data: 1925-1939
* base year = 1924 (one year before treatment cohort starts)
_make_event_plot, ///
    samplecond("inrange(birthyr,1915,1950)") ///
    baseyr(1924) ///
    outstub("birthyr_eventstudy_schoolage_v2") ///
    titletxt("Event study: school-age exposure cohorts") ///
    xline1(1925) ///
    xline2(1939) ///
    notetxt("Red lines mark school-age cohort bounds (1925-1939). Black dashed line is base cohort (1924).")

* 2) Wartime-birth cohorts (1931-1945), base = last pre-war cohort
_make_event_plot, ///
    samplecond("inrange(birthyr,1920,1950)") ///
    baseyr(1930) ///
    outstub("birthyr_eventstudy_wartime_v2") ///
    titletxt("Event study: wartime-birth cohorts") ///
    xline1(1931) ///
    xline2(1945) ///
    notetxt("Red lines mark wartime-birth cohort bounds (1931-1945). Black dashed line is base cohort (1930).")

* 3) Postwar-birth cohorts (1946-1955), base = last wartime cohort
_make_event_plot, ///
    samplecond("inrange(birthyr,1938,1955)") ///
    baseyr(1945) ///
    outstub("birthyr_eventstudy_postwar_v2") ///
    titletxt("Event study: postwar-birth cohorts") ///
    xline1(1946) ///
    xline2(1955) ///
    notetxt("Red lines mark postwar-birth cohort bounds (1946-1955). Black dashed line is base cohort (1945).")
