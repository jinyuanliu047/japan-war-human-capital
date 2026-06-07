*******************************************************
* Main robustness: individual yedu with revolutionary-history proxies
* Cutoff 1940, raw census chain
*******************************************************

clear all
set more off
args targetwave

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/raw/census/census1990.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

global control "minority"

local c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
local c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
local c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")

capture log close
if "`targetwave'" == "" log using "${proj}/result/table/check_main_individual_longmarch_korea_v1.log", replace text
else log using "${proj}/result/table/check_main_individual_longmarch_korea_`targetwave'_v1.log", replace text

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

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
* treatment and controls
*******************************************************
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile treat
save `treat'

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
drop if county_curr6=="" | county_curr6=="000000"
duplicates drop county_curr6, force
tempfile revproxy
use "${proj}/data/temp/revolutionary_proxy_controls_v1.dta", clear
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
save `revproxy'
use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
drop if county_curr6=="" | county_curr6=="000000"
duplicates drop county_curr6, force
merge 1:1 county_curr6 using `revproxy', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death ln_korea_war_martyr_count ln_longmarch_martyr_count {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
tempfile ctrl
save `ctrl'

*******************************************************
* map 1990 and 2000 raw county codes
*******************************************************
use county age_c age educ using "`c1990'", clear
drop if missing(county)
gen str6 old6 = string(county, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map1990
save `map1990'

import delimited "${proj}/data/temp/countyid_2000_to_current_routes_v1.csv", clear varnames(1) stringcols(_all)
rename county_old6 old6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile map2000
save `map2000'

tempfile summary
postfile sumhold str4 wave str12 spec double b se p n_obs r2 ar2 using `summary', replace

capture program drop _grab
program define _grab, rclass
    capture return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    capture return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    if _rc != 0 {
        return scalar b = _b[c.ln_martyr_per100k_1953#1.post]
        return scalar se = _se[c.ln_martyr_per100k_1953#1.post]
    }
    return scalar p = 2*ttail(e(df_r), abs(return(b)/return(se)))
end

*******************************************************
* 1982
*******************************************************
use countyid birthyr eduy ethniccn using "`c1982'", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using `cw1982', keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen birth_i = floor(birthyr)
gen minority = (ethniccn!=1) if !missing(ethniccn)
keep if inrange(birth_i, 1920, 1960)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1939
gen post = birth_i >= 1940
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `ctrl', keep(master match) nogen
egen county_num = group(county_curr6)

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
    absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("1982") ("base") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 1982 base"

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
    c.ln_longmarch_martyr_count#c.post, absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("1982") ("longmarch") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 1982 longmarch"

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
    c.ln_korea_war_martyr_count#c.post, absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("1982") ("korea") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 1982 korea"

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
    c.ln_longmarch_martyr_count#c.post c.ln_korea_war_martyr_count#c.post, ///
    absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("1982") ("both") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 1982 both"

*******************************************************
* 1990
*******************************************************
use county age_c age educ race using "`c1990'", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using `map1990', keep(master match) nogen
keep if county_curr6!=""
gen birthyr = 1000 + age_c*100 + age
gen birth_i = floor(birthyr)
gen eduy = .
replace eduy = 0  if educ==1
replace eduy = 6  if educ==2
replace eduy = 9  if educ==3
replace eduy = 12 if inlist(educ,4,5)
replace eduy = 15 if educ==6
replace eduy = 16 if educ==7
gen minority = (race!=1) if !missing(race)
keep if inrange(birth_i, 1920, 1968)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1939
gen post = birth_i >= 1940
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `ctrl', keep(master match) nogen
egen county_num = group(county_curr6)

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
    absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("1990") ("base") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 1990 base"

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
    c.ln_longmarch_martyr_count#c.post, absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("1990") ("longmarch") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 1990 longmarch"

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
    c.ln_korea_war_martyr_count#c.post, absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("1990") ("korea") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 1990 korea"

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
    c.ln_longmarch_martyr_count#c.post c.ln_korea_war_martyr_count#c.post, ///
    absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("1990") ("both") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 1990 both"

*******************************************************
* 2000
*******************************************************
use uid birthyr eduyr race using "`c2000'", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using `map2000', keep(master match) nogen
keep if county_curr6!=""
gen birth_i = floor(birthyr)
gen eduy = eduyr
gen minority = (race!=1) if !missing(race)
keep if inrange(birth_i, 1920, 1978)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1939
gen post = birth_i >= 1940
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `ctrl', keep(master match) nogen
egen county_num = group(county_curr6)

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
    absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("2000") ("base") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 2000 base"

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
    c.ln_longmarch_martyr_count#c.post, absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("2000") ("longmarch") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 2000 longmarch"

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
    c.ln_korea_war_martyr_count#c.post, absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("2000") ("korea") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 2000 korea"

quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control ///
    c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
    c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
    c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
    c.ln_longmarch_martyr_count#c.post c.ln_korea_war_martyr_count#c.post, ///
    absorb(county_num birth_i) vce(cluster county_num)
quietly _grab
post sumhold ("2000") ("both") (r(b)) (r(se)) (r(p)) (e(N)) (e(r2)) (e(r2_a))
noi di "finished 2000 both"

postclose sumhold
use `summary', clear
if "`targetwave'" == "" export delimited using "${proj}/result/table/main_individual_longmarch_korea_v1.csv", replace
else export delimited using "${proj}/result/table/main_individual_longmarch_korea_`targetwave'_v1.csv", replace

log close
exit, clear
