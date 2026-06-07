*******************************************************
* Cohort-specific treatment coefficients by wave
* Individual-level eduy (no weights), no controls
* Drop cohort 1939
* Treated cohorts: 1940+
* Wave-specific end year (age-22 rule):
*   1982 -> 1960, 1990 -> 1968, 2000 -> 1978
* Coefficients are absolute slopes (vs 0), not normalized.
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

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
* treatment table
*******************************************************
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953 martyr_per100k_1953 martyr_count_1931_1945 pop_1953
duplicates drop countyid_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

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
* helper: one wave on individual data (no controls)
*******************************************************
capture program drop _one_wave_indiv_noctrl
program define _one_wave_indiv_noctrl, rclass
    syntax , WAVE(integer) HI(integer)

    if `wave' == 1982 {
        use countyid birthyr eduy sex ethniccn using "${proj}/data/temp/census_1982_cleaned.dta", clear
        drop if missing(countyid) | missing(birthyr) | missing(eduy)
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6

        gen female = (sex==2) if !missing(sex)
        gen minority = (ethniccn!=1) if !missing(ethniccn)
    }

    if `wave' == 1990 {
        use county age_c age educ sex race regstatu using "${proj}/data/raw/census/census1990.dta", clear
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

        gen female = (sex==2) if !missing(sex)
        gen minority = (race!=1) if !missing(race)
    }

    if `wave' == 2000 {
        use uid birthyr eduyr sex race urban rural using "${proj}/data/raw/census/census2000.dta", clear
        drop if missing(uid) | missing(birthyr) | missing(eduyr)

        gen str6 old6 = string(uid, "%06.0f")
        merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6

        gen eduy = eduyr
        gen female = (sex==2) if !missing(sex)
        gen minority = (race!=1) if !missing(race)
    }

    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    drop if missing(eduy)
    keep if inrange(eduy,0,25)

    merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen

    gen birth_i = floor(birthyr)
    egen county_num = group(countyid_curr6)
    gen post = birth_i >= 1940

    quietly count
    return scalar n_obs = r(N)
    egen tag_county = tag(county_num)
    quietly count if tag_county==1
    return scalar n_counties = r(N)
    drop tag_county

    quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post, ///
        absorb(county_num birth_i) vce(cluster county_num)
    quietly lincom 1.post#c.ln_martyr_per100k_1953
    return scalar b_did = r(estimate)
    return scalar se_did = r(se)
    return scalar p_did = 2 * ttail(e(df_r), abs(r(estimate) / r(se)))

    quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib1938.birth_i, ///
        absorb(county_num birth_i) vce(cluster county_num)

    levelsof birth_i, local(years)

    local preterms
    local postterms
    foreach y of local years {
        if `y' <= 1937 {
            local preterms `preterms' `y'.birth_i#c.ln_martyr_per100k_1953
        }
        if `y' >= 1940 {
            local postterms `postterms' `y'.birth_i#c.ln_martyr_per100k_1953
        }
    }

    scalar p_pre_equal1938 = .
    scalar p_post_equal1938 = .
    capture noisily testparm `preterms'
    if _rc == 0 scalar p_pre_equal1938 = r(p)
    capture noisily testparm `postterms'
    if _rc == 0 scalar p_post_equal1938 = r(p)
    return scalar p_pre_equal1938 = p_pre_equal1938
    return scalar p_post_equal1938 = p_post_equal1938

    tempname ph
    tempfile coef
    postfile `ph' str6 wave int birthyr ///
        double coefficient se lb ub p_coef ///
        int startyr dropped sample_lo sample_hi ///
        using "`coef'", replace

    foreach y of local years {
        if `y' == 1938 {
            capture quietly lincom c.ln_martyr_per100k_1953
        }
        else {
            capture quietly lincom c.ln_martyr_per100k_1953 + `y'.birth_i#c.ln_martyr_per100k_1953
        }
        if _rc == 0 {
            local p = 2 * ttail(e(df_r), abs(r(estimate) / r(se)))
            post `ph' ("`wave'") (`y') ///
                (r(estimate)) (r(se)) ///
                (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se)) ///
                (`p') ///
                (1940) (1939) (1920) (`hi')
        }
    }
    postclose `ph'

    use "`coef'", clear
    sort birthyr
    export delimited using "${proj}/data/temp/eventstudy_coefficient_drop1939_start1940_`wave'_indiv_noctrl_v1.csv", replace
    save "${proj}/data/temp/eventstudy_coefficient_drop1939_start1940_`wave'_indiv_noctrl_v1.dta", replace
end

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen startyr = .
gen dropped = .
gen sample_lo = .
gen sample_hi = .
gen b_did = .
gen se_did = .
gen p_did = .
gen p_pre_equal1938 = .
gen p_post_equal1938 = .
gen n_obs = .
gen n_counties = .
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'" == "1990" local hi = 1968
    if "`w'" == "2000" local hi = 1978

    quietly _one_wave_indiv_noctrl, wave(`w') hi(`hi')

    local b_did = r(b_did)
    local se_did = r(se_did)
    local p_did = r(p_did)
    local p_pre = r(p_pre_equal1938)
    local p_post = r(p_post_equal1938)
    local n_obs = r(n_obs)
    local n_counties = r(n_counties)

    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace startyr = 1940 in `n'
    replace dropped = 1939 in `n'
    replace sample_lo = 1920 in `n'
    replace sample_hi = `hi' in `n'
    replace b_did = `b_did' in `n'
    replace se_did = `se_did' in `n'
    replace p_did = `p_did' in `n'
    replace p_pre_equal1938 = `p_pre' in `n'
    replace p_post_equal1938 = `p_post' in `n'
    replace n_obs = `n_obs' in `n'
    replace n_counties = `n_counties' in `n'
    save `summary', replace
}

use `summary', clear
sort wave
export delimited using "${proj}/data/temp/eventstudy_coefficient_drop1939_start1940_wavecut_summary_indiv_noctrl_v1.csv", replace
save "${proj}/data/temp/eventstudy_coefficient_drop1939_start1940_wavecut_summary_indiv_noctrl_v1.dta", replace
list, clean noobs
