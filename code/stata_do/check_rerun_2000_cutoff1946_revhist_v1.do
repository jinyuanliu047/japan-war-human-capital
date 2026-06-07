/*--------------------------------------------------------------
  Individual-level regressions: 2000 census only
  Part 1: Baseline with cutoff 1946, birth year range 1920-1978
  Part 2: Revolutionary history controls with cutoff 1940
  Output:
    rerun_2000_cutoff1946_v1.csv       (Part 1)
    rerun_2000_revhist_v1.csv          (Part 2)
--------------------------------------------------------------*/
clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "minority"

global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")

*--------------------------------------------------------------
* county dictionary and 1982 crosswalk
*--------------------------------------------------------------
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

*--------------------------------------------------------------
* helper: resolve old6 -> county_curr6 (full version)
*--------------------------------------------------------------
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

*--------------------------------------------------------------
* treatment
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
tempfile treat
save `treat'
global treat_tmp "`treat'"

*--------------------------------------------------------------
* county map for 2000 census
*--------------------------------------------------------------
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

*--------------------------------------------------------------
* revolutionary history controls (longmarch, korean war)
*--------------------------------------------------------------
use "${proj}/data/temp/revolutionary_proxy_controls_v1.dta", clear
keep countyid_curr6 ln_longmarch_martyr_count ln_korea_war_martyr_count
foreach v in ln_longmarch_martyr_count ln_korea_war_martyr_count {
    replace `v' = 0 if missing(`v')
}
* Create level variables for c.var##ib0.post syntax
gen longmarch   = ln_longmarch_martyr_count
gen korean_war  = ln_korea_war_martyr_count
duplicates drop countyid_curr6, force
tempfile revhist
save `revhist'
global revhist_tmp "`revhist'"

*==============================================================
* PART 1: Baseline with cutoff 1946 (2000 census only)
*==============================================================
di _n "=== Part 1: Cutoff 1946 baseline ==="

use uid birthyr eduyr race using "$c2000", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1978)
drop if floor(birthyr)==1945
drop if missing(eduy)
keep if inrange(eduy, 0, 25)
merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen
gen birth_i = floor(birthyr)
gen post = birth_i >= 1946
egen county_num = group(countyid_curr6)

di "=== 2000: OLS ln, cutoff 1946 ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control, absorb(county_num birth_i) vce(cluster county_num)
local b1  = _b[1.post#c.ln_martyr_per100k_1953]
local se1 = _se[1.post#c.ln_martyr_per100k_1953]
local p1  = 2*ttail(e(df_r), abs(`b1'/`se1'))
local n1  = e(N)

* Export Part 1 results
preserve
    clear
    set obs 1
    gen b  = `b1'
    gen se = `se1'
    gen p  = `p1'
    gen N  = `n1'
    export delimited using "${proj}/paper/assets/tables/rerun_2000_cutoff1946_v1.csv", replace
restore

di "=== Part 1 done ==="

*==============================================================
* PART 2: Revolutionary history controls (cutoff 1940)
*==============================================================
di _n "=== Part 2: Revolutionary history controls, cutoff 1940 ==="

use uid birthyr eduyr race using "$c2000", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1978)
drop if floor(birthyr)==1939
drop if missing(eduy)
keep if inrange(eduy, 0, 25)
merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen
merge m:1 countyid_curr6 using "$revhist_tmp", keep(master match) nogen
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)

* Spec 1: Full baseline (no revolutionary history interactions)
di "=== Spec 1: baseline ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control, absorb(county_num birth_i) vce(cluster county_num)
local b_s1  = _b[1.post#c.ln_martyr_per100k_1953]
local se_s1 = _se[1.post#c.ln_martyr_per100k_1953]
local p_s1  = 2*ttail(e(df_r), abs(`b_s1'/`se_s1'))
local n_s1  = e(N)

* Spec 2: + Long March interaction
di "=== Spec 2: + Long March ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post c.longmarch##ib0.post $control, absorb(county_num birth_i) vce(cluster county_num)
local b_s2  = _b[1.post#c.ln_martyr_per100k_1953]
local se_s2 = _se[1.post#c.ln_martyr_per100k_1953]
local p_s2  = 2*ttail(e(df_r), abs(`b_s2'/`se_s2'))
local n_s2  = e(N)

* Spec 3: + Korean War interaction
di "=== Spec 3: + Korean War ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post c.korean_war##ib0.post $control, absorb(county_num birth_i) vce(cluster county_num)
local b_s3  = _b[1.post#c.ln_martyr_per100k_1953]
local se_s3 = _se[1.post#c.ln_martyr_per100k_1953]
local p_s3  = 2*ttail(e(df_r), abs(`b_s3'/`se_s3'))
local n_s3  = e(N)

* Spec 4: + Both Long March and Korean War
di "=== Spec 4: + Both ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post c.longmarch##ib0.post c.korean_war##ib0.post $control, absorb(county_num birth_i) vce(cluster county_num)
local b_s4  = _b[1.post#c.ln_martyr_per100k_1953]
local se_s4 = _se[1.post#c.ln_martyr_per100k_1953]
local p_s4  = 2*ttail(e(df_r), abs(`b_s4'/`se_s4'))
local n_s4  = e(N)

* Export Part 2 results
preserve
    clear
    set obs 4
    gen str12 spec = ""
    gen b  = .
    gen se = .
    gen p  = .
    gen N  = .

    replace spec = "baseline"  in 1
    replace b    = `b_s1'      in 1
    replace se   = `se_s1'     in 1
    replace p    = `p_s1'      in 1
    replace N    = `n_s1'      in 1

    replace spec = "longmarch" in 2
    replace b    = `b_s2'      in 2
    replace se   = `se_s2'     in 2
    replace p    = `p_s2'      in 2
    replace N    = `n_s2'      in 2

    replace spec = "korea"     in 3
    replace b    = `b_s3'      in 3
    replace se   = `se_s3'     in 3
    replace p    = `p_s3'      in 3
    replace N    = `n_s3'      in 3

    replace spec = "both"      in 4
    replace b    = `b_s4'      in 4
    replace se   = `se_s4'     in 4
    replace p    = `p_s4'      in 4
    replace N    = `n_s4'      in 4

    export delimited using "${proj}/paper/assets/tables/rerun_2000_revhist_v1.csv", replace
restore

di _n "=== All done ==="
di "  Part 1 output: ${proj}/paper/assets/tables/rerun_2000_cutoff1946_v1.csv"
di "  Part 2 output: ${proj}/paper/assets/tables/rerun_2000_revhist_v1.csv"

exit, clear
