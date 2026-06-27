*****************************************************************
* check_ipums_baseline_v1.do
* Baseline pooled DID on the new IPUMS master, 1940 cutoff.
* Mirrors paper Table tab:main_eduy_cutoff1940 (pooled_baseline_main_v1.tex):
*   Y = b*(Post x X) + minority + county FE + birth-year FE + wave FE,
*   SE clustered at county. Birth cohorts 1920-1956, drop 1939.
*****************************************************************
clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which reghdfe
if _rc ssc install reghdfe, replace
capture which ftools
if _rc ssc install ftools, replace

use "${proj}/data/temp/master_pooled_ipums_v1.dta", clear
keep if inrange(birthyr, 1920, 1956)
drop if birthyr == 1939
gen byte post = birthyr >= 1940

di as txt "===== N and counties ====="
count
distinct countyid_curr6

* (1) binary high count
reghdfe eduy c.post#c.d_count_high minority, absorb(county_num birthyr wave) vce(cluster county_num)
* (2) binary high count + cohort size
reghdfe eduy c.post#c.d_count_high minority ln_cohort_n, absorb(county_num birthyr wave) vce(cluster county_num)
* (3) binary high rate
reghdfe eduy c.post#c.d_rate_high minority, absorb(county_num birthyr wave) vce(cluster county_num)
* (4) IHS count
reghdfe eduy c.post#c.ihs_count minority, absorb(county_num birthyr wave) vce(cluster county_num)
* (5) IHS count + cohort size
reghdfe eduy c.post#c.ihs_count minority ln_cohort_n, absorb(county_num birthyr wave) vce(cluster county_num)
* (6) IHS rate  <-- headline
reghdfe eduy c.post#c.ihs_rate minority, absorb(county_num birthyr wave) vce(cluster county_num)
* (7) ln(per 100k)
reghdfe eduy c.post#c.ln_martyr_per100k_1953 minority, absorb(county_num birthyr wave) vce(cluster county_num)

di as txt "===== BASELINE DONE ====="
