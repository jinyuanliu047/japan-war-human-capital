/*  ================================================================
    Residualized education figure:
    1. Regress eduy on county FE + wave FE → get residual
    2. Plot residual by birth cohort × treatment
    This removes county composition effects and shows cleaner DiD
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")
global figdir "${proj}/paper/assets/figures"

*--------------------------------------------------------------
* county dictionary + crosswalk
*--------------------------------------------------------------
import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
keep GBCounty
destring GBCounty, replace force
drop if missing(GBCounty)
gen str6 county_curr6 = string(GBCounty, "%06.0f")
gen str6 old6 = county_curr6
gen str6 curr_dict = county_curr6
keep old6 curr_dict
duplicates drop old6, force
tempfile county_dict
save `county_dict'
global county_dict_tmp "`county_dict'"

import delimited "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", clear varnames(1) stringcols(_all)
rename countyid_old6 old6
rename countyid_curr6_final county_curr6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = subinstr(county_curr6, ".0", "", .)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6 route_final
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'
global cw1982_tmp "`cw1982'"

capture program drop _resolve_old6_map
program define _resolve_old6_map
    gen str6 county_curr6 = ""
    gen str30 route = "unmatched"
    replace county_curr6 = "310101" if old6=="310103"
    replace route = "manual_successor" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace route = "manual_successor" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace route = "manual_successor" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"
    replace route = "manual_successor" if old6=="110010"
    tempfile left
    save `left'
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6 route_final)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    replace route = "crosswalk_1982" if county_curr6!="" & route=="unmatched"
    drop county_curr6 route_final
    rename curr_res county_curr6
    save `left', replace
    use `left', clear
    rename county_curr6 curr_res
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace curr_res = curr_dict if curr_res=="" & curr_dict!=""
    replace route = "exact_code" if curr_dict!="" & route=="unmatched"
    drop curr_dict
    rename curr_res county_curr6
    gen str6 muni6 = substr(old6,1,2) + "01" + substr(old6,5,2) ///
        if inlist(substr(old6,1,2),"11","12","31") & substr(old6,3,2)=="00" & county_curr6==""
    tempfile muni_exact
    tempfile muni_cw
    preserve
        keep old6
        keep if 0
        gen str6 curr_from_muni_exact = ""
        save `muni_exact', replace
    restore
    preserve
        keep old6
        keep if 0
        gen str6 curr_from_muni_cw = ""
        save `muni_cw', replace
    restore
    preserve
        keep if muni6!="" & county_curr6==""
        count
        if r(N)>0 {
            keep old6 muni6
            rename muni6 old6_muni
            rename old6 old6_orig
            rename old6_muni old6
            merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
            keep if curr_dict!=""
            drop old6
            rename old6_orig old6
            rename curr_dict curr_from_muni_exact
            keep old6 curr_from_muni_exact
            save `muni_exact', replace
        }
    restore
    merge 1:1 old6 using `muni_exact', keep(master match) nogen
    replace county_curr6 = curr_from_muni_exact if county_curr6=="" & curr_from_muni_exact!=""
    replace route = "municipality_geo3_recode" if county_curr6==curr_from_muni_exact & curr_from_muni_exact!=""
    drop curr_from_muni_exact
    preserve
        keep if muni6!="" & county_curr6==""
        count
        if r(N)>0 {
            keep old6 muni6
            rename muni6 old6_muni
            rename old6 old6_orig
            rename old6_muni old6
            merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
            keep if county_curr6!=""
            drop old6
            rename old6_orig old6
            rename county_curr6 curr_from_muni_cw
            keep old6 curr_from_muni_cw
            save `muni_cw', replace
        }
    restore
    merge 1:1 old6 using `muni_cw', keep(master match) nogen
    replace county_curr6 = curr_from_muni_cw if county_curr6=="" & curr_from_muni_cw!=""
    replace route = "municipality_then_crosswalk_1982" if county_curr6==curr_from_muni_cw & curr_from_muni_cw!=""
    drop curr_from_muni_cw muni6
end

*--------------------------------------------------------------
* treatment
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_raw pop_1953

gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)

summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)

rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
tempfile treat
save `treat'
global treat_tmp "`treat'"

*--------------------------------------------------------------
* mapping 1990/2000
*--------------------------------------------------------------
use county age_c age educ using "$c1990", clear
drop if missing(county)
gen str6 old6 = string(county, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map1990
save `map1990'
global map1990_tmp "`map1990'"

use uid birthyr eduyr using "$c2000", clear
drop if missing(uid)
gen str6 old6 = string(uid, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map2000
save `map2000'
global map2000_tmp "`map2000'"

*==============================================================
*  Load each wave
*==============================================================
use countyid birthyr eduy ethniccn using "$c1982", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen minority = (ethniccn != 1) if !missing(ethniccn)
keep if inrange(birthyr, 1920, 1956)
rename county_curr6 countyid_curr6
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 1
tempfile w1982
save `w1982'

use county age_c age educ race using "$c1990", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birthyr = 1000 + age_c*100 + age
gen eduy = .
replace eduy = 0  if educ==1
replace eduy = 6  if educ==2
replace eduy = 9  if educ==3
replace eduy = 12 if inlist(educ,4,5)
replace eduy = 15 if educ==6
replace eduy = 16 if educ==7
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 2
tempfile w1990
save `w1990'

use uid birthyr eduyr race using "$c2000", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 3
tempfile w2000
save `w2000'

*==============================================================
*  Pool & winsorize
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'

summ eduy, detail
scalar p1 = r(p1)
scalar p99 = r(p99)
replace eduy = p1 if eduy < p1
replace eduy = p99 if eduy > p99 & !missing(eduy)

encode countyid_curr6, gen(county_num)

di "=== POOLED N = " _N " ==="

*==============================================================
*  Method 1: Residualize eduy on county FE + wave FE
*  Then plot residual by cohort × treatment
*==============================================================

/* regress out county FE and wave FE */
reghdfe eduy i.wave, absorb(county_num) residuals(eduy_resid)

