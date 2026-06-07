*******************************************************
* Main robustness: control for Long March / Korea-war proxies
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/county_controls_full_v1.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which reghdfe
if _rc != 0 {
    ssc install reghdfe, replace
}
capture which reghdfe
if _rc != 0 {
    di as error "reghdfe not found"
    exit 198
}
capture which esttab
if _rc != 0 ssc install estout, replace

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death
duplicates drop countyid_curr6, force
merge 1:1 countyid_curr6 using "${proj}/data/temp/revolutionary_proxy_controls_v1.dta", keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death ln_korea_war_martyr_count ln_longmarch_martyr_count {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
tempfile ctrl
save `ctrl'
global longk_ctrl_tmp "`ctrl'"

capture program drop _run_wave
program define _run_wave, rclass
    syntax , WAVE(integer) HI(integer)
    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    gen birth_i = floor(birthyr)
    gen post = birth_i>=1940
    egen county_num = group(countyid_curr6)
    merge m:1 countyid_curr6 using "$longk_ctrl_tmp", keep(master match) nogen
    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
        ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
        massacre_event_w ln_massacre_death ln_korea_war_martyr_count ln_longmarch_martyr_count {
        replace `v' = 0 if missing(`v')
    }
end

capture program drop _grab
program define _grab, rclass
    capture return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    capture return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    if _rc != 0 {
        return scalar b = _b[c.ln_martyr_per100k_1953#1.post]
        return scalar se = _se[c.ln_martyr_per100k_1953#1.post]
    }
    return scalar p = 2*ttail(e(df_r), abs(return(b)/return(se)))
end

eststo clear
tempfile summary
clear
set obs 0
gen wave = .
gen str12 spec = ""
gen b = .
gen se = .
gen p = .
save `summary', replace

local models ""
foreach w in 1982 1990 2000 {
    local hi = 1960
    if `w'==1990 local hi = 1968
    if `w'==2000 local hi = 1978
    quietly _run_wave, wave(`w') hi(`hi')

    quietly reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
        [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store base`w'
    quietly _grab
    use `summary', clear
    set obs `=_N+1'
    replace wave = `w' in L
    replace spec = "base" in L
    replace b = r(b) in L
    replace se = r(se) in L
    replace p = r(p) in L
    save `summary', replace

    quietly _run_wave, wave(`w') hi(`hi')
    quietly reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
        c.ln_longmarch_martyr_count#c.post ///
        [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store long`w'
    quietly _grab
    use `summary', clear
    set obs `=_N+1'
    replace wave = `w' in L
    replace spec = "longmarch" in L
    replace b = r(b) in L
    replace se = r(se) in L
    replace p = r(p) in L
    save `summary', replace

    quietly _run_wave, wave(`w') hi(`hi')
    quietly reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
        c.ln_korea_war_martyr_count#c.post ///
        [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store kor`w'
    quietly _grab
    use `summary', clear
    set obs `=_N+1'
    replace wave = `w' in L
    replace spec = "korea" in L
    replace b = r(b) in L
    replace se = r(se) in L
    replace p = r(p) in L
    save `summary', replace

    quietly _run_wave, wave(`w') hi(`hi')
    quietly reghdfe eduy_mean c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
        c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
        c.ln_longmarch_martyr_count#c.post c.ln_korea_war_martyr_count#c.post ///
        [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store both`w'
    quietly _grab
    use `summary', clear
    set obs `=_N+1'
    replace wave = `w' in L
    replace spec = "both" in L
    replace b = r(b) in L
    replace se = r(se) in L
    replace p = r(p) in L
    save `summary', replace
}

use `summary', clear
export delimited using "${proj}/result/table/main_longmarch_korea_robustness_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_longmarch_korea_robustness_reghdfejl_summary_v1.dta", replace

esttab base1982 long1982 kor1982 both1982 base1990 long1990 kor1990 both1990 base2000 long2000 kor2000 both2000 ///
    using "${proj}/result/table/main_longmarch_korea_robustness_reghdfejl_v1.rtf", replace ///
    keep(1.post#c.ln_martyr_per100k_1953 c.ln_longmarch_martyr_count#1.post c.ln_korea_war_martyr_count#1.post) ///
    se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab base1982 long1982 kor1982 both1982 base1990 long1990 kor1990 both1990 base2000 long2000 kor2000 both2000 ///
    using "${proj}/result/table/main_longmarch_korea_robustness_reghdfejl_v1.tex", replace ///
    booktabs nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953 c.ln_longmarch_martyr_count#1.post c.ln_korea_war_martyr_count#1.post) ///
    se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
