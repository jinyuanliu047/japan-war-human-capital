*******************************************************
* DID: Martyr intensity (native place) and education
* v2 data with old->current county harmonization
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

use "${proj}/data/temp/did_1982_county_birthyr_martyr_native_v2.dta", clear

* Optional package install (run once)
* ssc install ftools, replace
* ssc install reghdfe, replace
* ssc install estout, replace

* ------------------------------
* Baseline: school-age exposure to war (1922-1938 birth)
* sample: 1910-1950 birth cohorts
* Keep higher-quality mapped cells first (strict share >= 0.8)
* ------------------------------
preserve
keep if sample_schoolage_did == 1
keep if strict_share_wt >= 0.8

reghdfe eduy_wmean c.ln_martyr_native_count##i.schoolage_war [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_schoolage_strict
restore

* Full sample counterpart (including fallback harmonization)
preserve
keep if sample_schoolage_did == 1
reghdfe eduy_wmean c.ln_martyr_native_count##i.schoolage_war [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_schoolage_full
restore

* ------------------------------
* Robustness 1: wartime-birth cohort (1931-1945) vs earlier cohorts
* ------------------------------
preserve
keep if sample_war_birth_vs_pre == 1
reghdfe eduy_wmean c.ln_martyr_native_count##i.wartime_birth [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_wartime_birth
restore

* ------------------------------
* Robustness 2: postwar-birth cohort (1946-1955) in wartime+postwar window
* ------------------------------
preserve
keep if sample_wartime_vs_post == 1
reghdfe eduy_wmean c.ln_martyr_native_count##i.postwar_birth [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_postwar_birth
restore

esttab did_schoolage_strict did_schoolage_full did_wartime_birth did_postwar_birth, ///
    se star(* 0.10 ** 0.05 *** 0.01) compress
