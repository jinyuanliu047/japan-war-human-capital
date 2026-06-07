*******************************************************
* Robustness: include relocation as additional control
* Control term: reloc_any#post
* Estimator: reghdfejl
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
    di as error "reghdfejl not found"
    exit 198
}

use "${proj}/data/temp/county_university_relocation_any_v1.dta", clear
keep countyid_curr6 reloc_any
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
replace reloc_any = 0 if missing(reloc_any)
duplicates drop countyid_curr6, force
tempfile reloc
save `reloc'
global reloc_tmp "`reloc'"

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop countyid_curr6, force
tempfile ctrl
save `ctrl'
global ctrl_tmp "`ctrl'"

capture program drop _run_wave
program define _run_wave, rclass
    syntax , WAVE(integer) HI(integer)

    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr,1920,`hi')
    drop if floor(birthyr)==1939
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="" | countyid_curr6=="000000"

    merge m:1 countyid_curr6 using "$reloc_tmp", keep(master match) nogen
    replace reloc_any = 0 if missing(reloc_any)
    merge m:1 countyid_curr6 using "$ctrl_tmp", keep(master match) nogen

    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
        ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
        massacre_event_w ln_massacre_death {
        replace `v' = 0 if missing(`v')
    }

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)

    quietly count
    return scalar n_cells = r(N)

    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store rc`wave'_s1
    estadd local RelocPostCtrl "N"
    estadd local FullControls "N"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    return scalar b1 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se1 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p1 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))

    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post c.reloc_any#c.post, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store rc`wave'_s2
    estadd local RelocPostCtrl "Y"
    estadd local FullControls "N"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    return scalar b2 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se2 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p2 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))

    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store rc`wave'_s3
    estadd local RelocPostCtrl "N"
    estadd local FullControls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    return scalar b3 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se3 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p3 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))

    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post c.reloc_any#c.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store rc`wave'_s4
    estadd local RelocPostCtrl "Y"
    estadd local FullControls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    return scalar b4 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se4 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p4 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
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
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978
    quietly _run_wave, wave(`w') hi(`hi')

    foreach s in 1 2 3 4 {
        use `summary', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        if `s'==1 replace spec = "S1 baseline" in `n'
        if `s'==2 replace spec = "S2 + reloc#post" in `n'
        if `s'==3 replace spec = "S3 + full controls" in `n'
        if `s'==4 replace spec = "S4 + full + reloc#post" in `n'
        replace b = r(b`s') in `n'
        replace se = r(se`s') in `n'
        replace p = r(p`s') in `n'
        replace n_cells = r(n_cells) in `n'
        save `summary', replace
    }
}

use `summary', clear
sort wave spec
export delimited using "${proj}/result/table/main_reloc_as_control_robustness_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_reloc_as_control_robustness_reghdfejl_summary_v1.dta", replace

esttab rc1982_s1 rc1982_s2 rc1982_s3 rc1982_s4 ///
       rc1990_s1 rc1990_s2 rc1990_s3 rc1990_s4 ///
       rc2000_s1 rc2000_s2 rc2000_s3 rc2000_s4 ///
    using "${proj}/result/table/main_reloc_as_control_robustness_reghdfejl_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(RelocPostCtrl FullControls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab rc1982_s1 rc1982_s2 rc1982_s3 rc1982_s4 ///
       rc1990_s1 rc1990_s2 rc1990_s3 rc1990_s4 ///
       rc2000_s1 rc2000_s2 rc2000_s3 rc2000_s4 ///
    using "${proj}/result/table/main_reloc_as_control_robustness_reghdfejl_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(RelocPostCtrl FullControls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
