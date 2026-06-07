*******************************************************
* Combined heterogeneity (reghdfejl, one table)
* - Gender: male vs female (1982/1990/2000)
* - Urban-rural: urban vs rural (1990/2000)
* - University relocation: reloc_any==0 vs 1 (1982/1990/2000)
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
    di as error "reghdfejl not found. Please install reghdfejl first."
    exit 198
}

import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
keep GBCounty
destring GBCounty, replace force
drop if missing(GBCounty)
gen str6 old6 = string(GBCounty, "%06.0f")
gen str6 curr_dict = old6
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
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'
global cw1982_tmp "`cw1982'"

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
duplicates drop countyid_curr6, force
tempfile treat
save `treat'
global treat_tmp "`treat'"

use "${proj}/data/temp/county_university_relocation_any_v1.dta", clear
keep countyid_curr6 reloc_any
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
replace reloc_any = 0 if missing(reloc_any)
duplicates drop countyid_curr6, force
tempfile reloc
save `reloc'
global reloc_tmp "`reloc'"

import delimited "${proj}/data/temp/countyid_2000_to_current_routes_v1.csv", clear varnames(1) stringcols(_all)
rename county_old6 old6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = subinstr(county_curr6, ".0", "", .)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile map2000
save `map2000'
global map2000_tmp "`map2000'"

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

capture program drop _prep_wave_subgroup
program define _prep_wave_subgroup
    syntax , WAVE(integer) HI(integer) GROUP(string)

    if `wave' == 1982 {
        use countyid birthyr eduy sex ethniccn using "${proj}/data/temp/census_1982_cleaned.dta", clear
        drop if missing(countyid) | missing(birthyr) | missing(eduy)
        gen str6 old6 = string(countyid, "%06.0f")
        merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen female = (sex==2) if !missing(sex)
        gen minority = (ethniccn!=1) if !missing(ethniccn)
        gen urban_tag = .
        gen rural_tag = .
    }

    if `wave' == 1990 {
        use region1990 year_birth yedu male han_ethn rural using "${proj}/data/raw/census_1990_clean.dta", clear
        drop if missing(region1990) | missing(year_birth) | missing(yedu)
        gen str6 old6 = string(region1990, "%06.0f")
        _resolve_old6_map
        keep if county_curr6!=""
        rename county_curr6 countyid_curr6
        gen birthyr = year_birth
        gen eduy = yedu
        gen female = (male==0) if !missing(male)
        gen minority = (han_ethn==0) if !missing(han_ethn)
        gen rural_tag = (rural==1) if !missing(rural)
        gen urban_tag = (rural==0) if !missing(rural)
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
        gen urban_tag = (urban==1) if !missing(urban)
        gen rural_tag = (rural==1) if !missing(rural)
    }

    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    drop if missing(eduy)
    keep if inrange(eduy,0,25)

    merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen
    merge m:1 countyid_curr6 using "$reloc_tmp", keep(master match) nogen
    replace reloc_any = 0 if missing(reloc_any)

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940

    if "`group'"=="male" keep if female==0
    if "`group'"=="female" keep if female==1
    if "`group'"=="urban" keep if urban_tag==1
    if "`group'"=="rural" keep if rural_tag==1
    if "`group'"=="reloc0" keep if reloc_any==0
    if "`group'"=="reloc1" keep if reloc_any==1

    collapse (mean) eduy, by(countyid_curr6 birth_i ln_martyr_per100k_1953)
    rename eduy eduy_mean

    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)
end

capture program drop _run_one
program define _run_one, rclass
    syntax , WAVE(integer) HI(integer) GROUP(string) MODEL(string)

    quietly _prep_wave_subgroup, wave(`wave') hi(`hi') group("`group'")

    quietly count
    return scalar n_cells = r(N)
    egen __tagc = tag(county_num)
    quietly count if __tagc==1
    return scalar n_counties = r(N)
    drop __tagc

    reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post, absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Group "`group'"
    estadd local Wave "`wave'"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar N_counties = r(n_counties)
    return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
end

eststo clear

tempfile sum
clear
set obs 0
gen str6 wave = ""
gen str12 subgroup = ""
gen b = .
gen se = .
gen p = .
gen n_cells = .
gen n_counties = .
save `sum', replace

local models ""

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978

    foreach g in male female reloc0 reloc1 {
        local m = "h`w'_`g'"
        quietly _run_one, wave(`w') hi(`hi') group("`g'") model("`m'")
        local models "`models' `m'"
        use `sum', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        replace subgroup = "`g'" in `n'
        replace b = r(b) in `n'
        replace se = r(se) in `n'
        replace p = r(p) in `n'
        replace n_cells = r(n_cells) in `n'
        replace n_counties = r(n_counties) in `n'
        save `sum', replace
    }
}

foreach w in 1990 2000 {
    local hi = 1968
    if "`w'"=="2000" local hi = 1978
    foreach g in urban rural {
        local m = "h`w'_`g'"
        quietly _run_one, wave(`w') hi(`hi') group("`g'") model("`m'")
        local models "`models' `m'"
        use `sum', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        replace subgroup = "`g'" in `n'
        replace b = r(b) in `n'
        replace se = r(se) in `n'
        replace p = r(p) in `n'
        replace n_cells = r(n_cells) in `n'
        replace n_counties = r(n_counties) in `n'
        save `sum', replace
    }
}

use `sum', clear
gen t_abs = abs(b/se)
sort wave subgroup
export delimited using "${proj}/result/table/main_heterogeneity_combined_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_heterogeneity_combined_reghdfejl_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/main_heterogeneity_combined_reghdfejl_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Wave County_FE Cohort_FE N_counties) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/main_heterogeneity_combined_reghdfejl_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Wave County_FE Cohort_FE N_counties) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
