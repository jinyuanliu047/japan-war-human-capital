*******************************************************
* Graduation-rate regressions by wave — with historical controls
* Raw / historical census chain
* Denominator = total county-cohort persons
* Adds SDY, famine, victims_cr, grain, urban64 × post
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
if _rc != 0 {
    capture which reghdfe
    if _rc != 0 ssc install reghdfe, replace
}

* --- County dictionary ---
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

* --- 1982 crosswalk ---
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

* --- 2000 crosswalk ---
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

* --- Resolve program for 1990 ---
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
    drop county_curr6 route_final
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
            rename curr_dict county_curr6
            keep old6 county_curr6
            save `muni_exact', replace
        }
    restore

    capture merge 1:1 old6 using `muni_exact', keep(master match) nogen update replace
    drop muni6
end

* --- Treatment ---
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop countyid_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

* --- Historical county controls ---
use "${proj}/data/raw/county_data.dta", clear
capture rename countyid countyid_curr6
capture tostring countyid_curr6, replace format("%06.0f")
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
capture gen ln_victims_cr = ln(1 + victims_cr)
capture gen ln_grain_output = ln(1 + grain_output)
keep countyid_curr6 sdy_density ins_famine ln_victims_cr ln_grain_output urbanization64
duplicates drop countyid_curr6, force
tempfile county_controls
save `county_controls'
global county_controls_tmp "`county_controls'"

* --- 1990 map ---
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

