/*--------------------------------------------------------------
  Individual-level heterogeneity: clan density (low vs high)
  All 3 census waves (1982, 1990, 2000), cutoff 1940
  DV = eduy (individual years of education)
  Absorb: county_num birth_i; cluster: county_num
  Output: .tex table in paper/assets/tables/
--------------------------------------------------------------*/
clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "minority"

global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")

capture which esttab
if _rc != 0 ssc install estout, replace

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
* mapping files for 1990 / 2000
*--------------------------------------------------------------
use county age_c age educ using "$c1990", clear
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
* clan data
*--------------------------------------------------------------
import delimited "${proj}/data/temp/county_clan_quake_controls_v1.csv", clear varnames(1) stringcols(_all)
keep countyid_curr6 clan_num
destring clan_num, replace force
gen clan_any = clan_num > 0 if !missing(clan_num)
replace clan_any = 0 if missing(clan_any)
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop countyid_curr6, force
tempfile clan
save `clan'
global clan_tmp "`clan'"

*--------------------------------------------------------------
* Run regressions: wave by wave, inline
*--------------------------------------------------------------
local waves "1982 1990 2000"
foreach w of local waves {
    foreach g in C0 C1 {
        local b_`w'_`g' .
        local se_`w'_`g' .
        local p_`w'_`g' .
        local n_`w'_`g' .
        local nc_`w'_`g' .
    }
}

* ---- Wave 1982 ----
di "=== Loading wave 1982 ==="
use countyid birthyr eduy ethniccn using "$c1982", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen minority = (ethniccn != 1) if !missing(ethniccn)
keep if inrange(birthyr, 1920, 1960)
drop if floor(birthyr)==1939
keep if inrange(eduy, 0, 25)
rename county_curr6 countyid_curr6
merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen
merge m:1 countyid_curr6 using "$clan_tmp", keep(master match) nogen keepusing(clan_any)
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)

