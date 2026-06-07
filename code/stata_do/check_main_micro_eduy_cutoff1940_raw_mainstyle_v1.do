*******************************************************
* Main individual-level eduy regressions (raw-based)
* Treat starts in 1940, drop 1939
* Three census waves, full cohorts
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

global p1982raw = cond(fileexists("/tmp/census_1982_cleaned_small.dta"), "/tmp/census_1982_cleaned_small.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global p1990raw = cond(fileexists("/tmp/census1990_raw_small.dta"), "/tmp/census1990_raw_small.dta", "${proj}/data/raw/census/census1990.dta")
global p2000raw = cond(fileexists("/tmp/census2000_raw_small.dta"), "/tmp/census2000_raw_small.dta", "${proj}/data/raw/census/census2000.dta")

capture which esttab
if _rc != 0 ssc install estout, replace
capture which areg
if _rc != 0 exit 198

global control "minority"
global hist_controls_all "c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post"

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
* county dictionary and mappings
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

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953 martyr_per100k_1953 martyr_count_1931_1945 pop_1953
duplicates drop countyid_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

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
tempfile histctrl
save `histctrl'
global histctrl_tmp "`histctrl'"

use countyid region1990 using "${proj}/data/raw/census_1990_county_char.dta", clear
drop if missing(countyid) | missing(region1990)
gen str6 old6 = string(countyid, "%06.0f")
gen str6 county_curr6 = string(region1990, "%06.0f")
keep old6 county_curr6
duplicates drop old6, force
tempfile map1990
save `map1990'
global map1990_tmp "`map1990'"

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

capture program drop _run_wave_main
program define _run_wave_main, rclass
    syntax , WAVE(integer) HI(integer)

    if `wave' == 1982 {
        use countyid birthyr eduy ethniccn using "$p1982raw", clear
        drop if missing(countyid) | missing(birthyr) | missing(eduy)
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen minority = (ethniccn!=1) if !missing(ethniccn)
    }

    if `wave' == 1990 {
        use county age_c age educ race using "$p1990raw", clear
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
        use uid birthyr eduyr race using "$p2000raw", clear
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
    merge m:1 countyid_curr6 using "$histctrl_tmp", keep(master match) nogen
    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
        replace `v' = 0 if missing(`v')
    }

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)

    quietly count
    return scalar n_obs = r(N)
    egen __tagc = tag(county_num)
    quietly count if __tagc==1
    local n_counties_local = r(N)
    return scalar n_counties = r(N)
    drop __tagc

    quietly areg eduy c.ln_martyr_per100k_1953##ib0.post i.birth_i minority, absorb(county_num) vce(cluster county_num)
    estimates store m`wave'_base
    estadd local Controls "Y"
    estadd local Hist_Control "None"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "1940"
    estadd scalar N_counties = `n_counties_local'
    return scalar b1 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se1 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p1 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))

    quietly areg eduy c.ln_martyr_per100k_1953##ib0.post i.birth_i minority $hist_controls_all, absorb(county_num) vce(cluster county_num)
    estimates store m`wave'_full
    estadd local Controls "Y"
    estadd local Hist_Control "All five"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "1940"
    estadd scalar N_counties = `n_counties_local'
    return scalar b2 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se2 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p2 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
end

eststo clear
quietly _run_wave_main, wave(1982) hi(1960)
quietly _run_wave_main, wave(1990) hi(1968)
quietly _run_wave_main, wave(2000) hi(1978)

esttab m1982_base m1982_full m1990_base m1990_full m2000_base m2000_full using "${proj}/result/table/main_micro_eduy_cutoff1940_raw_mainstyle_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 baseline" "1982 + all five" "1990 baseline" "1990 + all five" "2000 baseline" "2000 + all five") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N_counties N r2_a, labels("Individual controls" "County history control" "County FE" "Cohort FE" "Treatment start" "Counties" "Observations" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

esttab m1982_base m1982_full m1990_base m1990_full m2000_base m2000_full using "${proj}/result/table/main_micro_eduy_cutoff1940_raw_mainstyle_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 baseline" "1982 + all five" "1990 baseline" "1990 + all five" "2000 baseline" "2000 + all five") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N_counties N r2_a, labels("Individual controls" "County history control" "County FE" "Cohort FE" "Treatment start" "Counties" "Observations" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' str4 wave str12 spec double b se p N N_clust using "${proj}/result/table/main_micro_eduy_cutoff1940_raw_mainstyle_v1_tmp.dta", replace
foreach w in 1982 1990 2000 {
    estimates restore m`w'_base
    post `memhold' ("`w'") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
        (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))
    estimates restore m`w'_full
    post `memhold' ("`w'") ("all_five") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
        (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))
}
postclose `memhold'
use "${proj}/result/table/main_micro_eduy_cutoff1940_raw_mainstyle_v1_tmp.dta", clear
export delimited using "${proj}/result/table/main_micro_eduy_cutoff1940_raw_mainstyle_v1.csv", replace
erase "${proj}/result/table/main_micro_eduy_cutoff1940_raw_mainstyle_v1_tmp.dta"
exit, clear
