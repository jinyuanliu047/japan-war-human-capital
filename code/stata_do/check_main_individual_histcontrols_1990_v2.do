/*--------------------------------------------------------------
  Individual-level historical controls robustness: 1990 census
  Cutoff 1940 (drop 1939, post = birth_i >= 1940)
  DV = eduy (individual years of education)
  Absorb: county_num birth_i; cluster: county_num
  6 specs: Baseline, +SDY, +Famine, +Victims, +Grain, +Urban
  Output: .tex + .csv in paper/assets/tables/
--------------------------------------------------------------*/
clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global control "minority"

global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")

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
* mapping file for 1990
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

*--------------------------------------------------------------
* county-level historical controls
*--------------------------------------------------------------
use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64
gen ln_victims_cr   = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop countyid_curr6, force
tempfile ctrl
save `ctrl'
global ctrl_tmp "`ctrl'"

*--------------------------------------------------------------
* Load 1990 census, merge treatment + controls
*--------------------------------------------------------------
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
merge m:1 countyid_curr6 using "$ctrl_tmp", keep(match) nogen

gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)

*--------------------------------------------------------------
* Run 6 regressions (same sample throughout)
*--------------------------------------------------------------
* Ensure same sample: require non-missing on all control variables
mark _usesamp
markout _usesamp eduy ln_martyr_per100k_1953 post minority ///
    sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64

local specs "baseline sdy famine victims grain urban"

* Initialise storage
foreach s of local specs {
    local b_`s' .
    local se_`s' .
    local p_`s' .
    local n_`s' .
    local nc_`s' .
}

* (1) Baseline
di "=== Spec 1: Baseline ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post $control if _usesamp, absorb(county_num birth_i) vce(cluster county_num)
local b_baseline  = _b[1.post#c.ln_martyr_per100k_1953]
local se_baseline = _se[1.post#c.ln_martyr_per100k_1953]
local p_baseline  = 2*ttail(e(df_r), abs(`b_baseline'/`se_baseline'))
local n_baseline  = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_baseline = r(N)
drop tagc

* (2) +SDY
di "=== Spec 2: +SDY ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post c.sdy_density##ib0.post $control if _usesamp, absorb(county_num birth_i) vce(cluster county_num)
local b_sdy  = _b[1.post#c.ln_martyr_per100k_1953]
local se_sdy = _se[1.post#c.ln_martyr_per100k_1953]
local p_sdy  = 2*ttail(e(df_r), abs(`b_sdy'/`se_sdy'))
local n_sdy  = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_sdy = r(N)
drop tagc

* (3) +Famine
di "=== Spec 3: +Famine ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post c.ins_famine##ib0.post $control if _usesamp, absorb(county_num birth_i) vce(cluster county_num)
local b_famine  = _b[1.post#c.ln_martyr_per100k_1953]
local se_famine = _se[1.post#c.ln_martyr_per100k_1953]
local p_famine  = 2*ttail(e(df_r), abs(`b_famine'/`se_famine'))
local n_famine  = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_famine = r(N)
drop tagc

* (4) +Victims
di "=== Spec 4: +Victims ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post c.ln_victims_cr##ib0.post $control if _usesamp, absorb(county_num birth_i) vce(cluster county_num)
local b_victims  = _b[1.post#c.ln_martyr_per100k_1953]
local se_victims = _se[1.post#c.ln_martyr_per100k_1953]
local p_victims  = 2*ttail(e(df_r), abs(`b_victims'/`se_victims'))
local n_victims  = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_victims = r(N)
drop tagc

* (5) +Grain
di "=== Spec 5: +Grain ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post c.ln_grain_output##ib0.post $control if _usesamp, absorb(county_num birth_i) vce(cluster county_num)
local b_grain  = _b[1.post#c.ln_martyr_per100k_1953]
local se_grain = _se[1.post#c.ln_martyr_per100k_1953]
local p_grain  = 2*ttail(e(df_r), abs(`b_grain'/`se_grain'))
local n_grain  = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_grain = r(N)
drop tagc

* (6) +Urban
di "=== Spec 6: +Urban ==="
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post c.urbanratio64##ib0.post $control if _usesamp, absorb(county_num birth_i) vce(cluster county_num)
local b_urban  = _b[1.post#c.ln_martyr_per100k_1953]
local se_urban = _se[1.post#c.ln_martyr_per100k_1953]
local p_urban  = 2*ttail(e(df_r), abs(`b_urban'/`se_urban'))
local n_urban  = e(N)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc_urban = r(N)
drop tagc

di "=== All regressions done ==="

*--------------------------------------------------------------
* Export .csv
*--------------------------------------------------------------
local csvfile "${proj}/paper/assets/tables/main_individual_histcontrols_1990_cutoff1940_v2.csv"

capture file close csvout
file open csvout using "`csvfile'", write replace
file write csvout "spec,b,se,p,N,N_clust" _n

foreach s of local specs {
    local bv : di %12.6f `b_`s''
    local sev : di %12.6f `se_`s''
    local pv : di %12.6f `p_`s''
    local nv : di %12.0f `n_`s''
    local ncv : di %12.0f `nc_`s''
    file write csvout "`s',`bv',`sev',`pv',`nv',`ncv'" _n
}

file close csvout
di "=== CSV written to: `csvfile' ==="

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

local texfile "${proj}/paper/assets/tables/main_individual_histcontrols_1990_cutoff1940_v2.tex"

capture file close texout
file open texout using "`texfile'", write replace

file write texout "{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write texout "\begin{tabular}{l*{6}{c}}" _n
file write texout "\toprule" _n
file write texout "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}\\" _n
file write texout "            &\multicolumn{1}{c}{Baseline}&\multicolumn{1}{c}{+SDY}&\multicolumn{1}{c}{+Famine}&\multicolumn{1}{c}{+Victims}&\multicolumn{1}{c}{+Grain}&\multicolumn{1}{c}{+Urban}\\" _n
file write texout "\midrule" _n

* Stars
foreach s of local specs {
    _stars `p_`s''
    local star_`s' = r(star)
}

* Coefficient row
file write texout "Post $\times$ War exp."
foreach s of local specs {
    local bv : di %9.3f `b_`s''
    file write texout "&" %14s "`bv'\sym{`star_`s''}"
}
file write texout "\\" _n

* SE row
file write texout "            "
foreach s of local specs {
    local sev : di %9.3f `se_`s''
    file write texout "&" %14s "(`sev')"
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
foreach s of local specs {
    local nv : di %12.0fc `n_`s''
    file write texout "&" %14s "`nv'"
}
file write texout "\\" _n

file write texout "\bottomrule" _n
file write texout "\end{tabular}" _n
file write texout "}" _n

file close texout

di _n "=== Table written to: `texfile' ==="
di "=== Done ==="

exit, clear