* --- Prep program ---
capture program drop _prep_wave_grad
program define _prep_wave_grad
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
        keep if inrange(birth_i, 1920, `hi')
        keep if inrange(eduy_clean, 0, 25)
        gen total_n = 1
        gen primary_num = (eduy_clean >= 6)
        gen junior_num = (eduy_clean >= 9)
        gen senior_num = (eduy_clean >= 12)
        gen college_num = (eduy_clean >= 15)
        collapse (sum) total_n primary_num junior_num senior_num college_num, by(countyid_curr6 birth_i)
    }

    if `wave' == 1990 {
        use county age_c age educ using "$census1990", clear
        drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
        gen str6 old6 = string(county, "%06.0f")
        merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen birthyr = 1000 + age_c*100 + age
        gen birth_i = floor(birthyr)
        gen eduy_clean = .
        replace eduy_clean = 0  if educ==1
        replace eduy_clean = 6  if educ==2
        replace eduy_clean = 9  if educ==3
        replace eduy_clean = 12 if inlist(educ,4,5)
        replace eduy_clean = 15 if educ==6
        replace eduy_clean = 16 if educ==7
        keep if inrange(birth_i, 1920, `hi')
        keep if inrange(eduy_clean, 0, 25)
        gen total_n = 1
        gen primary_num = (eduy_clean >= 6)
        gen junior_num = (eduy_clean >= 9)
        gen senior_num = (eduy_clean >= 12)
        gen college_num = (eduy_clean >= 15)
        collapse (sum) total_n primary_num junior_num senior_num college_num, by(countyid_curr6 birth_i)
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
        keep if inrange(birth_i, 1920, `hi')
        keep if inrange(eduy_clean, 0, 25)
        gen total_n = 1
        gen primary_num = (eduy_clean >= 6)
        gen junior_num = (eduy_clean >= 9)
        gen senior_num = (eduy_clean >= 12)
        gen college_num = (eduy_clean >= 15)
        collapse (sum) total_n primary_num junior_num senior_num college_num, by(countyid_curr6 birth_i)
    }
end

* --- Run program with controls ---
capture program drop _run_wave_grad_ctrl
program define _run_wave_grad_ctrl
    syntax , WAVE(integer) HI(integer) CUTOFF(integer) DROPYEAR(integer)

    quietly _prep_wave_grad, wave(`wave') hi(`hi')
    drop if birth_i == `dropyear'
    gen primary_rate = primary_num / total_n
    gen junior_rate = junior_num / total_n
    gen senior_rate = senior_num / total_n
    gen college_rate = college_num / total_n
    merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen
    merge m:1 countyid_curr6 using "$county_controls_tmp", keep(master match) nogen
    gen post = birth_i >= `cutoff'
    egen county_num = group(countyid_curr6)

    * --- Baseline (no historical controls) ---
    quietly reghdfejl primary_rate c.ln_martyr_per100k_1953##ib0.post [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m1_base
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Hist_controls "N"
    estadd local Cutoff "`cutoff'"

    quietly reghdfejl junior_rate c.ln_martyr_per100k_1953##ib0.post [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m2_base
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Hist_controls "N"
    estadd local Cutoff "`cutoff'"

    quietly reghdfejl senior_rate c.ln_martyr_per100k_1953##ib0.post [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m3_base
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Hist_controls "N"
    estadd local Cutoff "`cutoff'"

    quietly reghdfejl college_rate c.ln_martyr_per100k_1953##ib0.post [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m4_base
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Hist_controls "N"
    estadd local Cutoff "`cutoff'"

    * --- With historical controls × post ---
    local hist_int "c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanization64#c.post"

    quietly reghdfejl primary_rate c.ln_martyr_per100k_1953##ib0.post `hist_int' [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m1_ctrl
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Hist_controls "Y"
    estadd local Cutoff "`cutoff'"

    quietly reghdfejl junior_rate c.ln_martyr_per100k_1953##ib0.post `hist_int' [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m2_ctrl
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Hist_controls "Y"
    estadd local Cutoff "`cutoff'"

    quietly reghdfejl senior_rate c.ln_martyr_per100k_1953##ib0.post `hist_int' [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m3_ctrl
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Hist_controls "Y"
    estadd local Cutoff "`cutoff'"

    quietly reghdfejl college_rate c.ln_martyr_per100k_1953##ib0.post `hist_int' [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m4_ctrl
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Hist_controls "Y"
    estadd local Cutoff "`cutoff'"

    * --- Export baseline ---
    esttab m1_base m2_base m3_base m4_base using "${outstub}_baseline.tex", ///
        replace booktabs nonotes ///
        keep(1.post#c.ln_martyr_per100k_1953) ///
        coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
        mtitles("Primary" "Junior high" "Senior high" "College") ///
        stats(County_FE Cohort_FE Hist_controls Cutoff N r2, ///
            labels("County FE" "Cohort FE" "Historical controls × post" "Treatment start" "Observations" "R-squared")) ///
        se star(* 0.1 ** 0.05 *** 0.01)

    * --- Export with controls ---
    esttab m1_ctrl m2_ctrl m3_ctrl m4_ctrl using "${outstub}_withcontrols.tex", ///
        replace booktabs nonotes ///
        keep(1.post#c.ln_martyr_per100k_1953) ///
        coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
        mtitles("Primary" "Junior high" "Senior high" "College") ///
        stats(County_FE Cohort_FE Hist_controls Cutoff N r2, ///
            labels("County FE" "Cohort FE" "Historical controls × post" "Treatment start" "Observations" "R-squared")) ///
        se star(* 0.1 ** 0.05 *** 0.01)

    * --- Export combined 8-col ---
    esttab m1_base m1_ctrl m2_base m2_ctrl m3_base m3_ctrl m4_base m4_ctrl using "${outstub}_combined.tex", ///
        replace booktabs nonotes ///
        keep(1.post#c.ln_martyr_per100k_1953) ///
        coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
        mtitles("Primary" "Primary" "Jr. high" "Jr. high" "Sr. high" "Sr. high" "College" "College") ///
        stats(County_FE Cohort_FE Hist_controls Cutoff N r2, ///
            labels("County FE" "Cohort FE" "Historical controls × post" "Treatment start" "Observations" "R-squared")) ///
        se star(* 0.1 ** 0.05 *** 0.01)

    * --- CSV summary ---
    tempfile tmp
    tempname memhold
    postfile `memhold' str18 outcome str12 spec double b se p N using `tmp', replace
    foreach s in "base" "ctrl" {
        foreach m in 1 2 3 4 {
            local oname ""
            if `m'==1 local oname "primary"
            if `m'==2 local oname "junior_high"
            if `m'==3 local oname "senior_high"
            if `m'==4 local oname "college"
            estimates restore m`m'_`s'
            post `memhold' ("`oname'") ("`s'") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N))
        }
    }
    postclose `memhold'
    use `tmp', clear
    export delimited using "${outstub}_summary.csv", replace
end

* === Run all waves, cutoff 1940 ===
global outstub "${proj}/result/table/graduation_rates_1982_cutoff1940_ctrl_v1"
_run_wave_grad_ctrl, wave(1982) hi(1960) cutoff(1940) dropyear(1939)
global outstub "${proj}/result/table/graduation_rates_1990_cutoff1940_ctrl_v1"
_run_wave_grad_ctrl, wave(1990) hi(1968) cutoff(1940) dropyear(1939)
global outstub "${proj}/result/table/graduation_rates_2000_cutoff1940_ctrl_v1"
_run_wave_grad_ctrl, wave(2000) hi(1978) cutoff(1940) dropyear(1939)

* === Run all waves, cutoff 1946 ===
global outstub "${proj}/result/table/graduation_rates_1982_cutoff1946_ctrl_v1"
_run_wave_grad_ctrl, wave(1982) hi(1960) cutoff(1946) dropyear(1945)
global outstub "${proj}/result/table/graduation_rates_1990_cutoff1946_ctrl_v1"
_run_wave_grad_ctrl, wave(1990) hi(1968) cutoff(1946) dropyear(1945)
global outstub "${proj}/result/table/graduation_rates_2000_cutoff1946_ctrl_v1"
_run_wave_grad_ctrl, wave(2000) hi(1978) cutoff(1946) dropyear(1945)

exit, clear
