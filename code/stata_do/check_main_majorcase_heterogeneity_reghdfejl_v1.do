*******************************************************
* Major case heterogeneity (massacre exposure)
* Estimator: reghdfejl
* Heterogeneity: massacre_any (county-level)
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 {
    ssc install estout, replace
}

capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found. Please install reghdfejl first."
    exit 198
}

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death massacre_any
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
drop if countyid_curr6=="" | countyid_curr6=="000000"
duplicates drop countyid_curr6, force

foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death massacre_any {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
replace massacre_any = (massacre_event_w>0) if missing(massacre_any)

tempfile ctrl
save `ctrl'
global ctrl_tmp "`ctrl'"

capture program drop _run_wave_majorhet
program define _run_wave_majorhet, rclass
    syntax , WAVE(integer) HI(integer)

    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    keep if !missing(eduy_mean)
    drop if countyid_curr6=="" | countyid_curr6=="000000"

    merge m:1 countyid_curr6 using "$ctrl_tmp", keep(master match) nogen

    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
        ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
        massacre_event_w ln_massacre_death massacre_any {
        replace `v' = 0 if missing(`v')
    }
    replace massacre_any = (massacre_event_w>0) if missing(massacre_any)

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)
    gen prov = real(substr(countyid_curr6,1,2))
    egen prov_cohort = group(prov birth_i)

    egen base_edu_pre = mean(eduy_mean) if inrange(birth_i,1920,1938), by(county_num)
    egen __base_fill = max(base_edu_pre), by(county_num)
    replace base_edu_pre = __base_fill if missing(base_edu_pre)
    quietly summarize base_edu_pre
    replace base_edu_pre = r(mean) if missing(base_edu_pre)
    drop __base_fill

    quietly count
    return scalar n_cells = r(N)
    egen __tagc = tag(county_num)
    quietly count if __tagc==1
    local n_counties = r(N)
    return scalar n_counties = r(N)
    drop __tagc

    // main_majorcase_heterogeneity
    reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post##i.massacre_any, ///
        absorb(county_num prov_cohort c.base_edu_pre#i.birth_i) vce(cluster county_num)
    estimates store m`wave'_s1
    estadd local FullControls "N"
    estadd local County_FE "Y"
    estadd local ProvCohort_FE "Y"
    estadd local BaseEduCohort "Y"
    estadd scalar N_counties = `n_counties'
    return scalar b_base1 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se_base1 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p_base1 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
    return scalar b_diff1 = _b[1.massacre_any#1.post#c.ln_martyr_per100k_1953]
    return scalar se_diff1 = _se[1.massacre_any#1.post#c.ln_martyr_per100k_1953]
    return scalar p_diff1 = 2*ttail(e(df_r), abs(_b[1.massacre_any#1.post#c.ln_martyr_per100k_1953]/_se[1.massacre_any#1.post#c.ln_martyr_per100k_1953]))
    quietly lincom 1.post#c.ln_martyr_per100k_1953 + 1.massacre_any#1.post#c.ln_martyr_per100k_1953
    return scalar b_high1 = r(estimate)
    return scalar se_high1 = r(se)
    return scalar p_high1 = r(p)

    reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post##i.massacre_any ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
        absorb(county_num prov_cohort c.base_edu_pre#i.birth_i) vce(cluster county_num)
    estimates store m`wave'_s2
    estadd local FullControls "Y"
    estadd local County_FE "Y"
    estadd local ProvCohort_FE "Y"
    estadd local BaseEduCohort "Y"
    estadd scalar N_counties = `n_counties'
    return scalar b_base2 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se_base2 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p_base2 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
    return scalar b_diff2 = _b[1.massacre_any#1.post#c.ln_martyr_per100k_1953]
    return scalar se_diff2 = _se[1.massacre_any#1.post#c.ln_martyr_per100k_1953]
    return scalar p_diff2 = 2*ttail(e(df_r), abs(_b[1.massacre_any#1.post#c.ln_martyr_per100k_1953]/_se[1.massacre_any#1.post#c.ln_martyr_per100k_1953]))
    quietly lincom 1.post#c.ln_martyr_per100k_1953 + 1.massacre_any#1.post#c.ln_martyr_per100k_1953
    return scalar b_high2 = r(estimate)
    return scalar se_high2 = r(se)
    return scalar p_high2 = r(p)
end

eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str24 spec = ""
gen b_base = .
gen se_base = .
gen p_base = .
gen b_diff = .
gen se_diff = .
gen p_diff = .
gen b_high = .
gen se_high = .
gen p_high = .
gen n_cells = .
gen n_counties = .
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'" == "1990" local hi = 1968
    if "`w'" == "2000" local hi = 1978

    quietly _run_wave_majorhet, wave(`w') hi(`hi')

    foreach s in 1 2 {
        use `summary', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        if `s'==1 replace spec = "S1 baseline" in `n'
        if `s'==2 replace spec = "S2 + full controls" in `n'
        replace b_base = r(b_base`s') in `n'
        replace se_base = r(se_base`s') in `n'
        replace p_base = r(p_base`s') in `n'
        replace b_diff = r(b_diff`s') in `n'
        replace se_diff = r(se_diff`s') in `n'
        replace p_diff = r(p_diff`s') in `n'
        replace b_high = r(b_high`s') in `n'
        replace se_high = r(se_high`s') in `n'
        replace p_high = r(p_high`s') in `n'
        replace n_cells = r(n_cells) in `n'
        replace n_counties = r(n_counties) in `n'
        save `summary', replace
    }
}

use `summary', clear
sort wave spec
export delimited using "${proj}/result/table/main_majorcase_heterogeneity_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_majorcase_heterogeneity_reghdfejl_summary_v1.dta", replace

esttab m1982_s1 m1982_s2 m1990_s1 m1990_s2 m2000_s1 m2000_s2 ///
    using "${proj}/result/table/main_majorcase_heterogeneity_reghdfejl_v1.rtf", ///
    replace ///
    keep(*post#c.ln_martyr_per100k_1953*) ///
    scalar(FullControls County_FE ProvCohort_FE BaseEduCohort N_counties) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab m1982_s1 m1982_s2 m1990_s1 m1990_s2 m2000_s1 m2000_s2 ///
    using "${proj}/result/table/main_majorcase_heterogeneity_reghdfejl_v1.tex", ///
    replace ///
    keep(*post#c.ln_martyr_per100k_1953*) ///
    scalar(FullControls County_FE ProvCohort_FE BaseEduCohort N_counties) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