di "=== 1982: clan_any == 0 ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control if clan_any==0, absorb(county_num birth_i) vce(cluster county_num)
local b_1982_C0 = _b[1.post#c.ln_martyr_per100k_1953]
local se_1982_C0 = _se[1.post#c.ln_martyr_per100k_1953]
local p_1982_C0 = 2*ttail(e(df_r), abs(`b_1982_C0'/`se_1982_C0'))
local n_1982_C0 = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_1982_C0 = r(N)
drop tagc

di "=== 1982: clan_any == 1 ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control if clan_any==1, absorb(county_num birth_i) vce(cluster county_num)
local b_1982_C1 = _b[1.post#c.ln_martyr_per100k_1953]
local se_1982_C1 = _se[1.post#c.ln_martyr_per100k_1953]
local p_1982_C1 = 2*ttail(e(df_r), abs(`b_1982_C1'/`se_1982_C1'))
local n_1982_C1 = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_1982_C1 = r(N)
drop tagc
di "=== 1982 done: C0 b=`b_1982_C0' n=`n_1982_C0'; C1 b=`b_1982_C1' n=`n_1982_C1' ==="

* ---- Wave 1990 ----
di "=== Loading wave 1990 ==="
use county age_c age educ race using "$c1990", clear
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
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1968)
drop if floor(birthyr)==1939
drop if missing(eduy)
keep if inrange(eduy, 0, 25)
merge m:1 countyid_curr6 using "$treat_tmp", keep(master match) nogen
merge m:1 countyid_curr6 using "$clan_tmp", keep(master match) nogen keepusing(clan_any)
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)

di "=== 1990: clan_any == 0 ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control if clan_any==0, absorb(county_num birth_i) vce(cluster county_num)
local b_1990_C0 = _b[1.post#c.ln_martyr_per100k_1953]
local se_1990_C0 = _se[1.post#c.ln_martyr_per100k_1953]
local p_1990_C0 = 2*ttail(e(df_r), abs(`b_1990_C0'/`se_1990_C0'))
local n_1990_C0 = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_1990_C0 = r(N)
drop tagc

di "=== 1990: clan_any == 1 ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control if clan_any==1, absorb(county_num birth_i) vce(cluster county_num)
local b_1990_C1 = _b[1.post#c.ln_martyr_per100k_1953]
local se_1990_C1 = _se[1.post#c.ln_martyr_per100k_1953]
local p_1990_C1 = 2*ttail(e(df_r), abs(`b_1990_C1'/`se_1990_C1'))
local n_1990_C1 = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_1990_C1 = r(N)
drop tagc
di "=== 1990 done: C0 b=`b_1990_C0' n=`n_1990_C0'; C1 b=`b_1990_C1' n=`n_1990_C1' ==="

* ---- Wave 2000 ----
di "=== Loading wave 2000 ==="
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
merge m:1 countyid_curr6 using "$clan_tmp", keep(master match) nogen keepusing(clan_any)
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)

di "=== 2000: clan_any == 0 ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control if clan_any==0, absorb(county_num birth_i) vce(cluster county_num)
local b_2000_C0 = _b[1.post#c.ln_martyr_per100k_1953]
local se_2000_C0 = _se[1.post#c.ln_martyr_per100k_1953]
local p_2000_C0 = 2*ttail(e(df_r), abs(`b_2000_C0'/`se_2000_C0'))
local n_2000_C0 = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_2000_C0 = r(N)
drop tagc

di "=== 2000: clan_any == 1 ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control if clan_any==1, absorb(county_num birth_i) vce(cluster county_num)
local b_2000_C1 = _b[1.post#c.ln_martyr_per100k_1953]
local se_2000_C1 = _se[1.post#c.ln_martyr_per100k_1953]
local p_2000_C1 = 2*ttail(e(df_r), abs(`b_2000_C1'/`se_2000_C1'))
local n_2000_C1 = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_2000_C1 = r(N)
drop tagc
di "=== 2000 done: C0 b=`b_2000_C0' n=`n_2000_C0'; C1 b=`b_2000_C1' n=`n_2000_C1' ==="

*--------------------------------------------------------------
* Export .tex table
*--------------------------------------------------------------

capture program drop _stars
program define _stars, rclass
    args p
    if `p' < 0.01      return local star "***"
    else if `p' < 0.05 return local star "**"
    else if `p' < 0.10 return local star "*"
    else                return local star ""
end

local texfile "${proj}/paper/assets/tables/main_individual_clan_heterogeneity_reghdfejl_v1.tex"

capture file close texout
file open texout using "`texfile'", write replace

file write texout "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write texout "\begin{tabular}{l*{6}{c}}" _n
file write texout "\toprule" _n
file write texout "            &\multicolumn{2}{c}{1982}&\multicolumn{2}{c}{1990}&\multicolumn{2}{c}{2000}\\" _n
file write texout "\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}" _n
file write texout "            &\multicolumn{1}{c}{Low-clan}&\multicolumn{1}{c}{High-clan}&\multicolumn{1}{c}{Low-clan}&\multicolumn{1}{c}{High-clan}&\multicolumn{1}{c}{Low-clan}&\multicolumn{1}{c}{High-clan}\\" _n
file write texout "\midrule" _n

* Stars
foreach w in 1982 1990 2000 {
    foreach g in C0 C1 {
        _stars `p_`w'_`g''
        local s_`w'_`g' = r(star)
    }
}

* Coefficient row
file write texout "Post $\times$ War exp."
foreach w in 1982 1990 2000 {
    foreach g in C0 C1 {
        local bv : di %9.3f `b_`w'_`g''
        file write texout "&" %14s "`bv'\sym{`s_`w'_`g''}"
    }
}
file write texout "\\" _n

* SE row
file write texout "            "
foreach w in 1982 1990 2000 {
    foreach g in C0 C1 {
        local sev : di %9.3f `se_`w'_`g''
        file write texout "&" %14s "(`sev')"
    }
}
file write texout "\\" _n

file write texout "\midrule" _n

file write texout "Individual controls"
forval i = 1/6 {
    file write texout "&         Yes"
}
file write texout "\\" _n

file write texout "County FE   "
forval i = 1/6 {
    file write texout "&         Yes"
}
file write texout "\\" _n

file write texout "Cohort FE   "
forval i = 1/6 {
    file write texout "&         Yes"
}
file write texout "\\" _n

* Observations
file write texout "\(N\)       "
foreach w in 1982 1990 2000 {
    foreach g in C0 C1 {
        local nv : di %12.0fc `n_`w'_`g''
        file write texout "&" %14s "`nv'"
    }
}
file write texout "\\" _n

file write texout "\bottomrule" _n
file write texout "\end{tabular}" _n
file write texout "}" _n

file close texout

di _n "=== Table written to: `texfile' ==="
di "=== Done ==="

exit, clear
