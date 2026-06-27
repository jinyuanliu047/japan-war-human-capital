*****************************************************************
* build_ipums_pooled_master_v1.do
* Build the pooled 1982/1990/2000 master dataset from the NEW IPUMS
* International extract (ipumsi_00001), replacing the legacy proprietary
* census files. All three waves come from one harmonized source.
*
* Inputs (all under data/):
*   /tmp/ipums_slim.csv                       slim micro extract (24.26M rows, birth 1910-1975)
*   data/temp/ipums_geo3_to_curr6_v1.csv      IPUMS GEO3_CN{wave} -> countyid_curr6 crosswalk
*   data/temp/martyr_pop1953_treatment_county_v2.dta   county martyr treatment
*   data/temp/county_controls_full_v1.dta              historical controls + clan
*   data/temp/revolutionary_proxy_controls_v1.dta      Long March / Korea placebo
* Output:
*   data/temp/master_pooled_ipums_v1.dta
*****************************************************************

clear all
set more off
set maxvar 32767

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global slim "/tmp/ipums_slim.csv"

*--------------------------------------------------------------
* 1. County treatment + controls (county level)
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 pop_1953 martyr_count_1931_1945 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw
capture confirm string variable countyid_curr6
if _rc tostring countyid_curr6, replace
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)

rename martyr_count_1931_1945 martyr_count
replace martyr_count = 0 if missing(martyr_count)
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
gen ln_count  = ln(martyr_count + 1)
gen ln_pop1953 = ln(pop_1953) if !missing(pop_1953)

summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
summ martyr_per100k_1953, detail
gen d_rate_high  = (martyr_per100k_1953 > r(p50)) if !missing(martyr_per100k_1953)

duplicates drop countyid_curr6, force

merge 1:1 countyid_curr6 using "${proj}/data/temp/county_controls_full_v1.dta", ///
    keep(master match) nogen ///
    keepusing(sdy_density victims_cr grain_output urbanratio64 ins_famine clan_num ln_clan)
merge 1:1 countyid_curr6 using "${proj}/data/temp/revolutionary_proxy_controls_v1.dta", ///
    keep(master match) nogen ///
    keepusing(longmarch_martyr_per100k korea_war_martyr_per100k longmarch_martyr_count korea_war_martyr_count)

gen ln_victims_cr   = ln(victims_cr + 1)   if !missing(victims_cr)
gen ln_grain_output = ln(grain_output + 1) if !missing(grain_output)
gen ihs_longmarch = ln(longmarch_martyr_per100k + sqrt(longmarch_martyr_per100k^2 + 1)) if !missing(longmarch_martyr_per100k)
gen ihs_korea     = ln(korea_war_martyr_per100k + sqrt(korea_war_martyr_per100k^2 + 1))   if !missing(korea_war_martyr_per100k)
gen has_longmarch = (longmarch_martyr_count > 0) if !missing(longmarch_martyr_count)
replace has_longmarch = 0 if missing(has_longmarch)

gen has_clan = (clan_num > 0) if !missing(clan_num)
replace has_clan = 0 if missing(has_clan)

foreach v in sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 ihs_longmarch ihs_korea clan_num ln_clan {
    replace `v' = 0 if missing(`v')
}
tempfile treat
save `treat'

*--------------------------------------------------------------
* 2. IPUMS GEO3 -> countyid_curr6 crosswalk
*--------------------------------------------------------------
import delimited "${proj}/data/temp/ipums_geo3_to_curr6_v2.csv", varnames(1) stringcols(2 3) clear
rename wave year
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop year geo3_code, force
tempfile cw
save `cw'

*--------------------------------------------------------------
* 3. Micro ingest
*    slim cols: year sample serial perwt geo3_1982 geo3_1990 geo3_2000 urban
*               age sex ethniccn school lit edattain edattaind educcn
*               empstat empstatd labforce occisco occ indgen ind migrate5 birthyr
*--------------------------------------------------------------
import delimited "${slim}", varnames(1) stringcols(2 5 6 7) clear

* single-char fields can carry blanks (NIU) and import as string -> force numeric
destring urban sex school lit edattain empstat labforce occisco educcn edattaind ///
         indgen ind occ migrate5 ethniccn age year birthyr perwt, replace force

