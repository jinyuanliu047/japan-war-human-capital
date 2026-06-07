*******************************************************
* DID: Martyr intensity (sacrifice place) and education
* v2 data with old->current county harmonization
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

use "${proj}/data/temp/did_1982_county_birthyr_martyr_sacrifice_v2.dta", clear

* ------------------------------
* Baseline: school-age exposure to war (1925-1939 birth)
* sample: 1915-1950 birth cohorts
* ------------------------------
preserve
keep if sample_schoolage_did == 1
keep if strict_share_wt >= 0.8
reghdfe eduy_wmean c.ln_martyr_sacrifice_count##i.schoolage_war [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_schoolage_sacrifice
restore

* Robustness 1: wartime birth cohort (1931-1945)
preserve
keep if sample_war_birth_vs_pre == 1
reghdfe eduy_wmean c.ln_martyr_sacrifice_count##i.wartime_birth [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_wartime_sacrifice
restore

* Robustness 2: postwar birth cohort (1946-1955)
preserve
keep if sample_wartime_vs_post == 1
reghdfe eduy_wmean c.ln_martyr_sacrifice_count##i.postwar_birth [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_postwar_sacrifice
restore

esttab did_schoolage_sacrifice did_wartime_sacrifice did_postwar_sacrifice, ///
    se star(* 0.10 ** 0.05 *** 0.01) compress
