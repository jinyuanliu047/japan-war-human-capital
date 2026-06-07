*******************************************************
* 2x2 postwar event-study panel in Stata
* Rebuild with navy series and maroon treatment markers
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _plot_one
program define _plot_one
    syntax , INFILE(string) GNAME(name) TITLE(string asis) SUBTITLE(string asis)

    import delimited "`infile'", clear
    sort birthyr

    quietly summarize baseyr
    local baseyr = r(mean)
    quietly summarize tstart
    local tstart = r(mean)
    quietly summarize tend
    local tend = r(mean)

    twoway ///
        (rcap ub lb birthyr, lcolor(navy%55) lwidth(vthin)) ///
        (line beta birthyr, lcolor(navy) lwidth(medthin)) ///
        (scatter beta birthyr, mcolor(navy) msymbol(circle) msize(vsmall)) ///
        (scatter beta birthyr if birthyr==`baseyr', mcolor(maroon) msymbol(diamond) msize(medlarge)), ///
        yline(0, lcolor(gs8) lpattern(dash)) ///
        xline(`baseyr', lcolor(black) lpattern(shortdash)) ///
        xline(`tstart' `tend', lcolor(maroon) lpattern(shortdash)) ///
        xtitle("Birth year") ///
        ytitle("Coefficient relative to base cohort") ///
        title(`"`title'"', size(medsmall)) ///
        subtitle(`"`subtitle'"', size(vsmall)) ///
        legend(off) ///
        graphregion(color(white)) ///
        plotregion(color(white)) ///
        name(`gname', replace)
end

_plot_one, ///
    infile("${proj}/data/temp/es_postwar_birth_wide_prebase_v4.csv") ///
    gname(g1) ///
    title("A. Postwar birth, pre-war base") ///
    subtitle("Base cohort = 1945; treated cohorts = 1946-1960")

_plot_one, ///
    infile("${proj}/data/temp/es_postwar_schentry_wide_prebase_v4.csv") ///
    gname(g2) ///
    title("B. Postwar school-entry, pre-war base") ///
    subtitle("Base cohort = 1942; treated cohorts = 1943-1960")

_plot_one, ///
    infile("${proj}/data/temp/es_postwar_birth_wide_currentbase_v4.csv") ///
    gname(g3) ///
    title("C. Postwar birth, current-period base") ///
    subtitle("Base cohort = 1946; treated cohorts = 1946-1960")

_plot_one, ///
    infile("${proj}/data/temp/es_postwar_schentry_wide_currentbase_v4.csv") ///
    gname(g4) ///
    title("D. Postwar school-entry, current-period base") ///
    subtitle("Base cohort = 1943; treated cohorts = 1943-1960")

graph combine g1 g2 g3 g4, ///
    cols(2) imargin(3 3 3 3) ///
    graphregion(color(white)) ///
    title("Postwar Event-Study Panels", size(medium)) ///
    note("Navy lines show coefficients with 95% confidence intervals; maroon dashed lines mark treatment bounds.", size(vsmall)) ///
    name(gall, replace)

graph export "${proj}/result/figure/eventstudy_postwar_main_2x2_stata_v1.png", replace width(3200)
graph export "${proj}/result/figure/eventstudy_postwar_main_2x2_stata_v1.pdf", replace

exit, clear
