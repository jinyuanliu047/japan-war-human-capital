*******************************************************
* Extended robustness (fast version)
* Data: county-birth panels (unweighted eduy mean)
* FE: county FE + province x cohort FE + base-edu x cohort
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 {
    ssc install estout, replace
}

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ///
    ln_memorial_cnt massacre_event_w ln_massacre_death
duplicates drop countyid_curr6, force
tempfile county_ctrl
save `county_ctrl'
global county_ctrl_tmp "`county_ctrl'"

capture program drop _run_wave_fast2
program define _run_wave_fast2, rclass
    syntax , WAVE(integer) HI(integer)

    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr) == 1939
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="000000"

    merge m:1 countyid_curr6 using "$county_ctrl_tmp", keep(master match) nogen
    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
        ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt massacre_event_w ln_massacre_death {
        replace `v' = 0 if missing(`v')
    }

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)
    gen prov = real(substr(countyid_curr6,1,2))
    egen prov_cohort = group(prov birth_i)

    egen base_edu_pre = mean(eduy_mean) if inrange(birth_i,1920,1938), by(county_num)
    egen base_edu_pre_all = max(base_edu_pre), by(county_num)
    replace base_edu_pre = base_edu_pre_all if missing(base_edu_pre)
    quietly summarize base_edu_pre
    replace base_edu_pre = r(mean) if missing(base_edu_pre)
    drop base_edu_pre_all

    quietly count
    return scalar n_cells = r(N)
    egen __tagc = tag(county_num)
    quietly count if __tagc==1
    local n_counties = r(N)
    return scalar n_counties = r(N)
    drop __tagc

    // main_extended_fast
    quietly areg eduy_mean c.ln_martyr_per100k_1953##ib0.post i.prov_cohort c.base_edu_pre#i.birth_i, ///
        absorb(county_num) vce(cluster county_num)
    estimates store fx`wave'_s1
    estadd local AER_Post "N"
    estadd local Conflict_Post "N"
    estadd local County_FE "Y"
    estadd local ProvCohort_FE "Y"
    estadd local BaseEduCohort "Y"
    estadd scalar N_counties = `n_counties'
    return scalar b1 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se1 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p1 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))

    quietly areg eduy_mean c.ln_martyr_per100k_1953##ib0.post i.prov_cohort c.base_edu_pre#i.birth_i ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post, ///
        absorb(county_num) vce(cluster county_num)
    estimates store fx`wave'_s2
    estadd local AER_Post "Y"
    estadd local Conflict_Post "N"
    estadd local County_FE "Y"
    estadd local ProvCohort_FE "Y"
    estadd local BaseEduCohort "Y"
    estadd scalar N_counties = `n_counties'
    return scalar b2 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se2 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p2 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))

    quietly areg eduy_mean c.ln_martyr_per100k_1953##ib0.post i.prov_cohort c.base_edu_pre#i.birth_i ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
        absorb(county_num) vce(cluster county_num)
    estimates store fx`wave'_s3
    estadd local AER_Post "N"
    estadd local Conflict_Post "Y"
    estadd local County_FE "Y"
    estadd local ProvCohort_FE "Y"
    estadd local BaseEduCohort "Y"
    estadd scalar N_counties = `n_counties'
    return scalar b3 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se3 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p3 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))

    quietly areg eduy_mean c.ln_martyr_per100k_1953##ib0.post i.prov_cohort c.base_edu_pre#i.birth_i ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
        absorb(county_num) vce(cluster county_num)
    estimates store fx`wave'_s4
    estadd local AER_Post "Y"
    estadd local Conflict_Post "Y"
    estadd local County_FE "Y"
    estadd local ProvCohort_FE "Y"
    estadd local BaseEduCohort "Y"
    estadd scalar N_counties = `n_counties'
    return scalar b4 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se4 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p4 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))
end

eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str28 spec = ""
gen b = .
gen se = .
gen p = .
gen n_cells = .
gen n_counties = .
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'" == "1990" local hi = 1968
    if "`w'" == "2000" local hi = 1978

    quietly _run_wave_fast2, wave(`w') hi(`hi')

    foreach s in 1 2 3 4 {
        use `summary', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        if `s' == 1 replace spec = "S1 baseline" in `n'
        if `s' == 2 replace spec = "S2 + AER#post" in `n'
        if `s' == 3 replace spec = "S3 + conflict#post" in `n'
        if `s' == 4 replace spec = "S4 + full controls" in `n'
        replace b = r(b`s') in `n'
        replace se = r(se`s') in `n'
        replace p = r(p`s') in `n'
        replace n_cells = r(n_cells) in `n'
        replace n_counties = r(n_counties) in `n'
        save `summary', replace
    }
}

use `summary', clear
gen t_abs = abs(b/se)
gsort wave -t_abs
export delimited using "${proj}/result/table/main_extended_robustness_fast_summary_v2.csv", replace
save "${proj}/result/table/main_extended_robustness_fast_summary_v2.dta", replace

esttab fx1982_s1 fx1982_s2 fx1982_s3 fx1982_s4 ///
       fx1990_s1 fx1990_s2 fx1990_s3 fx1990_s4 ///
       fx2000_s1 fx2000_s2 fx2000_s3 fx2000_s4 ///
       using "${proj}/result/table/main_extended_robustness_fast_v2.rtf", ///
       replace ///
       keep(1.post#c.ln_martyr_per100k_1953) ///
       scalar(AER_Post Conflict_Post County_FE ProvCohort_FE BaseEduCohort N_counties) ///
       se r2 ar2 ///
       star(* 0.1 ** 0.05 *** 0.01)

esttab fx1982_s1 fx1982_s2 fx1982_s3 fx1982_s4 ///
       fx1990_s1 fx1990_s2 fx1990_s3 fx1990_s4 ///
       fx2000_s1 fx2000_s2 fx2000_s3 fx2000_s4 ///
       using "${proj}/result/table/main_extended_robustness_fast_v2.tex", ///
       replace ///
       keep(1.post#c.ln_martyr_per100k_1953) ///
       scalar(AER_Post Conflict_Post County_FE ProvCohort_FE BaseEduCohort N_counties) ///
       se r2 ar2 ///
       star(* 0.1 ** 0.05 *** 0.01)

exit, clear
