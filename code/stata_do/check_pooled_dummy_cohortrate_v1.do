/*  ================================================================
    Pooled baseline: dummy treatment + county×cohort-scaled treatment

    Treatments tried:
    A) Dummy: above/below median of martyr_count
    B) Dummy: above/below median of martyr_per100k
    C) Tercile dummies of martyr_count
    D) martyr_count / county×cohort cell size, standardised
    E) ln(1 + martyr_count), controlling for ln(cohort_size)
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")
global outdir "${proj}/paper/assets/tables"

*--------------------------------------------------------------
* county dictionary + crosswalk  (from clan v2)
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

*--------------------------------------------------------------
* resolve program  (full, from clan v2)
*--------------------------------------------------------------
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

/* dummy: above median count */
summ martyr_count, detail
scalar med_count = r(p50)
gen d_count_high = (martyr_count > med_count) if !missing(martyr_count)
di "Median martyr count = " med_count

/* dummy: above median per-capita rate */
summ martyr_per100k_1953, detail
scalar med_rate = r(p50)
gen d_rate_high = (martyr_per100k_1953 > med_rate) if !missing(martyr_per100k_1953)
di "Median martyr rate = " med_rate

/* tercile of count */
xtile count_tercile = martyr_count, nq(3)

rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
tempfile treat
save `treat'
global treat_tmp "`treat'"

*--------------------------------------------------------------
* mapping files for 1990/2000
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

* ---- 1982 ----
di "=== Loading 1982 ==="
use countyid birthyr eduy ethniccn using "$c1982", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen minority = (ethniccn != 1) if !missing(ethniccn)
keep if inrange(birthyr, 1920, 1956)
drop if floor(birthyr)==1939
drop if missing(eduy)
rename county_curr6 countyid_curr6
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
gen wave = 1
tempfile w1982
save `w1982'
di "1982 N = " _N

* ---- 1990 ----
di "=== Loading 1990 ==="
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
drop if floor(birthyr)==1939
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
gen wave = 2
tempfile w1990
save `w1990'
di "1990 N = " _N

* ---- 2000 ----
di "=== Loading 2000 ==="
use uid birthyr eduyr race using "$c2000", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1956)
drop if floor(birthyr)==1939
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
gen wave = 3
tempfile w2000
save `w2000'
di "2000 N = " _N

*==============================================================
*  Pool
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'
egen county_num = group(countyid_curr6)

di "=== Pooled N (before winsorize) = " _N
tab wave

/* winsorize eduy at 1st and 99th percentile */
summ eduy, detail
scalar eduy_p1  = r(p1)
scalar eduy_p99 = r(p99)
di "eduy: p1 = " eduy_p1 "  p99 = " eduy_p99
replace eduy = eduy_p1  if eduy < eduy_p1
replace eduy = eduy_p99 if eduy > eduy_p99 & !missing(eduy)
di "=== Pooled N (after winsorize) = " _N

*==============================================================
*  Construct county×cohort cell size & scaled treatment
*==============================================================

/* cell size: N per county × birth_year (across all waves pooled) */
bysort countyid_curr6 birth_i: gen cohort_size = _N

/* treatment D: martyr_count / cohort_size, standardised */
gen martyr_per_cohort = martyr_count / cohort_size
summ martyr_per_cohort, detail
/* winsorise at 99th */
scalar p99d = r(p99)
gen mpc_w = min(martyr_per_cohort, p99d)
summ mpc_w
gen mpc_std = (mpc_w - r(mean)) / r(sd)
label var mpc_std "Martyrs / county-cohort size (std)"

/* also ln version */
gen ln_mpc = ln(1 + martyr_per_cohort)

/* ln cohort size for control */
gen ln_cohort_size = ln(cohort_size)

di "=== Summary of new treatment variables ==="
summ martyr_per_cohort mpc_std ln_mpc cohort_size, detail

*==============================================================
*  Regressions
*==============================================================

/* ---- A: Dummy, above-median count ---- */
di "=== A: Dummy (count > median) ==="
reghdfejl eduy i.d_count_high##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local bA    = _b[1.d_count_high#1.post]
local seA   = _se[1.d_count_high#1.post]
local pA    = 2*ttail(e(df_r), abs(`bA'/`seA'))
local nA    = e(N)

