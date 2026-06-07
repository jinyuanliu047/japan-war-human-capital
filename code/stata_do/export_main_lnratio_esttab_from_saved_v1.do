*******************************************************
* Build esttab RTF from validated main coefficients
* (temporary fallback when cloud I/O blocks full rerun)
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 {
    ssc install estout, replace
}

capture program drop _post_main
program define _post_main, eclass
    syntax , B(real) SE(real) NCELLS(integer) NCOUNTIES(integer)

    tempname bb VV
    matrix `bb' = (`b')
    matrix colnames `bb' = did

    matrix `VV' = (`se'^2)
    matrix colnames `VV' = did
    matrix rownames `VV' = did

    ereturn post `bb' `VV'
    ereturn scalar N = `ncells'

    estadd local county_fe "Yes"
    estadd local cohort_fe "Yes"
    estadd local se_cluster "County"
    estadd local drop1939 "Yes"
    estadd scalar n_cells = `ncells'
    estadd scalar n_counties = `ncounties'
end

eststo clear

* Coefficients from validated log: check_eventstudy_coefficient_drop1939_start1940_wavecut_v1.log
eststo m1982: _post_main, b(.07263061) se(.0098622) ncells(67104) ncounties(1688)
eststo m1990: _post_main, b(.08533462) se(.0116868) ncells(78645) ncounties(1652)
eststo m2000: _post_main, b(.08604854) se(.0083055) ncells(126669) ncounties(2209)

esttab m1982 m1990 m2000 using "${proj}/result/table/main_regression_lnratio_esttab_v2.rtf", replace ///
    mtitles("Census 1982" "Census 1990" "Census 2000") ///
    keep(did) ///
    coeflabels(did "Post x ln(1+martyrs per 100k)") ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    compress label nonumbers ///
    stats(county_fe cohort_fe se_cluster drop1939 n_cells n_counties N, ///
          labels("County FE" "Birth-year FE" "SE cluster" "Drop 1939 cohort" "Cell observations" "Counties" "N (estimation)"))

exit, clear
