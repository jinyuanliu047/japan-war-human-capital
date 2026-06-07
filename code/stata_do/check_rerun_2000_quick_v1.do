/*--------------------------------------------------------------
  Quick re-run: 2000 census only, cutoff 1946 + rev history
  Uses same infrastructure as IHS do file (new mapping)
--------------------------------------------------------------*/
clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "minority"
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")

capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

* county dictionary
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

* 1982 crosswalk
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

* _resolve_old6_map (full version)
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

* _stars helper
capture program drop _stars
program define _stars, sclass
    args pval
    if `pval' < 0.01      sclass local s "***"
    else if `pval' < 0.05 sclass local s "**"
    else if `pval' < 0.10 sclass local s "*"
    else                   sclass local s ""
end

* treatment
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
tempfile treat
save `treat'
global treat_tmp "`treat'"

* revolutionary history controls
use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop countyid_curr6, force
tempfile ctrl
save `ctrl'
global ctrl_tmp "`ctrl'"

* revolutionary proxy (Long March / Korean War)
capture confirm file "${proj}/data/temp/revolutionary_proxy_controls_v1.dta"
if _rc == 0 {
    use "${proj}/data/temp/revolutionary_proxy_controls_v1.dta", clear
    capture keep countyid_curr6 ln_longmarch_martyr_count ln_korea_war_martyr_count
    if _rc != 0 {
        keep countyid_curr6
        gen ln_longmarch_martyr_count = 0
        gen ln_korea_war_martyr_count = 0
    }
    foreach v in ln_longmarch_martyr_count ln_korea_war_martyr_count {
        replace `v' = 0 if missing(`v')
    }
    replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
    duplicates drop countyid_curr6, force
    tempfile revproxy
    save `revproxy'
    global revproxy_tmp "`revproxy'"
}

* 2000 county map (new mapping)
use uid birthyr eduyr using "$c2000", clear
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

* Load 2000 census
di "=== Loading 2000 census ==="
use uid birthyr eduyr race using "$c2000", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1978)
drop if missing(eduy)
keep if inrange(eduy, 0, 25)
merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen

* Save full dataset for both parts
tempfile full2000
save `full2000'

*--------------------------------------------------------------
* Part 1: Cutoff 1946
*--------------------------------------------------------------
di _n "========== CUTOFF 1946 =========="
use `full2000', clear
drop if floor(birthyr)==1945
gen birth_i = floor(birthyr)
gen post = birth_i >= 1946
egen county_num = group(countyid_curr6)

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control, absorb(county_num birth_i) vce(cluster county_num)
di "Cutoff 1946: b = " _b[1.post#c.ln_martyr_per100k_1953] " se = " _se[1.post#c.ln_martyr_per100k_1953] " N = " e(N)
local b_1946 = _b[1.post#c.ln_martyr_per100k_1953]
local se_1946 = _se[1.post#c.ln_martyr_per100k_1953]
local n_1946 = e(N)

*--------------------------------------------------------------
* Part 2: Revolutionary history (cutoff 1940)
*--------------------------------------------------------------
di _n "========== REV HISTORY CUTOFF 1940 =========="
use `full2000', clear
drop if floor(birthyr)==1939
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
merge m:1 countyid_curr6 using "$ctrl_tmp", keep(match) nogen
capture merge m:1 countyid_curr6 using "$revproxy_tmp", keep(master match) nogen
foreach v in sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 ln_longmarch_martyr_count ln_korea_war_martyr_count {
    capture replace `v' = 0 if missing(`v')
}
egen county_num = group(countyid_curr6)

* (1) Full baseline (with all history controls)
di "=== Rev hist: full baseline ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post ///
    c.sdy_density##ib0.post c.ins_famine##ib0.post c.ln_victims_cr##ib0.post ///
    c.ln_grain_output##ib0.post c.urbanratio64##ib0.post ///
    $control, absorb(county_num birth_i) vce(cluster county_num)
di "Full baseline: b = " _b[1.post#c.ln_martyr_per100k_1953] " se = " _se[1.post#c.ln_martyr_per100k_1953] " N = " e(N)
local b_full = _b[1.post#c.ln_martyr_per100k_1953]
local se_full = _se[1.post#c.ln_martyr_per100k_1953]
local n_full = e(N)

* (2) + Long March
di "=== Rev hist: + Long March ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post ///
    c.sdy_density##ib0.post c.ins_famine##ib0.post c.ln_victims_cr##ib0.post ///
    c.ln_grain_output##ib0.post c.urbanratio64##ib0.post ///
    c.ln_longmarch_martyr_count##ib0.post ///
    $control, absorb(county_num birth_i) vce(cluster county_num)
di "+ Long March: b = " _b[1.post#c.ln_martyr_per100k_1953] " se = " _se[1.post#c.ln_martyr_per100k_1953] " N = " e(N)
local b_lm = _b[1.post#c.ln_martyr_per100k_1953]
local se_lm = _se[1.post#c.ln_martyr_per100k_1953]
local n_lm = e(N)

* (3) + Korean War
di "=== Rev hist: + Korean War ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post ///
    c.sdy_density##ib0.post c.ins_famine##ib0.post c.ln_victims_cr##ib0.post ///
    c.ln_grain_output##ib0.post c.urbanratio64##ib0.post ///
    c.ln_korea_war_martyr_count##ib0.post ///
    $control, absorb(county_num birth_i) vce(cluster county_num)
di "+ Korean War: b = " _b[1.post#c.ln_martyr_per100k_1953] " se = " _se[1.post#c.ln_martyr_per100k_1953] " N = " e(N)
local b_kw = _b[1.post#c.ln_martyr_per100k_1953]
local se_kw = _se[1.post#c.ln_martyr_per100k_1953]
local n_kw = e(N)

* (4) + Both
di "=== Rev hist: + Both ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post ///
    c.sdy_density##ib0.post c.ins_famine##ib0.post c.ln_victims_cr##ib0.post ///
    c.ln_grain_output##ib0.post c.urbanratio64##ib0.post ///
    c.ln_longmarch_martyr_count##ib0.post c.ln_korea_war_martyr_count##ib0.post ///
    $control, absorb(county_num birth_i) vce(cluster county_num)
di "+ Both: b = " _b[1.post#c.ln_martyr_per100k_1953] " se = " _se[1.post#c.ln_martyr_per100k_1953] " N = " e(N)
local b_both = _b[1.post#c.ln_martyr_per100k_1953]
local se_both = _se[1.post#c.ln_martyr_per100k_1953]
local n_both = e(N)

*--------------------------------------------------------------
* Print summary
*--------------------------------------------------------------
di _n "=========================================="
di "SUMMARY OF RESULTS"
di "=========================================="
di "Cutoff 1946:    b=" %7.4f `b_1946' " se=" %7.4f `se_1946' " N=" %12.0fc `n_1946'
di "Rev full:       b=" %7.4f `b_full' " se=" %7.4f `se_full' " N=" %12.0fc `n_full'
di "Rev +LM:        b=" %7.4f `b_lm'   " se=" %7.4f `se_lm'   " N=" %12.0fc `n_lm'
di "Rev +KW:        b=" %7.4f `b_kw'   " se=" %7.4f `se_kw'   " N=" %12.0fc `n_kw'
di "Rev +Both:      b=" %7.4f `b_both' " se=" %7.4f `se_both' " N=" %12.0fc `n_both'
di "=========================================="

exit, clear
