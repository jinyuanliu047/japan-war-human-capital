*******************************************************
* DID: Martyr intensity (native place) and education
* Input:
*   data/temp/did_1982_county_birthyr_martyr_native.dta
* Output:
*   baseline and robustness regressions
*******************************************************

clear all
set more off

* Adjust this to your local project path if needed
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

use "${proj}/data/temp/did_1982_county_birthyr_martyr_native.dta", clear

* Optional: install reghdfe/ftools if missing
* ssc install ftools, replace
* ssc install reghdfe, replace

* Recommended baseline:
* Compare cohorts 1915-1937, with school-age-during-war cohort = 1 for 1926-1937
keep if sample_schoolage_did == 1

* Weighted cell regression (county FE + birthyear FE)
reghdfe eduy_wmean c.ln_martyr_native_count##i.schoolage_war [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_base

* Robustness 1:
* wartime birth cohort (1931-1945) in a broader window
preserve
use "${proj}/data/temp/did_1982_county_birthyr_martyr_native.dta", clear
keep if inrange(birthyr,1916,1945)
reghdfe eduy_wmean c.ln_martyr_native_count##i.wartime_birth [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_wartime
restore

* Robustness 2:
* postwar cohort (1946-1955) versus wartime cohort period window
preserve
use "${proj}/data/temp/did_1982_county_birthyr_martyr_native.dta", clear
keep if sample_wartime_vs_post == 1
reghdfe eduy_wmean c.ln_martyr_native_count##i.postwar_birth [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_postwar
restore

esttab did_base did_wartime did_postwar, se star(* 0.10 ** 0.05 *** 0.01) compress

