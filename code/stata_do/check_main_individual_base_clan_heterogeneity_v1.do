clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/raw/census/census1990.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"
local c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")

capture which esttab
if _rc != 0 ssc install estout, replace

import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
keep GBCounty
destring GBCounty, replace force
drop if missing(GBCounty)
gen str6 county_curr6 = string(GBCounty, "%06.0f")
gen str6 old6 = county_curr6
keep old6 county_curr6
duplicates drop old6, force
tempfile county_dict
save `county_dict'

import delimited "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", clear varnames(1) stringcols(_all)
rename countyid_old6 old6
rename countyid_curr6_final county_curr6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'

import delimited "${proj}/data/temp/countyid_2000_to_current_routes_v1.csv", clear varnames(1) stringcols(_all)
rename county_old6 old6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile map2000
save `map2000'

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile treat
save `treat'

import delimited "${proj}/data/temp/county_completion_pre1940_wave1982_v1.csv", clear varnames(1) stringcols(_all)
keep countyid_curr6 mid_comp_pre
rename countyid_curr6 county_curr6
destring mid_comp_pre, replace force
egen baseedu_tercile = xtile(mid_comp_pre), nq(3)
keep county_curr6 baseedu_tercile
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile base1982
save `base1982'

import delimited "${proj}/data/temp/county_completion_pre1940_wave1990_v1.csv", clear varnames(1) stringcols(_all)
keep countyid_curr6 mid_comp_pre
rename countyid_curr6 county_curr6
destring mid_comp_pre, replace force
egen baseedu_tercile = xtile(mid_comp_pre), nq(3)
keep county_curr6 baseedu_tercile
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile base1990
save `base1990'

import delimited "${proj}/data/temp/county_completion_pre1940_wave2000_v1.csv", clear varnames(1) stringcols(_all)
keep countyid_curr6 mid_comp_pre
rename countyid_curr6 county_curr6
destring mid_comp_pre, replace force
egen baseedu_tercile = xtile(mid_comp_pre), nq(3)
keep county_curr6 baseedu_tercile
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile base2000
save `base2000'

import delimited "${proj}/data/temp/county_clan_quake_controls_v1.csv", clear varnames(1) stringcols(_all)
keep countyid_curr6 clan_num
rename countyid_curr6 county_curr6
destring clan_num, replace force
gen clan_any = clan_num > 0 if !missing(clan_num)
replace clan_any = 0 if missing(clan_any)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile clan
save `clan'

capture program drop _resolve_old6_map
program define _resolve_old6_map
    gen str6 county_curr6 = ""
    merge m:1 old6 using "`cw1982'", keep(master match) nogen
    replace county_curr6 = county_curr6 if county_curr6!=""
end

tempfile summarytmp

local b_base_B1 .
local se_base_B1 .
local p_base_B1 .
local nobs_base_B1 .
local ncty_base_B1 .

local b_base_B2 .
local se_base_B2 .
local p_base_B2 .
local nobs_base_B2 .
local ncty_base_B2 .

local b_base_B3 .
local se_base_B3 .
local p_base_B3 .
local nobs_base_B3 .
local ncty_base_B3 .

local b_clan_C0 .
local se_clan_C0 .
local p_clan_C0 .
local nobs_clan_C0 .
local ncty_clan_C0 .

local b_clan_C1 .
local se_clan_C1 .
local p_clan_C1 .
local nobs_clan_C1 .
local ncty_clan_C1 .

