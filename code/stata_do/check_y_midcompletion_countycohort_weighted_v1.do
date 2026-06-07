*******************************************************
* Y = county-by-cohort middle-school completion rate
* mid_comp = mean(1[eduy>=9]) within county x birth cohort
* Compare unweighted vs weighted [aw=n_obs]
* Main FE spec + AER-style controls interacted with post
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
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

    gen str6 muni6 = substr(old6,1,2) + "01" + substr(old6,5,2) if inlist(substr(old6,1,2),"11","12","31") & substr(old6,3,2)=="00" & county_curr6==""
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
* treatment and controls
*******************************************************
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
duplicates drop countyid_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64
duplicates drop countyid_curr6, force
tempfile ctrls
save `ctrls'
global ctrls_tmp "`ctrls'"

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

capture program drop _build_panel_mid
program define _build_panel_mid
    syntax , WAVE(integer) HI(integer)

    if `wave'==1982 {
        use countyid birthyr eduy using "${proj}/data/temp/census_1982_cleaned.dta", clear
        drop if missing(countyid) | missing(birthyr) | missing(eduy)
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
    }

    if `wave'==1990 {
        use county age_c age educ using "${proj}/data/raw/census/census1990.dta", clear
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
    }

    if `wave'==2000 {
        use uid birthyr eduyr using "${proj}/data/raw/census/census2000.dta", clear
        drop if missing(uid) | missing(birthyr) | missing(eduyr)
        gen str6 old6 = string(uid, "%06.0f")
        merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen eduy = eduyr
    }

    keep if inrange(birthyr,1920,`hi')
    drop if floor(birthyr)==1939
    keep if inrange(eduy,0,25)
    gen birth_i = floor(birthyr)
    gen mid = (eduy>=9)

    collapse (mean) mid_comp=mid (count) n_obs=mid, by(countyid_curr6 birth_i)
    merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen
    merge m:1 countyid_curr6 using "$ctrls_tmp", keep(master match) nogen

    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
        replace `v' = 0 if missing(`v')
    }

    gen post = birth_i>=1940
    egen county_num = group(countyid_curr6)
end

eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str16 spec = ""
gen b = .
gen se = .
gen p = .
gen n_cells = .
gen n_counties = .
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978

    quietly _build_panel_mid, wave(`w') hi(`hi')

    quietly count
    local n_cells = r(N)
    egen __tagc = tag(county_num)
    quietly count if __tagc==1
    local n_counties = r(N)
    drop __tagc

    // U1
    quietly reghdfejl mid_comp c.ln_martyr_per100k_1953##ib0.post, absorb(county_num birth_i) vce(cluster county_num)
    estimates store m`w'_u1
    estadd local Weighted "N"
    estadd local AER_Post "N"
    estadd scalar N_counties = `n_counties'
    local b1 = _b[1.post#c.ln_martyr_per100k_1953]
    local se1 = _se[1.post#c.ln_martyr_per100k_1953]
    local p1 = 2*ttail(e(df_r), abs(`b1'/`se1'))

    // U2
    quietly reghdfejl mid_comp c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store m`w'_u2
    estadd local Weighted "N"
    estadd local AER_Post "Y"
    estadd scalar N_counties = `n_counties'
    local b2 = _b[1.post#c.ln_martyr_per100k_1953]
    local se2 = _se[1.post#c.ln_martyr_per100k_1953]
    local p2 = 2*ttail(e(df_r), abs(`b2'/`se2'))

    // W1
    quietly reghdfejl mid_comp c.ln_martyr_per100k_1953##ib0.post [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m`w'_w1
    estadd local Weighted "Y"
    estadd local AER_Post "N"
    estadd scalar N_counties = `n_counties'
    local b3 = _b[1.post#c.ln_martyr_per100k_1953]
    local se3 = _se[1.post#c.ln_martyr_per100k_1953]
    local p3 = 2*ttail(e(df_r), abs(`b3'/`se3'))

    // W2
    quietly reghdfejl mid_comp c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m`w'_w2
    estadd local Weighted "Y"
    estadd local AER_Post "Y"
    estadd scalar N_counties = `n_counties'
    local b4 = _b[1.post#c.ln_martyr_per100k_1953]
    local se4 = _se[1.post#c.ln_martyr_per100k_1953]
    local p4 = 2*ttail(e(df_r), abs(`b4'/`se4'))

    use `summary', clear
    local n = _N + 1
    set obs `=`n'+3'
    replace wave = "`w'" in `n'
    replace spec = "U1 baseline" in `n'
    replace b = `b1' in `n'
    replace se = `se1' in `n'
    replace p = `p1' in `n'
    replace n_cells = `n_cells' in `n'
    replace n_counties = `n_counties' in `n'

    replace wave = "`w'" in `=`n'+1'
    replace spec = "U2 + AER" in `=`n'+1'
    replace b = `b2' in `=`n'+1'
    replace se = `se2' in `=`n'+1'
    replace p = `p2' in `=`n'+1'
    replace n_cells = `n_cells' in `=`n'+1'
    replace n_counties = `n_counties' in `=`n'+1'

    replace wave = "`w'" in `=`n'+2'
    replace spec = "W1 baseline" in `=`n'+2'
    replace b = `b3' in `=`n'+2'
    replace se = `se3' in `=`n'+2'
    replace p = `p3' in `=`n'+2'
    replace n_cells = `n_cells' in `=`n'+2'
    replace n_counties = `n_counties' in `=`n'+2'

    replace wave = "`w'" in `=`n'+3'
    replace spec = "W2 + AER" in `=`n'+3'
    replace b = `b4' in `=`n'+3'
    replace se = `se4' in `=`n'+3'
    replace p = `p4' in `=`n'+3'
    replace n_cells = `n_cells' in `=`n'+3'
    replace n_counties = `n_counties' in `=`n'+3'
    save `summary', replace
}

use `summary', clear
gen t_abs = abs(b/se)
export delimited using "${proj}/result/table/y_midcompletion_countycohort_compare_summary_v1.csv", replace
save "${proj}/result/table/y_midcompletion_countycohort_compare_summary_v1.dta", replace

esttab m1982_u1 m1982_u2 m1982_w1 m1982_w2 ///
       m1990_u1 m1990_u2 m1990_w1 m1990_w2 ///
       m2000_u1 m2000_u2 m2000_w1 m2000_w2 ///
       using "${proj}/result/table/y_midcompletion_countycohort_compare_v1.rtf", ///
       replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Weighted AER_Post N_counties) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab m1982_u1 m1982_u2 m1982_w1 m1982_w2 ///
       m1990_u1 m1990_u2 m1990_w1 m1990_w2 ///
       m2000_u1 m2000_u2 m2000_w1 m2000_w2 ///
       using "${proj}/result/table/y_midcompletion_countycohort_compare_v1.tex", ///
       replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Weighted AER_Post N_counties) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
