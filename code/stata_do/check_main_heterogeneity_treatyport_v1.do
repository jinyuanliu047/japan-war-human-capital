*******************************************************
* Treaty-port heterogeneity (reghdfe)
* Explicit sample-style version
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/did_1982_county_birthyr_pop1953_unwt_v2.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

*******************************************************
* Step 1. Build county-level treaty-port prefecture dummy
*******************************************************

import delimited "${proj}/data/temp/county_to_pref4_crosswalk_v1.csv", clear varnames(1) stringcols(_all)
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6) - 5, 6)
destring pref4_curr, replace
keep countyid_curr6 pref4_curr
duplicates drop countyid_curr6, force
tempfile county_pref
save `county_pref'

clear
input long pref4_curr str24 port_group
1201 "Tianjin"
1202 "Tianjin"
1303 "Qinhuangdao"
2101 "Shenyang"
2108 "Yingkou"
2201 "Changchun"
2224 "Yanbian"
2301 "Harbin"
3101 "Shanghai"
3102 "Shanghai"
3201 "Nanjing"
3205 "Suzhou"
3211 "Zhenjiang"
3301 "Hangzhou"
3302 "Ningbo"
3303 "Wenzhou"
3402 "Wuhu"
3501 "Fuzhou"
3502 "Xiamen"
3509 "Ningde"
3604 "Jiujiang"
3702 "Qingdao"
3706 "Yantai"
4201 "Wuhan"
4205 "Yichang"
4210 "Jingzhou"
4301 "Changsha"
4306 "Yueyang"
4401 "Guangzhou"
4405 "Shantou"
4501 "Nanning"
4504 "Wuzhou"
4505 "Beihai"
4514 "Chongzuo"
4601 "Haikou"
5001 "Chongqing"
5002 "Chongqing"
5305 "Baoshan"
5308 "Puer"
5325 "Honghe"
end
gen treaty_port_pref = 1
keep pref4_curr treaty_port_pref
duplicates drop pref4_curr, force
tempfile treaty_pref
save `treaty_pref'

use `county_pref', clear
merge m:1 pref4_curr using `treaty_pref', nogen
replace treaty_port_pref = 0 if missing(treaty_port_pref)
keep countyid_curr6 pref4_curr treaty_port_pref
duplicates drop countyid_curr6, force
tempfile county_treaty
save `county_treaty'

eststo clear

*******************************************************
* Step 2. 1982 wave
*******************************************************

use "${proj}/data/temp/did_1982_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1960)
drop if floor(birthyr) == 1939
keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"
merge m:1 countyid_curr6 using `county_treaty', keep(master match) nogen
replace treaty_port_pref = 0 if missing(treaty_port_pref)
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
sort county_num birth_i

preserve
keep if treaty_port_pref == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty1 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty1'
restore

preserve
keep if treaty_port_pref == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty2 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty2'
restore

*******************************************************
* Step 3. 1990 wave
*******************************************************

use "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1968)
drop if floor(birthyr) == 1939
keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"
merge m:1 countyid_curr6 using `county_treaty', keep(master match) nogen
replace treaty_port_pref = 0 if missing(treaty_port_pref)
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
sort county_num birth_i

preserve
keep if treaty_port_pref == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty3 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model3
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty3'
restore

preserve
keep if treaty_port_pref == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty4 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model4
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty4'
restore

*******************************************************
* Step 4. 2000 wave
*******************************************************

use "${proj}/data/temp/did_2000_county_birthyr_pop1953_unwt_v2.dta", clear
keep if inrange(birthyr, 1920, 1978)
drop if floor(birthyr) == 1939
keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
drop if countyid_curr6 == "" | countyid_curr6 == "000000"
merge m:1 countyid_curr6 using `county_treaty', keep(master match) nogen
replace treaty_port_pref = 0 if missing(treaty_port_pref)
gen birth_i = floor(birthyr)
gen post = birth_i >= 1940
egen county_num = group(countyid_curr6)
sort county_num birth_i

preserve
keep if treaty_port_pref == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty5 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model5
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty5'
restore

preserve
keep if treaty_port_pref == 1
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty6 = r(N)
drop tag_model
reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw = n_obs], absorb(county_num birth_i) vce(cluster county_num)
estimates store model6
estadd scalar ar2 = e(r2_a)
estadd local Weight "n_obs"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty6'
restore

*******************************************************
* Step 5. Table output
*******************************************************

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_treaty_port_heterogeneity_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("82 P0" "82 P1" "90 P0" "90 P1" "00 P0" "00 P1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2 ar2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 using "${proj}/result/table/main_treaty_port_heterogeneity_1982_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("P0" "P1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2 ar2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model3 model4 using "${proj}/result/table/main_treaty_port_heterogeneity_1990_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("P0" "P1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2 ar2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model5 model6 using "${proj}/result/table/main_treaty_port_heterogeneity_2000_reghdfe_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("P0" "P1") ///
    stats(Weight County_FE Cohort_FE N_counties N r2 ar2, ///
        labels("Weights" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Step 6. Summary CSV
*******************************************************

tempname memhold
postfile `memhold' str4 wave str12 dim str4 subgroup double b se p n_cells n_counties using "${proj}/result/table/main_treaty_port_heterogeneity_reghdfe_summary_v1_tmp.dta", replace

estimates restore model1
post `memhold' ("1982") ("treatyport") ("P0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty1')
estimates restore model2
post `memhold' ("1982") ("treatyport") ("P1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty2')
estimates restore model3
post `memhold' ("1990") ("treatyport") ("P0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty3')
estimates restore model4
post `memhold' ("1990") ("treatyport") ("P1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty4')
estimates restore model5
post `memhold' ("2000") ("treatyport") ("P0") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty5')
estimates restore model6
post `memhold' ("2000") ("treatyport") ("P1") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (`ncounty6')

postclose `memhold'

use "${proj}/result/table/main_treaty_port_heterogeneity_reghdfe_summary_v1_tmp.dta", clear
export delimited using "${proj}/result/table/main_treaty_port_heterogeneity_reghdfe_summary_v1.csv", replace
save "${proj}/result/table/main_treaty_port_heterogeneity_reghdfe_summary_v1.dta", replace