di "=== Residualized education: county FE + wave FE removed ==="

/* collapse to cohort × treatment means */
preserve
    collapse (mean) mean_resid = eduy_resid (count) n = eduy_resid, by(birthyr d_count_high)
    reshape wide mean_resid n, i(birthyr) j(d_count_high)

    /* Figure A: residualized education by cohort */
    twoway (connected mean_resid0 birthyr, msymbol(circle) msize(small) lcolor(navy) mcolor(navy) lpattern(solid)) ///
           (connected mean_resid1 birthyr, msymbol(triangle) msize(small) lcolor(cranberry) mcolor(cranberry) lpattern(dash)), ///
           xline(1940, lcolor(gs8) lpattern(dash)) ///
           xline(1946, lcolor(gs8) lpattern(shortdash)) ///
           xtitle("Birth Year") ytitle("Residualized Years of Education") ///
           legend(order(1 "Control (count {&le} 12)" 2 "Treatment (count > 12)") rows(1) position(6) size(small)) ///
           xlabel(1920(5)1955, labsize(small)) ylabel(, labsize(small)) ///
           graphregion(color(white)) plotregion(color(white)) ///
           note("County FE and wave FE removed", size(vsmall)) ///
           scheme(s2color)
    graph export "${figdir}/cohort_edu_residualized.pdf", replace

    /* Figure B: gap in residuals */
    gen gap = mean_resid1 - mean_resid0

    twoway (connected gap birthyr, msymbol(circle) msize(small) lcolor(dkorange) mcolor(dkorange)) ///
           (lfit gap birthyr if birthyr < 1940, lcolor(navy) lpattern(dash) range(1920 1939)) ///
           (lfit gap birthyr if birthyr >= 1940, lcolor(cranberry) lpattern(dash) range(1940 1956)), ///
           yline(0, lcolor(gs10) lpattern(solid)) ///
           xline(1940, lcolor(gs8) lpattern(dash)) ///
           xline(1946, lcolor(gs8) lpattern(shortdash)) ///
           xtitle("Birth Year") ytitle("Residualized Education Gap (T - C)") ///
           legend(order(1 "Gap" 2 "Pre-1940 trend" 3 "Post-1940 trend") rows(1) position(6) size(small)) ///
           xlabel(1920(5)1955, labsize(small)) ylabel(, labsize(small)) ///
           graphregion(color(white)) plotregion(color(white)) ///
           note("County FE and wave FE removed", size(vsmall)) ///
           scheme(s2color)
    graph export "${figdir}/cohort_gap_residualized.pdf", replace
