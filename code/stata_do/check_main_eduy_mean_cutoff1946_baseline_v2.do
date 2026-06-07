*******************************************************
* Main county-cohort eduy_mean regressions
* Correct historical panels with pre-1946 cohorts
* Treat starts in 1946, drop 1945
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

tempfile ctrl
use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64
duplicates drop countyid_curr6, force
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
save `ctrl'

tempname memhold
postfile `memhold' str4 wave double b se p N r2 ar2 using "${proj}/result/table/main_eduy_mean_cutoff1946_baseline_v2_tmp.dta", replace

foreach wave in 1982 1990 2000 {
    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep countyid_curr6 birthyr eduy_mean ln_martyr_per100k_1953 n_obs
    keep if inrange(birthyr, 1920, cond(`wave'==1982, 1960, cond(`wave'==1990, 1968, 1978)))
    drop if floor(birthyr) == 1945
    gen birth_i = floor(birthyr)
    merge m:1 countyid_curr6 using `ctrl', keep(master match) nogen
    gen post = birth_i >= 1946
    egen county_num = group(countyid_curr6)
    reghdfejl eduy_mean c.ln_martyr_per100k_1953##i.post [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store model`wave'
    post `memhold' ("`wave'") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
        (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) ///
        (e(N)) (e(r2)) (e(r2_a))
}

esttab model1982 model1990 model2000 using "${proj}/result/table/main_eduy_mean_cutoff1946_baseline_v2.tex", ///
    replace booktabs nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982" "1990" "2000") ///
    stats(N r2 ar2, labels("Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

postclose `memhold'
use "${proj}/result/table/main_eduy_mean_cutoff1946_baseline_v2_tmp.dta", clear
export delimited using "${proj}/result/table/main_eduy_mean_cutoff1946_baseline_v2.csv", replace
erase "${proj}/result/table/main_eduy_mean_cutoff1946_baseline_v2_tmp.dta"

exit, clear
