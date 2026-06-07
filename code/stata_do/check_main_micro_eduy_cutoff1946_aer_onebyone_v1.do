*******************************************************
* Main individual-level eduy regressions
* Treat starts in 1946, drop 1945
* AER-style controls added one by one
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

global control "minority"

*******************************************************
* Crosswalks and county-level files
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
* Prepare summary sink
*******************************************************
tempname memhold
postfile `memhold' str4 wave str20 spec double b se p N N_clust using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_onebyone_v1_tmp.dta", replace

*******************************************************
* Wave 1982
*******************************************************
use countyid birthyr eduy ethniccn using "${proj}/data/temp/census_1982_cleaned.dta", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using `cw1982', keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen minority = (ethniccn!=1) if !missing(ethniccn)
keep if inrange(birthyr, 1920, 1960)
keep if inrange(eduy, 0, 25)
gen birth_i = floor(birthyr)
drop if birth_i == 1945
gen post = birth_i >= 1946
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `aer', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)

// main_micro_eduy_1982_aer_onebyone
reghdfe eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1982_1
estadd local Controls "Y"
estadd local AER_Post "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1982") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.sdy_density#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1982_2
estadd local Controls "Y"
estadd local AER_Post "sdy_density"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1982") ("sdy_density") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.ins_famine#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1982_3
estadd local Controls "Y"
estadd local AER_Post "ins_famine"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1982") ("ins_famine") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.ln_victims_cr#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1982_4
estadd local Controls "Y"
estadd local AER_Post "ln_victims_cr"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1982") ("log_victims") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.ln_grain_output#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1982_5
estadd local Controls "Y"
estadd local AER_Post "ln_grain_output"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1982") ("log_grain") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.urbanratio64#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1982_6
estadd local Controls "Y"
estadd local AER_Post "urbanratio64"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1982") ("urbanratio64") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

esttab m1982_1 m1982_2 m1982_3 m1982_4 m1982_5 m1982_6 using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_onebyone_1982_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Controls AER_Post County_FE Cohort_FE Cutoff) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)
esttab m1982_1 m1982_2 m1982_3 m1982_4 m1982_5 m1982_6 using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_onebyone_1982_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Controls AER_Post County_FE Cohort_FE Cutoff) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Wave 1990
*******************************************************
use countyid year_birth yedu han_ethn using "${proj}/data/raw/census_1990_clean.dta", clear
drop if missing(countyid) | missing(year_birth) | missing(yedu)
rename countyid countyid_1990
merge m:1 countyid_1990 using `map1990', keep(master match) nogen
keep if county_curr6!=""
gen birth_i = floor(year_birth)
gen eduy = yedu
gen minority = (han_ethn!=1) if !missing(han_ethn)
keep if inrange(birth_i, 1920, 1968)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1945
gen post = birth_i >= 1946
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `aer', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)

// main_micro_eduy_1990_aer_onebyone
reghdfe eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1990_1
estadd local Controls "Y"
estadd local AER_Post "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1990") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.sdy_density#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1990_2
estadd local Controls "Y"
estadd local AER_Post "sdy_density"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1990") ("sdy_density") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.ins_famine#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1990_3
estadd local Controls "Y"
estadd local AER_Post "ins_famine"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1990") ("ins_famine") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.ln_victims_cr#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1990_4
estadd local Controls "Y"
estadd local AER_Post "ln_victims_cr"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1990") ("log_victims") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.ln_grain_output#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1990_5
estadd local Controls "Y"
estadd local AER_Post "ln_grain_output"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1990") ("log_grain") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.urbanratio64#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m1990_6
estadd local Controls "Y"
estadd local AER_Post "urbanratio64"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("1990") ("urbanratio64") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

esttab m1990_1 m1990_2 m1990_3 m1990_4 m1990_5 m1990_6 using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_onebyone_1990_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Controls AER_Post County_FE Cohort_FE Cutoff) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)
esttab m1990_1 m1990_2 m1990_3 m1990_4 m1990_5 m1990_6 using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_onebyone_1990_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Controls AER_Post County_FE Cohort_FE Cutoff) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Wave 2000
*******************************************************
use region2000 year_birth yedu han_ethn using "${proj}/data/raw/census_2000_clean.dta", clear
drop if missing(region2000) | missing(year_birth) | missing(yedu)
gen str6 county_curr6 = string(region2000, "%06.0f")
gen birth_i = floor(year_birth)
gen eduy = yedu
gen minority = (han_ethn!=1) if !missing(han_ethn)
keep if inrange(birth_i, 1920, 1978)
keep if inrange(eduy, 0, 25)
drop if birth_i == 1945
gen post = birth_i >= 1946
merge m:1 county_curr6 using `treat', keep(master match) nogen
merge m:1 county_curr6 using `aer', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
egen county_num = group(county_curr6)

// main_micro_eduy_2000_aer_onebyone
reghdfe eduy c.ln_martyr_per100k_1953##i.post $control, absorb(county_num birth_i) vce(cluster county_num)
estimates store m2000_1
estadd local Controls "Y"
estadd local AER_Post "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("2000") ("baseline") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.sdy_density#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m2000_2
estadd local Controls "Y"
estadd local AER_Post "sdy_density"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("2000") ("sdy_density") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.ins_famine#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m2000_3
estadd local Controls "Y"
estadd local AER_Post "ins_famine"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("2000") ("ins_famine") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.ln_victims_cr#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m2000_4
estadd local Controls "Y"
estadd local AER_Post "ln_victims_cr"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("2000") ("log_victims") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.ln_grain_output#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m2000_5
estadd local Controls "Y"
estadd local AER_Post "ln_grain_output"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("2000") ("log_grain") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

reghdfe eduy c.ln_martyr_per100k_1953##i.post $control c.urbanratio64#c.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store m2000_6
estadd local Controls "Y"
estadd local AER_Post "urbanratio64"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1946"
post `memhold' ("2000") ("urbanratio64") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(N_clust))

esttab m2000_1 m2000_2 m2000_3 m2000_4 m2000_5 m2000_6 using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_onebyone_2000_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Controls AER_Post County_FE Cohort_FE Cutoff) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)
esttab m2000_1 m2000_2 m2000_3 m2000_4 m2000_5 m2000_6 using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_onebyone_2000_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Controls AER_Post County_FE Cohort_FE Cutoff) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Summary CSV
*******************************************************
postclose `memhold'
use "${proj}/result/table/main_micro_eduy_cutoff1946_aer_onebyone_v1_tmp.dta", clear
export delimited using "${proj}/result/table/main_micro_eduy_cutoff1946_aer_onebyone_v1.csv", replace
erase "${proj}/result/table/main_micro_eduy_cutoff1946_aer_onebyone_v1_tmp.dta"
