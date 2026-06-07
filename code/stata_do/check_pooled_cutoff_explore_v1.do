/*  ================================================================
    Explore different treatment cutoffs:
    - median (12), mean (~266), p75 (145), p90
    - Figures + regressions for each
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")
global outdir "${proj}/paper/assets/tables"
global figdir "${proj}/paper/assets/figures"

*--------------------------------------------------------------
* county dictionary + crosswalk (same infrastructure)
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
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw pop_1953

gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

/* compute various cutoffs at county level */
summ martyr_count, detail
local p50  = r(p50)
local mean = r(mean)
local p75  = r(p75)
local p90  = r(p90)
local p67  = `p50' + (`p75' - `p50') * 0.68  /* approximate p67 */

/* get exact percentiles */
_pctile martyr_count, p(67 80)
local p67 = r(r1)
local p80 = r(r2)

di "=== County-level cutoffs ==="
di "Median (p50) = `p50'"
di "Mean         = " %8.1f `mean'
di "p67          = `p67'"
di "p75          = `p75'"
di "p80          = `p80'"
di "p90          = `p90'"

/* generate dummies for each cutoff */
gen d_p50  = (martyr_count > `p50')
gen d_mean = (martyr_count > `mean')
gen d_p75  = (martyr_count > `p75')
gen d_p90  = (martyr_count > `p90')

/* label cutoff values for display */
foreach c in p50 mean p75 p90 {
    local val_`c' = ``c''
}

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

/* county numeric for FE */
encode countyid_curr6, gen(county_num)

/* cohort cell size */
bysort county_num birth_i wave: gen cohort_n = _N
gen ln_cohort_n = ln(cohort_n)

di "=== POOLED N = " _N " ==="

*==============================================================
*  Figure: education by cohort for each cutoff
*==============================================================

foreach cutvar in p50 mean p75 p90 {

    local cutval = `val_`cutvar''

    if "`cutvar'" == "p50"  local clabel "Median (>`cutval')"
    if "`cutvar'" == "mean" local clabel "Mean (>`cutval')"
    if "`cutvar'" == "p75"  local clabel "p75 (>`cutval')"
    if "`cutvar'" == "p90"  local clabel "p90 (>`cutval')"

    di ""
    di "=== Figure for cutoff: `cutvar' = `cutval' ==="
    count if d_`cutvar' == 1
    di "Treatment obs = " r(N)
    count if d_`cutvar' == 0
    di "Control obs = " r(N)

    preserve
        collapse (mean) mean_edu = eduy, by(birthyr d_`cutvar')
        reshape wide mean_edu, i(birthyr) j(d_`cutvar')

        twoway (connected mean_edu0 birthyr, msymbol(circle) msize(small) lcolor(navy) mcolor(navy) lpattern(solid)) ///
               (connected mean_edu1 birthyr, msymbol(triangle) msize(small) lcolor(cranberry) mcolor(cranberry) lpattern(dash)), ///
               xline(1940, lcolor(gs8) lpattern(dash)) ///
               xline(1946, lcolor(gs8) lpattern(shortdash)) ///
               xtitle("Birth Year") ytitle("Mean Years of Education") ///
               title("`clabel'", size(medium)) ///
               legend(order(1 "Control" 2 "Treatment") rows(1) position(6) size(small)) ///
               xlabel(1920(5)1955, labsize(small)) ylabel(, labsize(small)) ///
               graphregion(color(white)) plotregion(color(white)) ///
               scheme(s2color)
        graph export "${figdir}/cohort_edu_cutoff_`cutvar'.pdf", replace
    restore

    /* gap figure */
    preserve
        collapse (mean) mean_edu = eduy, by(birthyr d_`cutvar')
        reshape wide mean_edu, i(birthyr) j(d_`cutvar')
        gen gap = mean_edu1 - mean_edu0

        twoway (connected gap birthyr, msymbol(circle) msize(small) lcolor(dkorange) mcolor(dkorange)) ///
               (lfit gap birthyr if birthyr < 1940, lcolor(navy) lpattern(dash) range(1920 1939)) ///
               (lfit gap birthyr if birthyr >= 1940, lcolor(cranberry) lpattern(dash) range(1940 1956)), ///
               yline(0, lcolor(gs10) lpattern(solid)) ///
               xline(1940, lcolor(gs8) lpattern(dash)) ///
               xline(1946, lcolor(gs8) lpattern(shortdash)) ///
               xtitle("Birth Year") ytitle("Education Gap (Treatment - Control)") ///
               title("`clabel'", size(medium)) ///
               legend(order(1 "Gap" 2 "Pre-1940 trend" 3 "Post-1940 trend") rows(1) position(6) size(small)) ///
               xlabel(1920(5)1955, labsize(small)) ylabel(, labsize(small)) ///
               graphregion(color(white)) plotregion(color(white)) ///
               scheme(s2color)
        graph export "${figdir}/cohort_gap_cutoff_`cutvar'.pdf", replace
    restore
}

/* Combined 2x2 figure: education levels */
preserve
    collapse (mean) mean_edu = eduy, by(birthyr d_mean)
    reshape wide mean_edu, i(birthyr) j(d_mean)
    tempfile fig_mean
    save `fig_mean'
restore

preserve
    collapse (mean) mean_edu = eduy, by(birthyr d_p75)
    reshape wide mean_edu, i(birthyr) j(d_p75)
    tempfile fig_p75
    save `fig_p75'
restore

*==============================================================
*  Regressions: each cutoff × each cohort cutoff
*==============================================================

tempname memhold
postfile `memhold' str20 cutoff_type cutoff_val str5 cohort_cut ///
    beta se pval n_obs using "${proj}/data/temp/cutoff_exploration_results.dta", replace

foreach cutvar in p50 mean p75 p90 {

    local cutval = `val_`cutvar''

    foreach ccut in 1940 1946 {
        gen post_`ccut' = (birth_i >= `ccut')

        /* dummy regression */
        di ""
        di "=== Regression: d_`cutvar' (>`cutval'), cutoff `ccut' ==="
        reghdfe eduy c.post_`ccut'#c.d_`cutvar' minority i.wave, ///
            absorb(county_num birth_i) vce(cluster county_num)
        local b  = _b[c.post_`ccut'#c.d_`cutvar']
        local se = _se[c.post_`ccut'#c.d_`cutvar']
        local t  = `b'/`se'
        local p  = 2*ttail(e(df_r), abs(`t'))
        local nn = e(N)

        di "  beta = " %8.4f `b' "  se = " %8.4f `se' "  p = " %6.4f `p' "  N = " `nn'

        post `memhold' ("`cutvar'") (`cutval') ("`ccut'") (`b') (`se') (`p') (`nn')

        /* with cohort size control */
        reghdfe eduy c.post_`ccut'#c.d_`cutvar' minority ln_cohort_n i.wave, ///
            absorb(county_num birth_i) vce(cluster county_num)
        local b2  = _b[c.post_`ccut'#c.d_`cutvar']
        local se2 = _se[c.post_`ccut'#c.d_`cutvar']
        local t2  = `b2'/`se2'
        local p2  = 2*ttail(e(df_r), abs(`t2'))

        di "  + cohort ctrl: beta = " %8.4f `b2' "  se = " %8.4f `se2' "  p = " %6.4f `p2'

        post `memhold' ("`cutvar'_cohort") (`cutval') ("`ccut'") (`b2') (`se2') (`p2') (`nn')

        drop post_`ccut'
    }
}

postclose `memhold'

/* display results */
use "${proj}/data/temp/cutoff_exploration_results.dta", clear
list, sep(4) noobs

di ""
di "=== DONE ==="

exit, clear