/* ---- B: Dummy, above-median rate ---- */
di "=== B: Dummy (rate > median) ==="
reghdfejl eduy i.d_rate_high##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local bB    = _b[1.d_rate_high#1.post]
local seB   = _se[1.d_rate_high#1.post]
local pB    = 2*ttail(e(df_r), abs(`bB'/`seB'))
local nB    = e(N)

/* ---- C: Tercile dummies ---- */
di "=== C: Tercile (count) ==="
reghdfejl eduy i.count_tercile##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local bC2   = _b[2.count_tercile#1.post]
local seC2  = _se[2.count_tercile#1.post]
local pC2   = 2*ttail(e(df_r), abs(`bC2'/`seC2'))
local bC3   = _b[3.count_tercile#1.post]
local seC3  = _se[3.count_tercile#1.post]
local pC3   = 2*ttail(e(df_r), abs(`bC3'/`seC3'))
local nC    = e(N)

/* ---- D: martyr_count / cohort_size, std ---- */
di "=== D: Martyrs / county-cohort size (std) ==="
reghdfejl eduy c.mpc_std##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local bD    = _b[1.post#c.mpc_std]
local seD   = _se[1.post#c.mpc_std]
local pD    = 2*ttail(e(df_r), abs(`bD'/`seD'))
local nD    = e(N)

/* ---- E: ln(1 + martyr_count), controlling for ln(cohort_size) ---- */
di "=== E: ln(1+count) + control ln(cohort_size) ==="
reghdfejl eduy c.ln_martyr_raw##ib0.post c.ln_cohort_size##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local bE    = _b[1.post#c.ln_martyr_raw]
local seE   = _se[1.post#c.ln_martyr_raw]
local pE    = 2*ttail(e(df_r), abs(`bE'/`seE'))
local nE    = e(N)

/* ---- F: ln(martyr_per_cohort) ---- */
di "=== F: ln(1 + martyr/cohort) ==="
reghdfejl eduy c.ln_mpc##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local bF    = _b[1.post#c.ln_mpc]
local seF   = _se[1.post#c.ln_mpc]
local pF    = 2*ttail(e(df_r), abs(`bF'/`seF'))
local nF    = e(N)

/* ---- G: ln(1+count) only, no per-capita, no cohort control ---- */
di "=== G: ln(1+count) raw ==="
reghdfejl eduy c.ln_martyr_raw##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local bG    = _b[1.post#c.ln_martyr_raw]
local seG   = _se[1.post#c.ln_martyr_raw]
local pG    = 2*ttail(e(df_r), abs(`bG'/`seG'))
local nG    = e(N)

/* ---- H: Original ln(per100k) for reference ---- */
di "=== H: ln(1+per100k) reference ==="
reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local bH    = _b[1.post#c.ln_martyr_per100k_1953]
local seH   = _se[1.post#c.ln_martyr_per100k_1953]
local pH    = 2*ttail(e(df_r), abs(`bH'/`seH'))
local nH    = e(N)

*==============================================================
*  Output
*==============================================================
tempname fh
file open `fh' using "${outdir}/pooled_dummy_cohortrate_results_v1.csv", write replace
file write `fh' "spec,b,se,p,N" _n
file write `fh' "A_dummy_count,`bA',`seA',`pA',`nA'" _n
file write `fh' "B_dummy_rate,`bB',`seB',`pB',`nB'" _n
file write `fh' "C_tercile2,`bC2',`seC2',`pC2',`nC'" _n
file write `fh' "C_tercile3,`bC3',`seC3',`pC3',`nC'" _n
file write `fh' "D_mpc_std,`bD',`seD',`pD',`nD'" _n
file write `fh' "E_lncount_cohortctrl,`bE',`seE',`pE',`nE'" _n
file write `fh' "F_ln_mpc,`bF',`seF',`pF',`nF'" _n
file write `fh' "G_lncount_raw,`bG',`seG',`pG',`nG'" _n
file write `fh' "H_ln_per100k_ref,`bH',`seH',`pH',`nH'" _n
file close `fh'

di ""
di "========================================="
di "  RESULTS SUMMARY"
di "========================================="
di ""
di "A  Dummy (count>median):     b = " %8.4f `bA'  "  se = " %7.4f `seA'  "  p = " %6.4f `pA'  "  N = " %12.0fc `nA'
di "B  Dummy (rate>median):      b = " %8.4f `bB'  "  se = " %7.4f `seB'  "  p = " %6.4f `pB'  "  N = " %12.0fc `nB'
di "C  Tercile 2 vs 1:           b = " %8.4f `bC2' "  se = " %7.4f `seC2' "  p = " %6.4f `pC2' "  N = " %12.0fc `nC'
di "   Tercile 3 vs 1:           b = " %8.4f `bC3' "  se = " %7.4f `seC3' "  p = " %6.4f `pC3' "  N = " %12.0fc `nC'
di "D  Martyrs/cohort (std):     b = " %8.4f `bD'  "  se = " %7.4f `seD'  "  p = " %6.4f `pD'  "  N = " %12.0fc `nD'
di "E  ln(count)+cohort ctrl:    b = " %8.4f `bE'  "  se = " %7.4f `seE'  "  p = " %6.4f `pE'  "  N = " %12.0fc `nE'
di "F  ln(1+martyr/cohort):      b = " %8.4f `bF'  "  se = " %7.4f `seF'  "  p = " %6.4f `pF'  "  N = " %12.0fc `nF'
di "G  ln(1+count) raw:          b = " %8.4f `bG'  "  se = " %7.4f `seG'  "  p = " %6.4f `pG'  "  N = " %12.0fc `nG'
di "H  ln(1+per100k) reference:  b = " %8.4f `bH'  "  se = " %7.4f `seH'  "  p = " %6.4f `pH'  "  N = " %12.0fc `nH'

exit, clear
