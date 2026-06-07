*******************************************************
* Main individual-level eduy regressions, clean data
* Cutoff 1946, drop 1945
* Compare minority only vs minority + AER#post
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
keep GBCounty
destring GBCounty, replace force
drop if missing(GBCounty)
gen str6 county_curr6 = string(GBCounty, "%06.0f")
gen str6 old6 = county_curr6
keep old6 county_curr6
duplicates drop old6, force
tempfile county_dict
save `county_dict'

import delimited "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", clear varnames(1) stringcols(_all)
rename countyid_old6 old6
rename countyid_curr6_final county_curr6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = subinstr(county_curr6, ".0", "", .)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'
global cw1982_tmp `"`cw1982'"'

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953 martyr_per100k_1953
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop countyid_curr6, force
tempfile treat
save `treat'
global treat_tmp `"`treat'"'

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
drop if countyid_curr6=="" | countyid_curr6=="000000"
duplicates drop countyid_curr6, force
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
tempfile aer
save `aer'
global aer_tmp `"`aer'"'

global aer_post "c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post"

use countyid region1990 using "${proj}/data/raw/census_1990_county_char.dta", clear
drop if missing(countyid) | missing(region1990)
rename countyid countyid_1990
rename region1990 county_curr6_num
keep countyid_1990 county_curr6_num
duplicates drop countyid_1990, force
gen str6 county_curr6 = string(county_curr6_num, "%06.0f")
keep countyid_1990 county_curr6
tempfile map1990clean
save `map1990clean'
global map1990clean_tmp `"`map1990clean'"'

capture program drop _prep_wave_clean
program define _prep_wave_clean
    syntax , WAVE(integer) HI(integer)

    if `wave' == 1982 {
        use countyid birthyr eduy ethniccn using "${proj}/data/temp/census_1982_cleaned.dta", clear
        drop if missing(countyid) | missing(birthyr) | missing(eduy)
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
        keep if county_curr6!=""
        gen minority = (ethniccn!=1) if !missing(ethniccn)
    }

    if `wave' == 1990 {
        use countyid year_birth yedu han_ethn using "${proj}/data/raw/census_1990_clean.dta", clear
        drop if missing(countyid) | missing(year_birth) | missing(yedu)
        rename countyid countyid_1990
        merge m:1 countyid_1990 using "$map1990clean_tmp", keep(master match) nogen
        keep if county_curr6!=""
        gen birthyr = year_birth
        gen eduy = yedu
        gen minority = (han_ethn!=1) if !missing(han_ethn)
    }

    if `wave' == 2000 {
        use region2000 year_birth yedu han_ethn using "${proj}/data/raw/census_2000_clean.dta", clear
        drop if missing(region2000) | missing(year_birth) | missing(yedu)
        gen county_curr6 = string(region2000, "%06.0f")
        gen birthyr = year_birth
        gen eduy = yedu
        gen minority = (han_ethn!=1) if !missing(han_ethn)
    }

    keep if inrange(birthyr, 1920, `hi')
    drop if missing(eduy)
    keep if inrange(eduy, 0, 25)
    gen birth_i = floor(birthyr)
    drop if birth_i == 1945
    gen post = birth_i >= 1946

    merge m:1 county_curr6 using "$treat_tmp", keep(master match) nogen
    merge m:1 county_curr6 using "$aer_tmp", keep(master match) nogen
    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
        replace `v' = 0 if missing(`v')
    }
    egen county_num = group(county_curr6)
end

