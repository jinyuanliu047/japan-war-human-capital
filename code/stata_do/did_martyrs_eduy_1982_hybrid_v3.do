*******************************************************
* Hybrid DID:
* - schoolage/wartime use sacrifice-place intensity
* - postwar uses native-place intensity
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

use "${proj}/data/temp/did_1982_county_birthyr_martyr_hybrid_v3.dta", clear

* 1) School-age DID (sacrifice treatment)
preserve
keep if sample_schoolage_did == 1
keep if strict_share_wt >= 0.8
reghdfe eduy_wmean c.ln_martyr_sacrifice_count##i.schoolage_war [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_school_sac
restore

* 2) Wartime-birth DID (sacrifice treatment)
preserve
keep if sample_war_birth_vs_pre == 1
reghdfe eduy_wmean c.ln_martyr_sacrifice_count##i.wartime_birth [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_war_sac
restore

* 3) Postwar-birth DID (native treatment) - baseline
preserve
keep if sample_wartime_vs_post == 1
reghdfe eduy_wmean c.ln_martyr_native_count##i.postwar_birth [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_post_native_birth
restore

* 4) Postwar-school-entry DID (native treatment) - alternative
preserve
keep if sample_postwar_schentry_49 == 1
reghdfe eduy_wmean c.ln_martyr_native_count##i.postwar_schentry_49 [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_post_native_schentry49
restore

esttab did_school_sac did_war_sac did_post_native_birth did_post_native_schentry49, ///
    se star(* 0.10 ** 0.05 *** 0.01) compress
