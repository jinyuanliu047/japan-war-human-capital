*******************************************************
* Main individual-level eduy regressions
* Treat starts in 1940, drop 1939
* Three census waves
* Main table template style
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

local p1982 = cond(fileexists("/tmp/census_1982_clean.dta"), "/tmp/census_1982_clean.dta", "${proj}/data/raw/census_1982_clean.dta")
local p1990 = cond(fileexists("/tmp/census_1990_clean.dta"), "/tmp/census_1990_clean.dta", "${proj}/data/raw/census_1990_clean.dta")
local p2000 = cond(fileexists("/tmp/census_2000_clean.dta"), "/tmp/census_2000_clean.dta", "${proj}/data/raw/census_2000_clean.dta")
local py1982 = cond(fileexists("/tmp/county_y_panel_1982_v4.dta"), "/tmp/county_y_panel_1982_v4.dta", "${proj}/data/temp/county_y_panel_1982_v4.dta")
local py1990 = cond(fileexists("/tmp/county_y_panel_1990_v4.dta"), "/tmp/county_y_panel_1990_v4.dta", "${proj}/data/temp/county_y_panel_1990_v4.dta")
local py2000 = cond(fileexists("/tmp/county_y_panel_2000_v4.dta"), "/tmp/county_y_panel_2000_v4.dta", "${proj}/data/temp/county_y_panel_2000_v4.dta")

global control "minority"
local hist_controls_all "c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post"

*******************************************************
* Step 1. Crosswalks and county-level files
*******************************************************
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

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953 martyr_per100k_1953
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
tempfile treat
save `treat'

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
drop if county_curr6=="" | county_curr6=="000000"
duplicates drop county_curr6, force
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
tempfile aer
save `aer'

use countyid region1990 using "${proj}/data/raw/census_1990_county_char.dta", clear
drop if missing(countyid) | missing(region1990)
rename countyid countyid_1990
gen str6 county_curr6 = string(region1990, "%06.0f")
keep countyid_1990 county_curr6
duplicates drop countyid_1990, force
tempfile map1990
save `map1990'

*******************************************************
* Step 2. Wave 1982 sample and regressions
*******************************************************
use region1982 year_birth yedu han_ethn using "`p1982'", clear
drop if missing(region1982) | missing(year_birth) | missing(yedu)
gen str6 old6 = string(region1982, "%06.0f")
merge m:1 old6 using `cw1982', keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen minority = (han_ethn!=1) if !missing(han_ethn)
keep if inrange(year_birth, 1920, 1960)
keep if inrange(yedu, 0, 25)
gen birth_i = floor(year_birth)
gen eduy = yedu
drop if birth_i == 1939
gen post = birth_i >= 1940
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `aer', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)

// main_micro_eduy_1982
reghdfe eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd local Controls "Y"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control `hist_controls_all', absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd local Controls "Y"
estadd local Hist_Control "All five"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

*******************************************************
* Step 3. Wave 1990 sample and regressions
*******************************************************
use countyid year_birth yedu han_ethn using "`p1990'", clear
drop if missing(countyid) | missing(year_birth) | missing(yedu)
rename countyid countyid_1990
merge m:1 countyid_1990 using `map1990', keep(master match) nogen
keep if county_curr6!=""
gen birth_i = floor(year_birth)
gen eduy2 = yedu
gen minority = (han_ethn!=1) if !missing(han_ethn)
keep if inrange(birth_i, 1920, 1968)
keep if inrange(eduy2, 0, 25)
drop if birth_i == 1939
gen post = birth_i >= 1940
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `aer', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)
rename eduy2 eduy

// main_micro_eduy_1990
reghdfe eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd local Controls "Y"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control `hist_controls_all', absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd local Controls "Y"
estadd local Hist_Control "All five"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

*******************************************************
* Step 4. Wave 2000 sample and regressions
*******************************************************
use region2000 year_birth yedu han_ethn using "`p2000'", clear
drop if missing(region2000) | missing(year_birth) | missing(yedu)
gen str6 county_curr6 = string(region2000, "%06.0f")
gen birth_i = floor(year_birth)
gen eduy = yedu
gen minority = (han_ethn!=1) if !missing(han_ethn)
keep if inrange(birth_i, 1920, 1978)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1939
gen post = birth_i >= 1940
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `aer', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)

// main_micro_eduy_2000
reghdfe eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd local Controls "Y"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control `hist_controls_all', absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd local Controls "Y"
estadd local Hist_Control "All five"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

*******************************************************
* Step 5. Table output
*******************************************************
esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 baseline" "1982 + all five" "1990 baseline" "1990 + all five" "2000 baseline" "2000 + all five") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N r2 ar2, ///
        labels("Individual controls" "County history control" "County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 baseline" "1982 + all five" "1990 baseline" "1990 + all five" "2000 baseline" "2000 + all five") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N r2 ar2, ///
        labels("Individual controls" "County history control" "County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Step 6. Summary CSV
*******************************************************
tempname memhold
postfile `memhold' str4 wave str12 spec double b se p N N_clust using "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v1_tmp.dta", replace

estimates restore model1
post `memhold' ("1982") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model2
post `memhold' ("1982") ("all_five") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model3
post `memhold' ("1990") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model4
post `memhold' ("1990") ("all_five") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model5
post `memhold' ("2000") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

estimates restore model6
post `memhold' ("2000") ("all_five") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

postclose `memhold'

use "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v1_tmp.dta", clear
export delimited using "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v1.csv", replace
erase "${proj}/result/table/main_micro_eduy_cutoff1940_mainstyle_v1_tmp.dta"
