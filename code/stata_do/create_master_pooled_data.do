/*  ================================================================
    MASTER POOLED DATA CREATION (Optimized for PPML)
    - Pools 1982, 1990, 2000 Censuses
    - Merges treatment and historical controls
    - Includes heterogeneity indicators (female, base education)
    - Saves to a permanent master file
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 "${proj}/data/raw/census/census1990.dta"
global c2000 "${proj}/data/raw/census/census2000.dta"
global out_master "${proj}/data/temp/master_pooled_ppml_v1.dta"

*--------------------------------------------------------------
* 1. Treatment + Controls Preparation
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw pop_1953

gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
summ martyr_per100k_1953, detail
gen d_rate_high = (martyr_per100k_1953 > r(p50)) if !missing(martyr_per100k_1953)

rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6

/* historical controls */
merge 1:1 countyid_curr6 using "${proj}/data/temp/county_controls_full_v1.dta", keep(master match) nogen
merge 1:1 countyid_curr6 using "${proj}/data/temp/revolutionary_proxy_controls_v1.dta", keep(master match) nogen

gen ln_victims_cr = ln(1 + victims_cr) if !missing(victims_cr)
gen ln_grain_output = ln(1 + grain_output) if !missing(grain_output)
gen ihs_longmarch = ln(longmarch_martyr_per100k + sqrt(longmarch_martyr_per100k^2 + 1)) if !missing(longmarch_martyr_per100k)
gen ihs_korea     = ln(korea_war_martyr_per100k + sqrt(korea_war_martyr_per100k^2 + 1)) if !missing(korea_war_martyr_per100k)

foreach v in sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 ihs_longmarch ihs_korea {
    replace `v' = 0 if missing(`v')
}

tempfile treat_with_ctrls
save `treat_with_ctrls'
global treat_tmp "`treat_with_ctrls'"

*--------------------------------------------------------------
* 2. Administrative Mapping boilerplate
*--------------------------------------------------------------
import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
keep GBCounty
destring GBCounty, replace force
gen str6 county_curr6 = string(GBCounty, "%06.0f")
gen str6 old6 = county_curr6
gen str6 curr_dict = county_curr6
keep old6 curr_dict
duplicates drop old6, force
tempfile county_dict
save `county_dict'

import delimited "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", clear varnames(1) stringcols(_all)
rename countyid_old6 old6
rename countyid_curr6_final county_curr6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = subinstr(county_curr6, ".0", "", .)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
duplicates drop old6, force
tempfile cw1982
save `cw1982'

capture program drop _resolve_map
program define _resolve_map
    args infile outfile wave
    use `infile', clear
    if "`wave'" == "1982" {
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using `cw1982', keep(master match) nogen
    }
    if "`wave'" == "1990" {
        gen str6 old6 = string(county, "%06.0f")
    }
    if "`wave'" == "2000" {
        gen str6 old6 = string(uid, "%06.0f")
    }
    
    gen str6 curr_res = county_curr6
    capture merge m:1 old6 using `county_dict', keep(master match) nogen keepusing(curr_dict)
    replace curr_res = curr_dict if curr_res=="" & curr_dict!=""
    drop if curr_res==""
    rename curr_res countyid_curr6
    save `outfile', replace
end

*--------------------------------------------------------------
* 3. Loading Waves
*--------------------------------------------------------------
/* 1982 */
use countyid birthyr eduy ethniccn using "$c1982", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using `cw1982', keep(match) nogen
gen minority = (ethniccn != 1) if !missing(ethniccn)
gen female = .
rename county_curr6 countyid_curr6
keep if inrange(birthyr, 1920, 1956)
gen wave = 1
tempfile w1
save `w1'

/* 1990 */
use county age_c age educ race sex using "$c1990", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using `county_dict', keep(match) nogen keepusing(curr_dict)
rename curr_dict countyid_curr6
gen birthyr = 1000 + age_c*100 + age
gen eduy = .
replace eduy = 0  if educ==1
replace eduy = 6  if educ==2
replace eduy = 9  if educ==3
replace eduy = 12 if inlist(educ,4,5)
replace eduy = 15 if educ==6
replace eduy = 16 if educ==7
gen minority = (race != 1) if !missing(race)
gen female = (sex == 2) if !missing(sex)
keep if inrange(birthyr, 1920, 1956)
gen wave = 2
tempfile w2
save `w2'

/* 2000 */
use uid birthyr eduyr sex race using "$c2000", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using `county_dict', keep(match) nogen keepusing(curr_dict)
rename curr_dict countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
gen female = (sex == 2) if !missing(sex)
keep if inrange(birthyr, 1920, 1956)
gen wave = 3
tempfile w3
save `w3'

*--------------------------------------------------------------
* 4. Pool & Finalize
*--------------------------------------------------------------
use `w1', clear
append using `w2'
append using `w3'

summ eduy, detail
replace eduy = r(p1) if eduy < r(p1)
replace eduy = r(p99) if eduy > r(p99) & !missing(eduy)

merge m:1 countyid_curr6 using `treat_with_ctrls', keep(match) nogen

gen birth_i = floor(birthyr)
encode countyid_curr6, gen(county_num)
bysort county_num birth_i wave: gen cohort_n = _N
gen ln_cohort_n = ln(cohort_n)

/* Base education for heterogeneity */
bysort countyid_curr6: egen base_edu = mean(cond(birthyr < 1940, eduy, .))
summ base_edu, detail
gen high_base_edu = (base_edu > r(p50)) if !missing(base_edu)

save "$out_master", replace
di "=== MASTER POOLED DATA SAVED TO $out_master ==="
