*******************************************************
* Postwar-main DID (v4)
* Main narrative: postwar institutional exposure
* Treatment intensity: native-place martyr counts (1931-1945)
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

use "${proj}/data/temp/did_1982_county_birthyr_martyr_hybrid_v3.dta", clear
keep if strict_share_wt >= 0.8

* Wider postwar windows for main narrative.
gen byte postwar_birth_wide = inrange(birthyr, 1946, 1960)
gen byte sample_postwar_birth_wide = inrange(birthyr, 1931, 1960)

gen byte postwar_schentry49_wide = inrange(birthyr, 1943, 1960)
gen byte sample_postwar_schentry49_wide = inrange(birthyr, 1928, 1960)

* 1) Main: postwar-school-entry (wide) with native-place treatment
preserve
keep if sample_postwar_schentry49_wide == 1
reghdfe eduy_wmean c.ln_martyr_native_count##i.postwar_schentry49_wide [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_post_main_w
restore

* 2) Alternative: postwar-birth (wide) with native-place treatment
preserve
keep if sample_postwar_birth_wide == 1
reghdfe eduy_wmean c.ln_martyr_native_count##i.postwar_birth_wide [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_post_alt_w
restore

* 3) Narrow-window replication: postwar-birth (1946-1955)
preserve
keep if sample_wartime_vs_post == 1
reghdfe eduy_wmean c.ln_martyr_native_count##i.postwar_birth [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_post_rep_b
restore

* 4) Narrow-window replication: postwar-school-entry (1943-1955)
preserve
keep if sample_postwar_schentry_49 == 1
reghdfe eduy_wmean c.ln_martyr_native_count##i.postwar_schentry_49 [aw=wt_sum], ///
    absorb(countyid_curr6 birthyr) vce(cluster countyid_curr6)
estimates store did_post_rep_s
restore

esttab did_post_main_w did_post_alt_w did_post_rep_b did_post_rep_s ///
    using "${proj}/result/table/did_postwar_main_v4.txt", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) compress ///
    title("Postwar-main DID (native-place treatment intensity)")

esttab did_post_main_w did_post_alt_w did_post_rep_b did_post_rep_s, ///
    se star(* 0.10 ** 0.05 *** 0.01) compress
