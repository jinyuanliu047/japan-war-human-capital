/*  ================================================================
    Pooled baseline with standardised per-capita treatment
    - Treatment: z-score of martyrs_per100k_1953 (winsorised p99)
    - Sample: 1982 + 1990 + 2000 censuses stacked
    - FEs: county + birth_year + wave  (main)
    ================================================================ */

clear all
set more off
set maxvar 10000

/* ---------- paths ---------- */
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")
global outdir "${proj}/paper/assets/tables"

*--------------------------------------------------------------
* county dictionary and 1982 crosswalk  (from clan v2)
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
* resolve old6 -> county_curr6  (full version from clan v2)
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
* treatment: both std rate and ln
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw pop_1953

/* raw count (not per capita) */
gen martyr_count = exp(ln_martyr_raw) - 1 if ln_martyr_raw > 0
replace martyr_count = 0 if ln_martyr_raw == 0 | missing(ln_martyr_raw)

/* winsorise raw count at 99th */
summ martyr_count, detail
scalar p99c = r(p99)
gen count_w = min(martyr_count, p99c)
summ count_w
gen count_std = (count_w - r(mean)) / r(sd)
label var count_std "War exposure: std count (not per capita)"

/* winsorise per-capita rate at 99th */
summ martyr_per100k_1953, detail
scalar p99 = r(p99)
gen martyr_rate_w = min(martyr_per100k_1953, p99)
summ martyr_rate_w
gen martyr_rate_std = (martyr_rate_w - r(mean)) / r(sd)
label var martyr_rate_std "War exposure: std rate (per capita)"

/* scaled raw rate */
gen martyr_rate_100 = martyr_per100k_1953 / 100

rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
tempfile treat
save `treat'
global treat_tmp "`treat'"

*--------------------------------------------------------------
* mapping files for 1990 / 2000
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

*--------------------------------------------------------------
* _stars helper
*--------------------------------------------------------------
capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01 {
        return local star "\sym{***}"
    }
    else if `pval' < 0.05 {
        return local star "\sym{**}"
    }
    else if `pval' < 0.10 {
        return local star "\sym{*}"
    }
    else {
        return local star ""
    }
end

*==============================================================
*  Load each wave, save temp files
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
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
gen wave = 3
tempfile w2000
save `w2000'
di "2000 N = " _N

*==============================================================
*  Stack and run pooled regressions
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'

/* consistent county_num across pooled sample */
egen county_num = group(countyid_curr6)

di "=== Pooled sample (before winsorize) ==="
di "Total N = " _N
tab wave

/* winsorize eduy at 1st and 99th percentile */
summ eduy, detail
scalar eduy_p1  = r(p1)
scalar eduy_p99 = r(p99)
di "eduy: p1 = " eduy_p1 "  p99 = " eduy_p99
replace eduy = eduy_p1  if eduy < eduy_p1
replace eduy = eduy_p99 if eduy > eduy_p99 & !missing(eduy)
di "=== After winsorize, N = " _N

/* ---------- Spec 1: Pooled, std rate, county + birth + wave FE ---------- */
di "=== Spec 1: Pooled, std rate, county + birth + wave FE ==="
reghdfejl eduy c.martyr_rate_std##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b1    = _b[1.post#c.martyr_rate_std]
local se1   = _se[1.post#c.martyr_rate_std]
local p1    = 2*ttail(e(df_r), abs(`b1'/`se1'))
local n1    = e(N)
local nc1   = e(N_clust)

/* ---------- Spec 2: Pooled, std rate, county + wave×birth FE ---------- */
di "=== Spec 2: Pooled, std rate, wave x birth FE ==="
gen wave_birth = wave * 1000 + birth_i
reghdfejl eduy c.martyr_rate_std##ib0.post minority, ///
    absorb(county_num wave_birth) vce(cluster county_num)
