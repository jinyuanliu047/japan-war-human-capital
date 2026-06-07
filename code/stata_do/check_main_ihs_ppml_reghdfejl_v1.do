*******************************************************
* Main spec robustness: IHS(X) and PPML
* Y: eduy_mean (county-by-birth cohort mean)
* Estimators: reghdfe / ppmlhdfe
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/county_controls_full_v1.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 {
    ssc install estout, replace
}

capture which reghdfe
if _rc != 0 {
    ssc install reghdfe, replace
}

capture which ppmlhdfe
if _rc != 0 {
    ssc install ppmlhdfe, replace
}

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
drop if countyid_curr6=="" | countyid_curr6=="000000"
duplicates drop countyid_curr6, force

foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)

tempfile ctrl
save `ctrl'
global ctrl_tmp "`ctrl'"

capture program drop _run_wave_ihs_ppml
program define _run_wave_ihs_ppml, rclass
    syntax , WAVE(integer) HI(integer)

    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    keep if !missing(eduy_mean)
    drop if countyid_curr6=="" | countyid_curr6=="000000"

    merge m:1 countyid_curr6 using "$ctrl_tmp", keep(master match) nogen

    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
        ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
        massacre_event_w ln_massacre_death {
        replace `v' = 0 if missing(`v')
    }

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    gen ihs_martyr_per100k_1953 = asinh(martyr_per100k_1953)
    egen county_num = group(countyid_curr6)
    quietly count
    return scalar n_cells = r(N)
    egen __tagc = tag(county_num)
    quietly count if __tagc==1
    local n_counties = r(N)
    return scalar n_counties = r(N)
    drop __tagc

    // main_ihs_ppml
    quietly reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store olsln`wave'
    estadd local Estimator "reghdfe"
    estadd local XForm "ln"
    estadd scalar N_counties = `n_counties'
    return scalar b1 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se1 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p1 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))

    quietly reghdfe eduy_mean c.ihs_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store olsihs`wave'
    estadd local Estimator "reghdfe"
    estadd local XForm "ihs"
    estadd scalar N_counties = `n_counties'
    return scalar b2 = _b[1.post#c.ihs_martyr_per100k_1953]
    return scalar se2 = _se[1.post#c.ihs_martyr_per100k_1953]
    return scalar p2 = 2*ttail(e(df_r), abs(_b[1.post#c.ihs_martyr_per100k_1953]/_se[1.post#c.ihs_martyr_per100k_1953]))

    quietly ppmlhdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
        absorb(county_num birth_i) cluster(county_num)
    estimates store ppmlln`wave'
    estadd local Estimator "ppmlhdfe"
    estadd local XForm "ln"
    estadd scalar N_counties = `n_counties'
    return scalar b3 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se3 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p3 = 2*normal(-abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))

    quietly ppmlhdfe eduy_mean c.ihs_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
        absorb(county_num birth_i) cluster(county_num)
    estimates store ppmlihs`wave'
    estadd local Estimator "ppmlhdfe"
    estadd local XForm "ihs"
    estadd scalar N_counties = `n_counties'
    return scalar b4 = _b[1.post#c.ihs_martyr_per100k_1953]
    return scalar se4 = _se[1.post#c.ihs_martyr_per100k_1953]
    return scalar p4 = 2*normal(-abs(_b[1.post#c.ihs_martyr_per100k_1953]/_se[1.post#c.ihs_martyr_per100k_1953]))
end

eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str20 estimator = ""
gen str8 xform = ""
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

    quietly _run_wave_ihs_ppml, wave(`w') hi(`hi')

    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace estimator = "reghdfe" in `n'
    replace xform = "ln" in `n'
    replace b = r(b1) in `n'
    replace se = r(se1) in `n'
    replace p = r(p1) in `n'
    replace n_cells = r(n_cells) in `n'
    replace n_counties = r(n_counties) in `n'
    save `summary', replace

    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace estimator = "reghdfe" in `n'
    replace xform = "ihs" in `n'
    replace b = r(b2) in `n'
    replace se = r(se2) in `n'
    replace p = r(p2) in `n'
    replace n_cells = r(n_cells) in `n'
    replace n_counties = r(n_counties) in `n'
    save `summary', replace

    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace estimator = "ppmlhdfe" in `n'
    replace xform = "ln" in `n'
    replace b = r(b3) in `n'
    replace se = r(se3) in `n'
    replace p = r(p3) in `n'
    replace n_cells = r(n_cells) in `n'
    replace n_counties = r(n_counties) in `n'
    save `summary', replace

    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace estimator = "ppmlhdfe" in `n'
    replace xform = "ihs" in `n'
    replace b = r(b4) in `n'
    replace se = r(se4) in `n'
    replace p = r(p4) in `n'
    replace n_cells = r(n_cells) in `n'
    replace n_counties = r(n_counties) in `n'
    save `summary', replace
}

use `summary', clear
sort wave estimator xform
export delimited using "${proj}/result/table/main_ihs_ppml_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_ihs_ppml_reghdfejl_summary_v1.dta", replace

esttab olsln1982 olsihs1982 ppmlln1982 ppmlihs1982 ///
       olsln1990 olsihs1990 ppmlln1990 ppmlihs1990 ///
       olsln2000 olsihs2000 ppmlln2000 ppmlihs2000 ///
    using "${proj}/result/table/main_ihs_ppml_reghdfejl_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953 1.post#c.ihs_martyr_per100k_1953) ///
    scalar(Estimator XForm N_counties) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab olsln1982 olsihs1982 ppmlln1982 ppmlihs1982 ///
       olsln1990 olsihs1990 ppmlln1990 ppmlihs1990 ///
       olsln2000 olsihs2000 ppmlln2000 ppmlihs2000 ///
    using "${proj}/result/table/main_ihs_ppml_reghdfejl_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953 1.post#c.ihs_martyr_per100k_1953) ///
    scalar(Estimator XForm N_counties) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