* wave's geography code
gen str9 geo3_code = ""
replace geo3_code = geo3_1982 if year == 1982
replace geo3_code = geo3_1990 if year == 1990
replace geo3_code = geo3_2000 if year == 2000
drop geo3_1982 geo3_1990 geo3_2000 sample serial

* merge geography -> county
merge m:1 year geo3_code using `cw', keep(master match) gen(_mcw)

* census wave
gen byte wave = .
replace wave = 1 if year == 1982
replace wave = 2 if year == 1990
replace wave = 3 if year == 2000

* education (EDUCCN -> years; paper coding 0/3/6/9/12/15/16)
gen byte eduy = .
replace eduy = 0  if educcn == 0
replace eduy = 3  if inlist(educcn,11,12)
replace eduy = 6  if inlist(educcn,10,13,19)
replace eduy = 9  if inrange(educcn,20,29)
replace eduy = 12 if inrange(educcn,30,39)
replace eduy = 15 if inlist(educcn,41,42,51,61)
replace eduy = 16 if inlist(educcn,40,43,44,50,52,58,60,62)
* educcn 98 (unknown) / 99 (NIU) -> eduy missing

* demographics
gen byte minority = (ethniccn != 1) if inrange(ethniccn,1,97)
gen byte female   = (sex == 2)      if inlist(sex,1,2)

* occupation categories (OCCISCO; employed only, valid 1-9; armed forces 10 & unspecified 11/97-99 excluded)
gen byte employed_occ = (empstat == 1) & inrange(occisco,1,9)
gen byte white_collar = inlist(occisco,1,2,3,4) if employed_occ
gen byte service      = (occisco == 5)          if employed_occ
gen byte agri         = (occisco == 6)          if employed_occ
gen byte manual       = inlist(occisco,7,8,9)   if employed_occ

* keep only geography-merged records with valid education
keep if _mcw == 3
drop if missing(eduy)

* merge treatment (county) ; keep matched only
merge m:1 countyid_curr6 using `treat', keep(match) gen(_mt)

* winsorize eduy at 1/99 (paper)
summ eduy, detail
replace eduy = r(p1)  if eduy < r(p1)
replace eduy = r(p99) if eduy > r(p99) & !missing(eduy)

* cohort size + base education (heterogeneity)
egen county_num = group(countyid_curr6)
bysort county_num birthyr wave: gen long cohort_n = _N
gen ln_cohort_n = ln(cohort_n)
bysort countyid_curr6: egen base_edu = mean(cond(birthyr < 1940, eduy, .))
summ base_edu, detail
gen byte high_base_edu = (base_edu > r(p50)) if !missing(base_edu)

* trim to analysis cohorts and needed variables (keeps file compact + reliable to save locally)
keep if inrange(birthyr, 1915, 1972)
keep year wave countyid_curr6 county_num birthyr age eduy female minority perwt ///
     occisco empstat employed_occ white_collar service agri manual urban migrate5 ///
     martyr_count martyr_per100k_1953 ln_martyr_per100k_1953 ihs_count ihs_rate ln_count ///
     d_count_high d_rate_high ln_pop1953 pop_1953 ///
     sdy_density ins_famine ln_victims_cr ln_grain_output urbanratio64 ///
     ihs_longmarch ihs_korea has_longmarch longmarch_martyr_per100k korea_war_martyr_per100k ///
     clan_num ln_clan has_clan cohort_n ln_cohort_n base_edu high_base_edu

label data "Pooled 1982/1990/2000 IPUMS master (martyr DID)"
compress
save "/tmp/japan_war_local/data/temp/master_pooled_ipums_v1.dta", replace
* mirror to project temp only if it fits (cloud path can be flaky); ignore failure
capture save "${proj}/data/temp/master_pooled_ipums_v1.dta", replace

*--------------------------------------------------------------
* 4. Coverage / sanity report
*--------------------------------------------------------------
di as txt "===== MASTER BUILD SUMMARY ====="
count
di as txt "N (matched to treatment, valid eduy) = " r(N)
tab year
distinct countyid_curr6
summ eduy martyr_per100k_1953 ln_martyr_per100k_1953 female minority
di as txt "===== END ====="