local b2    = _b[1.post#c.martyr_rate_std]
local se2   = _se[1.post#c.martyr_rate_std]
local p2    = 2*ttail(e(df_r), abs(`b2'/`se2'))
local n2    = e(N)
local nc2   = e(N_clust)

/* ---------- Spec 3: Balanced (1920-1960) ---------- */
di "=== Spec 3: Balanced (1920-1960), std rate ==="
reghdfejl eduy c.martyr_rate_std##ib0.post minority i.wave if birth_i <= 1960, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b3    = _b[1.post#c.martyr_rate_std]
local se3   = _se[1.post#c.martyr_rate_std]
local p3    = 2*ttail(e(df_r), abs(`b3'/`se3'))
local n3    = e(N)
local nc3   = e(N_clust)

/* ---------- Spec 4: Pooled, ln (comparison) ---------- */
di "=== Spec 4: Pooled, ln treatment ==="
reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b4    = _b[1.post#c.ln_martyr_per100k_1953]
local se4   = _se[1.post#c.ln_martyr_per100k_1953]
local p4    = 2*ttail(e(df_r), abs(`b4'/`se4'))
local n4    = e(N)
local nc4   = e(N_clust)

/* ---------- Spec 5: Raw rate / 100 ---------- */
di "=== Spec 5: Raw rate / 100 ==="
reghdfejl eduy c.martyr_rate_100##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b5    = _b[1.post#c.martyr_rate_100]
local se5   = _se[1.post#c.martyr_rate_100]
local p5    = 2*ttail(e(df_r), abs(`b5'/`se5'))
local n5    = e(N)
local nc5   = e(N_clust)

/* ---------- Spec 6: Raw count (not per capita), std ---------- */
di "=== Spec 6: Pooled, std count (not per capita) ==="
reghdfejl eduy c.count_std##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b6    = _b[1.post#c.count_std]
local se6   = _se[1.post#c.count_std]
local p6    = 2*ttail(e(df_r), abs(`b6'/`se6'))
local n6    = e(N)
local nc6   = e(N_clust)

/* ---------- Spec 7: ln raw count (not per capita) ---------- */
di "=== Spec 7: Pooled, ln raw count ==="
reghdfejl eduy c.ln_martyr_raw##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b7    = _b[1.post#c.ln_martyr_raw]
local se7   = _se[1.post#c.ln_martyr_raw]
local p7    = 2*ttail(e(df_r), abs(`b7'/`se7'))
local n7    = e(N)
local nc7   = e(N_clust)

/* ---------- Spec 8: ln raw count + control for ln(pop) ---------- */
di "=== Spec 8: ln raw count + ln(pop) control ==="
gen ln_pop = ln(pop_1953)
reghdfejl eduy c.ln_martyr_raw##ib0.post c.ln_pop##ib0.post minority i.wave, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b8    = _b[1.post#c.ln_martyr_raw]
local se8   = _se[1.post#c.ln_martyr_raw]
local p8    = 2*ttail(e(df_r), abs(`b8'/`se8'))
local n8    = e(N)
local nc8   = e(N_clust)

/* ---------- Wave-specific (std count, not per capita) ---------- */
di "=== Wave-specific count: 1982 ==="
reghdfejl eduy c.count_std##ib0.post minority if wave == 1, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b9a   = _b[1.post#c.count_std]
local se9a  = _se[1.post#c.count_std]
local p9a   = 2*ttail(e(df_r), abs(`b9a'/`se9a'))
local n9a   = e(N)

di "=== Wave-specific count: 1990 ==="
reghdfejl eduy c.count_std##ib0.post minority if wave == 2, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b9b   = _b[1.post#c.count_std]
local se9b  = _se[1.post#c.count_std]
local p9b   = 2*ttail(e(df_r), abs(`b9b'/`se9b'))
local n9b   = e(N)

di "=== Wave-specific count: 2000 ==="
reghdfejl eduy c.count_std##ib0.post minority if wave == 3, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b9c   = _b[1.post#c.count_std]
local se9c  = _se[1.post#c.count_std]
local p9c   = 2*ttail(e(df_r), abs(`b9c'/`se9c'))
local n9c   = e(N)

/* ---------- Wave-specific (std rate, per capita) ---------- */
di "=== Wave-specific rate: 1982 ==="
reghdfejl eduy c.martyr_rate_std##ib0.post minority if wave == 1, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b6a   = _b[1.post#c.martyr_rate_std]
local se6a  = _se[1.post#c.martyr_rate_std]
local p6a   = 2*ttail(e(df_r), abs(`b6a'/`se6a'))
local n6a   = e(N)

di "=== Wave-specific: 1990 ==="
reghdfejl eduy c.martyr_rate_std##ib0.post minority if wave == 2, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b6b   = _b[1.post#c.martyr_rate_std]
local se6b  = _se[1.post#c.martyr_rate_std]
local p6b   = 2*ttail(e(df_r), abs(`b6b'/`se6b'))
local n6b   = e(N)

di "=== Wave-specific: 2000 ==="
reghdfejl eduy c.martyr_rate_std##ib0.post minority if wave == 3, ///
    absorb(county_num birth_i) vce(cluster county_num)
local b6c   = _b[1.post#c.martyr_rate_std]
local se6c  = _se[1.post#c.martyr_rate_std]
local p6c   = 2*ttail(e(df_r), abs(`b6c'/`se6c'))
local n6c   = e(N)

*==============================================================
*  Output
*==============================================================
tempname fh
file open `fh' using "${outdir}/pooled_baseline_stdrate_results_v1.csv", write replace
file write `fh' "spec,b,se,p,N,N_clust" _n
file write `fh' "pooled_std_birthFE,`b1',`se1',`p1',`n1',`nc1'" _n
file write `fh' "pooled_std_wavebirthFE,`b2',`se2',`p2',`n2',`nc2'" _n
file write `fh' "pooled_balanced_1960,`b3',`se3',`p3',`n3',`nc3'" _n
file write `fh' "pooled_ln_comparison,`b4',`se4',`p4',`n4',`nc4'" _n
file write `fh' "pooled_rawrate100,`b5',`se5',`p5',`n5',`nc5'" _n
file write `fh' "pooled_count_std,`b6',`se6',`p6',`n6',`nc6'" _n
file write `fh' "pooled_ln_raw,`b7',`se7',`p7',`n7',`nc7'" _n
file write `fh' "pooled_ln_raw_popctrl,`b8',`se8',`p8',`n8',`nc8'" _n
file write `fh' "wave1982_count,`b9a',`se9a',`p9a',`n9a',." _n
file write `fh' "wave1990_count,`b9b',`se9b',`p9b',`n9b',." _n
file write `fh' "wave2000_count,`b9c',`se9c',`p9c',`n9c',." _n
file write `fh' "wave1982_std,`b6a',`se6a',`p6a',`n6a',." _n
file write `fh' "wave1990_std,`b6b',`se6b',`p6b',`n6b',." _n
file write `fh' "wave2000_std,`b6c',`se6c',`p6c',`n6c',." _n
file close `fh'

di ""
di "========================================="
di "  RESULTS SUMMARY"
di "========================================="
di ""
di "Spec 1 (pooled std, birth FE):       b = " %7.4f `b1' "  se = " %7.4f `se1' "  p = " %6.4f `p1' "  N = " %12.0fc `n1'
di "Spec 2 (pooled std, wave×birth FE):  b = " %7.4f `b2' "  se = " %7.4f `se2' "  p = " %6.4f `p2' "  N = " %12.0fc `n2'
di "Spec 3 (balanced 1920-1960):         b = " %7.4f `b3' "  se = " %7.4f `se3' "  p = " %6.4f `p3' "  N = " %12.0fc `n3'
di "Spec 4 (pooled ln, comparison):      b = " %7.4f `b4' "  se = " %7.4f `se4' "  p = " %6.4f `p4' "  N = " %12.0fc `n4'
di "Spec 5 (raw rate / 100):             b = " %7.4f `b5' "  se = " %7.4f `se5' "  p = " %6.4f `p5' "  N = " %12.0fc `n5'
di "Spec 6 (std count, not per capita):  b = " %7.4f `b6' "  se = " %7.4f `se6' "  p = " %6.4f `p6' "  N = " %12.0fc `n6'
di "Spec 7 (ln raw count):              b = " %7.4f `b7' "  se = " %7.4f `se7' "  p = " %6.4f `p7' "  N = " %12.0fc `n7'
di "Spec 8 (ln raw count + ln pop):     b = " %7.4f `b8' "  se = " %7.4f `se8' "  p = " %6.4f `p8' "  N = " %12.0fc `n8'
di ""
di "Wave-specific (std count, NOT per capita):"
di "  1982:  b = " %7.4f `b9a' "  se = " %7.4f `se9a' "  p = " %6.4f `p9a' "  N = " %12.0fc `n9a'
di "  1990:  b = " %7.4f `b9b' "  se = " %7.4f `se9b' "  p = " %6.4f `p9b' "  N = " %12.0fc `n9b'
di "  2000:  b = " %7.4f `b9c' "  se = " %7.4f `se9c' "  p = " %6.4f `p9c' "  N = " %12.0fc `n9c'
di ""
di "Wave-specific (std rate, per capita):"
di "  1982:  b = " %7.4f `b6a' "  se = " %7.4f `se6a' "  p = " %6.4f `p6a' "  N = " %12.0fc `n6a'
di "  1990:  b = " %7.4f `b6b' "  se = " %7.4f `se6b' "  p = " %6.4f `p6b' "  N = " %12.0fc `n6b'
di "  2000:  b = " %7.4f `b6c' "  se = " %7.4f `se6c' "  p = " %6.4f `p6c' "  N = " %12.0fc `n6c'

exit, clear