restore

*==============================================================
*  Method 2: County-level weighted mean education by cohort
*  Collapse to county × cohort, then average across counties
*  (equal county weight, not population-weighted)
*==============================================================

preserve
    /* collapse to county × cohort × treatment cell */
    collapse (mean) mean_edu = eduy (count) n = eduy, by(countyid_curr6 birthyr d_count_high)

    /* now take unweighted county average by cohort × treatment */
    collapse (mean) mean_edu_county = mean_edu (count) n_counties = n, by(birthyr d_count_high)
    reshape wide mean_edu_county n_counties, i(birthyr) j(d_count_high)

    /* Figure C: county-weighted education */
    twoway (connected mean_edu_county0 birthyr, msymbol(circle) msize(small) lcolor(navy) mcolor(navy) lpattern(solid)) ///
           (connected mean_edu_county1 birthyr, msymbol(triangle) msize(small) lcolor(cranberry) mcolor(cranberry) lpattern(dash)), ///
           xline(1940, lcolor(gs8) lpattern(dash)) ///
           xline(1946, lcolor(gs8) lpattern(shortdash)) ///
           xtitle("Birth Year") ytitle("Mean Years of Education (county-equal weight)") ///
           legend(order(1 "Control (count {&le} 12)" 2 "Treatment (count > 12)") rows(1) position(6) size(small)) ///
           xlabel(1920(5)1955, labsize(small)) ylabel(, labsize(small)) ///
           graphregion(color(white)) plotregion(color(white)) ///
           note("Each county weighted equally (not population-weighted)", size(vsmall)) ///
           scheme(s2color)
    graph export "${figdir}/cohort_edu_county_equalweight.pdf", replace

    /* Figure D: gap */
    gen gap = mean_edu_county1 - mean_edu_county0

    twoway (connected gap birthyr, msymbol(circle) msize(small) lcolor(dkorange) mcolor(dkorange)) ///
           (lfit gap birthyr if birthyr < 1940, lcolor(navy) lpattern(dash) range(1920 1939)) ///
           (lfit gap birthyr if birthyr >= 1940, lcolor(cranberry) lpattern(dash) range(1940 1956)), ///
           yline(0, lcolor(gs10) lpattern(solid)) ///
           xline(1940, lcolor(gs8) lpattern(dash)) ///
           xline(1946, lcolor(gs8) lpattern(shortdash)) ///
           xtitle("Birth Year") ytitle("Education Gap (T - C, county-equal weight)") ///
           legend(order(1 "Gap" 2 "Pre-1940 trend" 3 "Post-1940 trend") rows(1) position(6) size(small)) ///
           xlabel(1920(5)1955, labsize(small)) ylabel(, labsize(small)) ///
           graphregion(color(white)) plotregion(color(white)) ///
           note("Each county weighted equally", size(vsmall)) ///
           scheme(s2color)
    graph export "${figdir}/cohort_gap_county_equalweight.pdf", replace
restore

*==============================================================
*  Also: raw cohort size by year (for descriptive purposes)
*==============================================================
preserve
    collapse (count) n = eduy, by(birthyr d_count_high)
    reshape wide n, i(birthyr) j(d_count_high)

    twoway (line n0 birthyr, lcolor(navy) lpattern(solid) lwidth(medium)) ///
           (line n1 birthyr, lcolor(cranberry) lpattern(dash) lwidth(medium)), ///
           xline(1940, lcolor(gs8) lpattern(dash)) ///
           xline(1946, lcolor(gs8) lpattern(shortdash)) ///
           xtitle("Birth Year") ytitle("Number of Individuals") ///
           legend(order(1 "Control (count {&le} 12)" 2 "Treatment (count > 12)") rows(1) position(6) size(small)) ///
           xlabel(1920(5)1955, labsize(small)) ylabel(, labsize(small) format(%12.0fc)) ///
           graphregion(color(white)) plotregion(color(white)) ///
           scheme(s2color)
    graph export "${figdir}/cohort_size_line.pdf", replace
restore

di "=== ALL FIGURES DONE ==="

exit, clear
