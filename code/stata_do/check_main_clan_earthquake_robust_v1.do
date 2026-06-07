*******************************************************
* Robustness checks: clan and earthquake (AER-style)
* Main outcome: individual eduy
* Main treatment: ln(1 + martyrs per 100k pop1953) x post(>=1940)
* Follows AER-style controls:
*   - county FE
*   - province x cohort FE
*   - county baseline education x cohort interactions
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 {
    ssc install estout, replace
}

*******************************************************
* county dictionary and 1982 crosswalk
*******************************************************
import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
keep GBCounty
destring GBCounty, replace force
drop if missing(GBCounty)
gen str6 county_curr6 = string(GBCounty, "%06.0f")
gen str6 old6 = county_curr6
gen str6 curr_dict = county_curr6
keep old6 curr_dict
duplicates drop old6, force
tempfile county_dict
save `county_dict'
global county_dict_tmp "`county_dict'"

import delimited "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", clear varnames(1) stringcols(_all)
rename countyid_old6 old6
rename countyid_curr6_final county_curr6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = subinstr(county_curr6, ".0", "", .)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6 route_final
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'
global cw1982_tmp "`cw1982'"

*******************************************************
* helper: resolve old6 -> county_curr6
*******************************************************
capture program drop _resolve_old6_map
program define _resolve_old6_map
    gen str6 county_curr6 = ""
    gen str30 route = "unmatched"

    replace county_curr6 = "310101" if old6=="310103"
    replace route = "manual_successor" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace route = "manual_successor" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace route = "manual_successor" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"
    replace route = "manual_successor" if old6=="110010"

    tempfile left
    save `left'
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6 route_final)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    replace route = "crosswalk_1982" if county_curr6!="" & route=="unmatched"
    drop county_curr6
    drop route_final
    rename curr_res county_curr6
    save `left', replace

    use `left', clear
    rename county_curr6 curr_res
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace curr_res = curr_dict if curr_res=="" & curr_dict!=""
    replace route = "exact_code" if curr_dict!="" & route=="unmatched"
    drop curr_dict
    rename curr_res county_curr6

    gen str6 muni6 = substr(old6,1,2) + "01" + substr(old6,5,2) ///
        if inlist(substr(old6,1,2),"11","12","31") & substr(old6,3,2)=="00" & county_curr6==""

    tempfile muni_exact
    tempfile muni_cw

    preserve
        keep old6
        keep if 0
        gen str6 curr_from_muni_exact = ""
        save `muni_exact', replace
    restore

    preserve
        keep old6
        keep if 0
        gen str6 curr_from_muni_cw = ""
        save `muni_cw', replace
    restore

    preserve
        keep if muni6!="" & county_curr6==""
        count
        if r(N)>0 {
            keep old6 muni6
            rename muni6 old6_muni
            rename old6 old6_orig
            rename old6_muni old6
            merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
            keep if curr_dict!=""
            drop old6
            rename old6_orig old6
            rename curr_dict curr_from_muni_exact
            keep old6 curr_from_muni_exact
            save `muni_exact', replace
        }
    restore

    merge 1:1 old6 using `muni_exact', keep(master match) nogen
    replace county_curr6 = curr_from_muni_exact if county_curr6=="" & curr_from_muni_exact!=""
    replace route = "municipality_geo3_recode" if county_curr6==curr_from_muni_exact & curr_from_muni_exact!=""
    drop curr_from_muni_exact

    preserve
        keep if muni6!="" & county_curr6==""
        count
        if r(N)>0 {
            keep old6 muni6
            rename muni6 old6_muni
            rename old6 old6_orig
            rename old6_muni old6
            merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
            keep if county_curr6!=""
            drop old6
            rename old6_orig old6
            rename county_curr6 curr_from_muni_cw
            keep old6 curr_from_muni_cw
            save `muni_cw', replace
        }
    restore

    merge 1:1 old6 using `muni_cw', keep(master match) nogen
    replace county_curr6 = curr_from_muni_cw if county_curr6=="" & curr_from_muni_cw!=""
    replace route = "municipality_then_crosswalk_1982" if county_curr6==curr_from_muni_cw & curr_from_muni_cw!=""
    drop curr_from_muni_cw muni6
end

*******************************************************
* treatment and county controls
*******************************************************
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953 martyr_per100k_1953 martyr_count_1931_1945 pop_1953
duplicates drop countyid_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

use "${proj}/data/temp/county_clan_quake_controls_v1.dta", clear
keep countyid_curr6 clan_num ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940
duplicates drop countyid_curr6, force
tempfile county_ctrl
save `county_ctrl'
global county_ctrl_tmp "`county_ctrl'"

