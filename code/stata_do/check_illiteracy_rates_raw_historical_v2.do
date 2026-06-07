*******************************************************
* Illiteracy-rate regressions by wave
* Raw / historical census chain
* Denominator = total county-cohort persons
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/census_1982_cleaned.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

global census1982 "${proj}/data/temp/census_1982_cleaned.dta"
global census1990 "${proj}/data/raw/census/census1990.dta"
global census2000 "${proj}/data/raw/census/census2000.dta"
if fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta") global census1982 "${proj}/data/temp/census_1982_mainvars_v1.dta"
if fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta") global census1990 "${proj}/data/temp/census_1990_mainvars_v1.dta"
if fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta") global census2000 "${proj}/data/temp/census_2000_mainvars_v1.dta"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

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
global cw1982_tmp "`cw1982'"

import delimited "${proj}/data/temp/countyid_2000_to_current_routes_v1.csv", clear varnames(1) stringcols(_all)
rename county_old6 old6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile map2000
save `map2000'
global map2000_tmp "`map2000'"

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

capture program drop _resolve_old6_map
program define _resolve_old6_map
    gen str6 county_curr6 = ""
    replace county_curr6 = "310101" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"

    tempfile left
    save `left'
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    drop county_curr6
    rename curr_res county_curr6
    save `left', replace

    use `left', clear
    rename county_curr6 curr_res
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace curr_res = curr_dict if curr_res=="" & curr_dict!=""
    drop curr_dict
    rename curr_res county_curr6
end

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop countyid_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

use county using "$census1990", clear
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

capture program drop _prep_wave_illit
program define _prep_wave_illit
    syntax , WAVE(integer) HI(integer)

    if `wave' == 1982 {
        use countyid birthyr eduy using "$census1982", clear
        drop if missing(countyid) | missing(birthyr) | missing(eduy)
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen birth_i = floor(birthyr)
        gen eduy_clean = eduy
    }

    if `wave' == 1990 {
        use county age_c age educ using "$census1990", clear
        drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
        gen str6 old6 = string(county, "%06.0f")
        merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen birth_i = 1000 + age_c*100 + age
        gen eduy_clean = .
        replace eduy_clean = 0  if educ==1
        replace eduy_clean = 6  if educ==2
        replace eduy_clean = 9  if educ==3
        replace eduy_clean = 12 if inlist(educ,4,5)
        replace eduy_clean = 15 if educ==6
        replace eduy_clean = 16 if educ==7
    }

    if `wave' == 2000 {
        use uid birthyr eduyr using "$census2000", clear
        drop if missing(uid) | missing(birthyr) | missing(eduyr)
        gen str6 old6 = string(uid, "%06.0f")
        merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen birth_i = floor(birthyr)
        gen eduy_clean = eduyr
    }

    keep if inrange(birth_i, 1920, `hi')
    keep if inrange(eduy_clean, 0, 25)
end

capture program drop _run_wave_illit
program define _run_wave_illit
    syntax , WAVE(integer) HI(integer) CUTOFF(integer) DROPYEAR(integer)

    quietly _prep_wave_illit, wave(`wave') hi(`hi')
    drop if birth_i == `dropyear'
    gen total_n = 1
    gen illit_num = (eduy_clean == 0)
    collapse (sum) total_n illit_num, by(countyid_curr6 birth_i)
    gen illiteracy_rate = illit_num / total_n
    merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen
    gen post = birth_i >= `cutoff'
    egen county_num = group(countyid_curr6)

    quietly reghdfejl illiteracy_rate c.ln_martyr_per100k_1953##ib0.post [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m1
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "`cutoff'"
    estadd scalar Adj_R2 = e(r2_a)

    esttab m1 using "$outstub.tex", ///
        replace booktabs nonotes ///
        keep(1.post#c.ln_martyr_per100k_1953) ///
        coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
        stats(County_FE Cohort_FE Cutoff N r2 Adj_R2, ///
            labels("County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
        se star(* 0.1 ** 0.05 *** 0.01)

    esttab m1 using "$outstub.rtf", ///
        replace ///
        keep(1.post#c.ln_martyr_per100k_1953) ///
        coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
        stats(County_FE Cohort_FE Cutoff N r2 Adj_R2, ///
            labels("County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
        se star(* 0.1 ** 0.05 *** 0.01)

    local b = _b[1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))
    local n = e(N)

    clear
    set obs 1
    gen wave = `wave'
    gen b = `b'
    gen se = `se'
    gen p = `p'
    gen N = `n'
    export delimited using "$outstub.csv", replace
end

global outstub "${proj}/result/table/illiteracy_rates_1982_cutoff1940_raw_v2"
_run_wave_illit, wave(1982) hi(1960) cutoff(1940) dropyear(1939)
global outstub "${proj}/result/table/illiteracy_rates_1990_cutoff1940_raw_v2"
_run_wave_illit, wave(1990) hi(1968) cutoff(1940) dropyear(1939)
global outstub "${proj}/result/table/illiteracy_rates_2000_cutoff1940_raw_v2"
_run_wave_illit, wave(2000) hi(1978) cutoff(1940) dropyear(1939)

global outstub "${proj}/result/table/illiteracy_rates_1982_cutoff1946_raw_v2"
_run_wave_illit, wave(1982) hi(1960) cutoff(1946) dropyear(1945)
global outstub "${proj}/result/table/illiteracy_rates_1990_cutoff1946_raw_v2"
_run_wave_illit, wave(1990) hi(1968) cutoff(1946) dropyear(1945)
global outstub "${proj}/result/table/illiteracy_rates_2000_cutoff1946_raw_v2"
_run_wave_illit, wave(2000) hi(1978) cutoff(1946) dropyear(1945)

exit, clear