capture program drop _run_wave
program define _run_wave, rclass
    syntax , WAVE(integer) HI(integer)

    quietly _prep_wave_clean, wave(`wave') hi(`hi')
    quietly count
    local nobs = r(N)
    return scalar n_obs = `nobs'
    egen __tag = tag(county_num)
    quietly count if __tag==1
    local ncount = r(N)
    return scalar n_counties = `ncount'
    drop __tag

    quietly reghdfe eduy c.ln_martyr_per100k_1953##ib0.post minority, absorb(county_num birth_i) vce(cluster county_num)
    estimates store m`wave'_1
    estadd local Controls "Y"
    estadd local AER_Post "N"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "1946"
    estadd scalar N_counties = `ncount'
    return scalar b1 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se1 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p1 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))

    quietly reghdfe eduy c.ln_martyr_per100k_1953##ib0.post minority $aer_post, absorb(county_num birth_i) vce(cluster county_num)
    estimates store m`wave'_2
    estadd local Controls "Y"
    estadd local AER_Post "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "1946"
    estadd scalar N_counties = `ncount'
    return scalar b2 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se2 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p2 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
end

eststo clear

foreach w in 1982 1990 2000 {
    local hi = 1960
    if `w' == 1990 local hi = 1968
    if `w' == 2000 local hi = 1978

    quietly _run_wave, wave(`w') hi(`hi')
    local b`w'_1 = r(b1)
    local se`w'_1 = r(se1)
    local p`w'_1 = r(p1)
    local nobs`w'_1 = r(n_obs)
    local ncount`w'_1 = r(n_counties)

    local b`w'_2 = r(b2)
    local se`w'_2 = r(se2)
    local p`w'_2 = r(p2)
    local nobs`w'_2 = r(n_obs)
    local ncount`w'_2 = r(n_counties)
}

clear
set obs 6
gen str6 wave = ""
gen str14 spec = ""
gen b = .
gen se = .
gen p = .
gen n_obs = .
gen n_counties = .

replace wave = "1982" in 1
replace spec = "minority" in 1
replace b = `b1982_1' in 1
replace se = `se1982_1' in 1
replace p = `p1982_1' in 1
replace n_obs = `nobs1982_1' in 1
replace n_counties = `ncount1982_1' in 1

replace wave = "1982" in 2
replace spec = "minority+AER" in 2
replace b = `b1982_2' in 2
replace se = `se1982_2' in 2
replace p = `p1982_2' in 2
replace n_obs = `nobs1982_2' in 2
replace n_counties = `ncount1982_2' in 2

replace wave = "1990" in 3
replace spec = "minority" in 3
replace b = `b1990_1' in 3
replace se = `se1990_1' in 3
replace p = `p1990_1' in 3
replace n_obs = `nobs1990_1' in 3
replace n_counties = `ncount1990_1' in 3

replace wave = "1990" in 4
replace spec = "minority+AER" in 4
replace b = `b1990_2' in 4
replace se = `se1990_2' in 4
replace p = `p1990_2' in 4
replace n_obs = `nobs1990_2' in 4
replace n_counties = `ncount1990_2' in 4

replace wave = "2000" in 5
replace spec = "minority" in 5
replace b = `b2000_1' in 5
replace se = `se2000_1' in 5
replace p = `p2000_1' in 5
replace n_obs = `nobs2000_1' in 5
replace n_counties = `ncount2000_1' in 5

replace wave = "2000" in 6
replace spec = "minority+AER" in 6
replace b = `b2000_2' in 6
replace se = `se2000_2' in 6
replace p = `p2000_2' in 6
replace n_obs = `nobs2000_2' in 6
replace n_counties = `ncount2000_2' in 6

sort wave spec
export delimited using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_clean_reghdfe_summary_v1.csv", replace
save "${proj}/result/table/main_micro_eduy_cutoff1946_aer_clean_reghdfe_summary_v1.dta", replace

esttab m1982_1 m1982_2 m1990_1 m1990_2 m2000_1 m2000_2 using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_clean_reghdfe_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls AER_Post County_FE Cohort_FE Cutoff N_counties) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab m1982_1 m1982_2 m1990_1 m1990_2 m2000_1 m2000_2 using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_clean_reghdfe_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls AER_Post County_FE Cohort_FE Cutoff N_counties) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