*******************************************************
* mapping files for 1990 / 2000
*******************************************************
use county age_c age educ using "${proj}/data/raw/census/census1990.dta", clear
drop if missing(county)
gen str6 old6 = string(county, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map1990
save `map1990'
global map1990_tmp "`map1990'"

use uid birthyr eduyr using "${proj}/data/raw/census/census2000.dta", clear
drop if missing(uid)
gen str6 old6 = string(uid, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map2000
save `map2000'
global map2000_tmp "`map2000'"

*******************************************************
* helper: run one wave with 4 robustness specs
*******************************************************
capture program drop _run_wave_rob
program define _run_wave_rob, rclass
    syntax , WAVE(integer) HI(integer)

    if `wave' == 1982 {
        use countyid birthyr eduy sex ethniccn using "${proj}/data/temp/census_1982_cleaned.dta", clear
        drop if missing(countyid) | missing(birthyr) | missing(eduy)
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen minority = (ethniccn!=1) if !missing(ethniccn)
    }

    if `wave' == 1990 {
        use county age_c age educ race using "${proj}/data/raw/census/census1990.dta", clear
        drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
        gen str6 old6 = string(county, "%06.0f")
        merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6

        gen birthyr = 1000 + age_c*100 + age
        gen eduy = .
        replace eduy = 0  if educ==1
        replace eduy = 6  if educ==2
        replace eduy = 9  if educ==3
        replace eduy = 12 if inlist(educ,4,5)
        replace eduy = 15 if educ==6
        replace eduy = 16 if educ==7
        gen minority = (race!=1) if !missing(race)
    }

    if `wave' == 2000 {
        use uid birthyr eduyr race using "${proj}/data/raw/census/census2000.dta", clear
        drop if missing(uid) | missing(birthyr) | missing(eduyr)
        gen str6 old6 = string(uid, "%06.0f")
        merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen eduy = eduyr
        gen minority = (race!=1) if !missing(race)
    }

    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    drop if missing(eduy)
    keep if inrange(eduy,0,25)

    merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen
    merge m:1 countyid_curr6 using "$county_ctrl_tmp", keep(master match) nogen

    foreach v in clan_num ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 {
        replace `v' = 0 if missing(`v')
    }

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)
    gen prov = real(substr(countyid_curr6,1,2))
    egen prov_cohort = group(prov birth_i)

    * county baseline education (pre-treatment cohorts), AER-style interacted with cohort
    gen mid_comp = (eduy>=9) if !missing(eduy)
    egen base_mid_pre = mean(mid_comp) if inrange(birth_i,1920,1938), by(county_num)
    egen base_mid_pre_all = max(base_mid_pre), by(county_num)
    replace base_mid_pre = base_mid_pre_all if missing(base_mid_pre)
    quietly summarize base_mid_pre
    replace base_mid_pre = r(mean) if missing(base_mid_pre)
    drop base_mid_pre_all mid_comp

    quietly count
    return scalar n_obs = r(N)
    egen __tagc = tag(county_num)
    quietly count if __tagc==1
    local n_counties = r(N)
    return scalar n_counties = r(N)
    drop __tagc

    * spec 1: baseline (minority only)
    quietly areg eduy c.ln_martyr_per100k_1953##ib0.post i.prov_cohort c.base_mid_pre#i.birth_i minority, ///
        absorb(county_num) vce(cluster county_num)
    estimates store m`wave'_s1
    estadd local Controls "Y"
    estadd local Minority "Y"
    estadd local Clan_Post "N"
    estadd local Quake_Post "N"
    estadd local County_FE "Y"
    estadd local ProvCohort_FE "Y"
    estadd local BaseEduCohort "Y"
    estadd scalar N_counties = `n_counties'
    return scalar b1 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se1 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p1 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))

    * spec 2: + clan
    quietly areg eduy c.ln_martyr_per100k_1953##ib0.post i.prov_cohort c.base_mid_pre#i.birth_i minority ///
        c.ln_clan#c.post, absorb(county_num) vce(cluster county_num)
    estimates store m`wave'_s2
    estadd local Controls "Y"
    estadd local Minority "Y"
    estadd local Clan_Post "Y"
    estadd local Quake_Post "N"
    estadd local County_FE "Y"
    estadd local ProvCohort_FE "Y"
    estadd local BaseEduCohort "Y"
    estadd scalar N_counties = `n_counties'
    return scalar b2 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se2 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p2 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))

    * spec 3: + earthquake
    quietly areg eduy c.ln_martyr_per100k_1953##ib0.post i.prov_cohort c.base_mid_pre#i.birth_i minority ///
        c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post, ///
        absorb(county_num) vce(cluster county_num)
    estimates store m`wave'_s3
    estadd local Controls "Y"
    estadd local Minority "Y"
    estadd local Clan_Post "N"
    estadd local Quake_Post "Y"
    estadd local County_FE "Y"
    estadd local ProvCohort_FE "Y"
    estadd local BaseEduCohort "Y"
    estadd scalar N_counties = `n_counties'
    return scalar b3 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se3 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p3 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))

    * spec 4: + clan and earthquake
    quietly areg eduy c.ln_martyr_per100k_1953##ib0.post i.prov_cohort c.base_mid_pre#i.birth_i minority ///
        c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post, ///
        absorb(county_num) vce(cluster county_num)
    estimates store m`wave'_s4
    estadd local Controls "Y"
    estadd local Minority "Y"
    estadd local Clan_Post "Y"
    estadd local Quake_Post "Y"
    estadd local County_FE "Y"
    estadd local ProvCohort_FE "Y"
    estadd local BaseEduCohort "Y"
    estadd scalar N_counties = `n_counties'
    return scalar b4 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se4 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p4 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))