use countyid birthyr eduy ethniccn using "`c1982'", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using `cw1982', keep(master match) nogen
keep if county_curr6!=""
gen birth_i = floor(birthyr)
keep if inrange(birth_i, 1920, 1960)
drop if birth_i == 1939
keep if inrange(eduy, 0, 25)
gen post = birth_i >= 1940
gen minority = (ethniccn != 1) if !missing(ethniccn)
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `base1982', keep(master match) nogen
merge m:1 county_curr6 using `clan', keep(master match) nogen
egen county_num = group(county_curr6)
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority if baseedu_tercile==1, absorb(county_num birth_i) vce(cluster county_num)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc = r(N)
drop tagc
local b_base_B1 = _b[1.post#c.ln_martyr_per100k_1953]
local se_base_B1 = _se[1.post#c.ln_martyr_per100k_1953]
local p_base_B1 = 2*ttail(e(df_r), abs(`b_base_B1'/`se_base_B1'))
local nobs_base_B1 = e(N)
local ncty_base_B1 = `nc'
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority if baseedu_tercile==2, absorb(county_num birth_i) vce(cluster county_num)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc = r(N)
drop tagc
local b_base_B2 = _b[1.post#c.ln_martyr_per100k_1953]
local se_base_B2 = _se[1.post#c.ln_martyr_per100k_1953]
local p_base_B2 = 2*ttail(e(df_r), abs(`b_base_B2'/`se_base_B2'))
local nobs_base_B2 = e(N)
local ncty_base_B2 = `nc'
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority if baseedu_tercile==3, absorb(county_num birth_i) vce(cluster county_num)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc = r(N)
drop tagc
local b_base_B3 = _b[1.post#c.ln_martyr_per100k_1953]
local se_base_B3 = _se[1.post#c.ln_martyr_per100k_1953]
local p_base_B3 = 2*ttail(e(df_r), abs(`b_base_B3'/`se_base_B3'))
local nobs_base_B3 = e(N)
local ncty_base_B3 = `nc'
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority if clan_any==0, absorb(county_num birth_i) vce(cluster county_num)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc = r(N)
drop tagc
local b_clan_C0 = _b[1.post#c.ln_martyr_per100k_1953]
local se_clan_C0 = _se[1.post#c.ln_martyr_per100k_1953]
local p_clan_C0 = 2*ttail(e(df_r), abs(`b_clan_C0'/`se_clan_C0'))
local nobs_clan_C0 = e(N)
local ncty_clan_C0 = `nc'
quietly reghdfejl eduy c.ln_martyr_per100k_1953##ib0.post minority if clan_any==1, absorb(county_num birth_i) vce(cluster county_num)
egen tagc = tag(county_num) if e(sample)
count if tagc==1
local nc = r(N)
drop tagc
local b_clan_C1 = _b[1.post#c.ln_martyr_per100k_1953]
local se_clan_C1 = _se[1.post#c.ln_martyr_per100k_1953]
local p_clan_C1 = 2*ttail(e(df_r), abs(`b_clan_C1'/`se_clan_C1'))
local nobs_clan_C1 = e(N)
local ncty_clan_C1 = `nc'

clear
set obs 5
gen str10 wave = "1982"
gen str12 dim = ""
gen str6 subgroup = ""
gen double b = .
gen double se = .
gen double p = .
gen double n_obs = .
gen double n_counties = .

replace dim = "baseedu" in 1
replace subgroup = "B1" in 1
replace b = `b_base_B1' in 1
replace se = `se_base_B1' in 1
replace p = `p_base_B1' in 1
replace n_obs = `nobs_base_B1' in 1
replace n_counties = `ncty_base_B1' in 1

replace dim = "baseedu" in 2
replace subgroup = "B2" in 2
replace b = `b_base_B2' in 2
replace se = `se_base_B2' in 2
replace p = `p_base_B2' in 2
replace n_obs = `nobs_base_B2' in 2
replace n_counties = `ncty_base_B2' in 2

replace dim = "baseedu" in 3
replace subgroup = "B3" in 3
replace b = `b_base_B3' in 3
replace se = `se_base_B3' in 3
replace p = `p_base_B3' in 3
replace n_obs = `nobs_base_B3' in 3
replace n_counties = `ncty_base_B3' in 3

replace dim = "clan_any" in 4
replace subgroup = "C0" in 4
replace b = `b_clan_C0' in 4
replace se = `se_clan_C0' in 4
replace p = `p_clan_C0' in 4
replace n_obs = `nobs_clan_C0' in 4
replace n_counties = `ncty_clan_C0' in 4

replace dim = "clan_any" in 5
replace subgroup = "C1" in 5
replace b = `b_clan_C1' in 5
replace se = `se_clan_C1' in 5
replace p = `p_clan_C1' in 5
replace n_obs = `nobs_clan_C1' in 5
replace n_counties = `ncty_clan_C1' in 5

save "${proj}/result/table/main_individual_base_clan_heterogeneity_summary_v1.dta", replace
export delimited using "${proj}/result/table/main_individual_base_clan_heterogeneity_summary_v1.csv", replace

exit, clear
