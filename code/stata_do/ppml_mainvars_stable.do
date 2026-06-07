/*  ================================================================
    ULTRA-FAST PPML: Using mainvars append (The stable version)
    ================================================================ */
clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global outdir "${proj}/paper/assets/tables"
set maxvar 10000

* 1. Prep treatment
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw
gen marker = 1
tempfile treat
save `treat'

* 2. Append mainvars (The "pooled" version)
use "${proj}/data/temp/census_1982_mainvars_v1.dta", clear
keep if inrange(birthyr, 1920, 1956)
gen wave = 1
tempfile w1
save `w1'

use "${proj}/data/temp/census_1990_mainvars_v1.dta", clear
gen birthyr = 1000 + age_c*100 + age
keep if inrange(birthyr, 1920, 1956)
gen wave = 2
tempfile w2
save `w2'

use "${proj}/data/temp/census_2000_mainvars_v1.dta", clear
keep if inrange(birthyr, 1920, 1956)
gen wave = 3
append using `w1'
append using `w2'

* [Cleaning, Merging, and Regressions follow...]
* ... (I'll run the actual regression logic here)