end

*******************************************************
* run all waves and build summary
*******************************************************
eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str30 spec = ""
gen b = .
gen se = .
gen p = .
gen n_obs = .
gen n_counties = .
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'" == "1990" local hi = 1968
    if "`w'" == "2000" local hi = 1978

    quietly _run_wave_rob, wave(`w') hi(`hi')

    foreach s in 1 2 3 4 {
        use `summary', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        if `s' == 1 replace spec = "S1 baseline" in `n'
        if `s' == 2 replace spec = "S2 + clan#post" in `n'
        if `s' == 3 replace spec = "S3 + quake#post" in `n'
        if `s' == 4 replace spec = "S4 + clan+quake#post" in `n'
        replace b = r(b`s') in `n'
        replace se = r(se`s') in `n'
        replace p = r(p`s') in `n'
        replace n_obs = r(n_obs) in `n'
        replace n_counties = r(n_counties) in `n'
        save `summary', replace
    }
}

use `summary', clear
gen t_abs = abs(b/se)
gsort wave -t_abs
export delimited using "${proj}/result/table/main_clan_earthquake_robust_summary_v1.csv", replace
save "${proj}/result/table/main_clan_earthquake_robust_summary_v1.dta", replace
list, clean noobs

esttab m1982_s1 m1982_s2 m1982_s3 m1982_s4 ///
       m1990_s1 m1990_s2 m1990_s3 m1990_s4 ///
       m2000_s1 m2000_s2 m2000_s3 m2000_s4 ///
       using "${proj}/result/table/main_clan_earthquake_robust_v1.rtf", ///
       replace ///
       keep(1.post#c.ln_martyr_per100k_1953) ///
       scalar(Controls Minority Clan_Post Quake_Post County_FE ProvCohort_FE BaseEduCohort N_counties) ///
       se r2 ar2 ///
       star(* 0.1 ** 0.05 *** 0.01)

esttab m1982_s1 m1982_s2 m1982_s3 m1982_s4 ///
       m1990_s1 m1990_s2 m1990_s3 m1990_s4 ///
       m2000_s1 m2000_s2 m2000_s3 m2000_s4 ///
       using "${proj}/result/table/main_clan_earthquake_robust_v1.tex", ///
       replace ///
       keep(1.post#c.ln_martyr_per100k_1953) ///
       scalar(Controls Minority Clan_Post Quake_Post County_FE ProvCohort_FE BaseEduCohort N_counties) ///
       se r2 ar2 ///
       star(* 0.1 ** 0.05 *** 0.01)

exit, clear

