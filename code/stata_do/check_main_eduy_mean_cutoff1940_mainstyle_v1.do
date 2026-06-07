*******************************************************
* Main county-cohort eduy_mean regressions
* Treat starts in 1940, drop 1939
* Three census waves
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/county_controls_full_v1.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

local p1982 = cond(fileexists("/tmp/census_1982_clean.dta"), "/tmp/census_1982_clean.dta", "${proj}/data/raw/census_1982_clean.dta")
local p1990 = cond(fileexists("/tmp/census_1990_clean.dta"), "/tmp/census_1990_clean.dta", "${proj}/data/raw/census_1990_clean.dta")
local p2000 = cond(fileexists("/tmp/census_2000_clean.dta"), "/tmp/census_2000_clean.dta", "${proj}/data/raw/census_2000_clean.dta")
global outcome "eduy_mean"
local hist_controls_all "c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post"

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
drop if countyid_curr6=="" | countyid_curr6=="000000"
duplicates drop countyid_curr6, force
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
tempfile ctrl
save `ctrl'

*******************************************************
* 1982
*******************************************************
use "${proj}/data/temp/did_1982_county_birthyr_pop1953_unwt_v2.dta", clear
gen birth_i = floor(birthyr)
keep if inrange(birth_i, 1920, 1960)
drop if birth_i == 1939
merge m:1 countyid_curr6 using `ctrl', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
reghdfe ${outcome} c.ln_martyr_per100k_1953##i.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd local Controls "N"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"
reghdfe ${outcome} c.ln_martyr_per100k_1953##i.post `hist_controls_all', absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd local Controls "N"
estadd local Hist_Control "All five"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

*******************************************************
* 1990
*******************************************************
use "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta", clear
gen birth_i = floor(birthyr)
keep if inrange(birth_i, 1920, 1968)
drop if birth_i == 1939
merge m:1 countyid_curr6 using `ctrl', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
reghdfe ${outcome} c.ln_martyr_per100k_1953##i.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd local Controls "N"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"
reghdfe ${outcome} c.ln_martyr_per100k_1953##i.post `hist_controls_all', absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd local Controls "N"
estadd local Hist_Control "All five"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

*******************************************************
* 2000
*******************************************************
use "${proj}/data/temp/did_2000_county_birthyr_pop1953_unwt_v2.dta", clear
gen birth_i = floor(birthyr)
keep if inrange(birth_i, 1920, 1978)
drop if birth_i == 1939
merge m:1 countyid_curr6 using `ctrl', keep(master match) nogen
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
reghdfe ${outcome} c.ln_martyr_per100k_1953##i.post, absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd local Controls "N"
estadd local Hist_Control "None"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"
reghdfe ${outcome} c.ln_martyr_per100k_1953##i.post `hist_controls_all', absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd local Controls "N"
estadd local Hist_Control "All five"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Cutoff "1940"

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_eduy_mean_cutoff1940_mainstyle_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 baseline" "1982 + all five" "1990 baseline" "1990 + all five" "2000 baseline" "2000 + all five") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N r2 ar2, ///
        labels("Individual controls" "County history control" "County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_eduy_mean_cutoff1940_mainstyle_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 baseline" "1982 + all five" "1990 baseline" "1990 + all five" "2000 baseline" "2000 + all five") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N r2 ar2, ///
        labels("Individual controls" "County history control" "County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' str4 wave str12 spec double b se p N using "${proj}/result/table/main_eduy_mean_cutoff1940_mainstyle_v1_tmp.dta", replace
foreach i in 1 2 3 4 5 6 {
    estimates restore model`i'
    local wave = cond(`i'<=2,"1982",cond(`i'<=4,"1990","2000"))
    local spec = cond(mod(`i',2)==1,"baseline","all_five")
    post `memhold' ("`wave'") ("`spec'") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
        (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N))
}
postclose `memhold'
use "${proj}/result/table/main_eduy_mean_cutoff1940_mainstyle_v1_tmp.dta", clear
export delimited using "${proj}/result/table/main_eduy_mean_cutoff1940_mainstyle_v1.csv", replace
erase "${proj}/result/table/main_eduy_mean_cutoff1940_mainstyle_v1_tmp.dta"
exit, clear
