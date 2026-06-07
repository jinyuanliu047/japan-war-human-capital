*******************************************************
* Treaty-port heterogeneity, 1990 micro yedu
* Explicit sample-style version
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace

capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

*******************************************************
* Step 1. County-level treaty-port crosswalk
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
keep countyid_curr6 treaty_port_pref
duplicates drop countyid_curr6, force
tempfile county_treaty
save `county_treaty'

*******************************************************
* Step 2. County-level war exposure
*******************************************************

use "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6) - 5, 6)
duplicates drop countyid_curr6, force
tempfile county_martyr
save `county_martyr'

*******************************************************
* Step 3. 1990 individual micro sample
*******************************************************

use "${proj}/data/raw/census_1990_clean.dta", clear
keep if !missing(yedu) & !missing(year_birth)
keep if inrange(year_birth, 1920, 1975)
drop if floor(year_birth) == 1939

capture confirm numeric variable region1990
if _rc == 0 {
    gen countyid_curr6 = string(region1990, "%06.0f")
}
else {
    gen countyid_curr6 = region1990
    replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6) - 5, 6)
}

merge m:1 countyid_curr6 using `county_treaty', keep(master match) nogen
merge m:1 countyid_curr6 using `county_martyr', keep(master match) nogen

drop if missing(ln_martyr_per100k_1953)
replace treaty_port_pref = 0 if missing(treaty_port_pref)

gen birth_i = floor(year_birth)
gen post = birth_i >= 1946
gen did_post_exposure = ln_martyr_per100k_1953 * post
egen county_num = group(countyid_curr6)

*******************************************************
* Step 4. Regressions
*******************************************************

preserve
keep if treaty_port_pref == 0
egen tag_model = tag(county_num)
quietly count if tag_model == 1
local ncounty1 = r(N)
drop tag_model
reghdfejl yedu did_post_exposure male han_ethn rural, absorb(county_num birth_i) vce(cluster county_num)
estimates store model1
estadd scalar ar2 = e(r2_a)
estadd local Controls "Y"
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
reghdfejl yedu did_post_exposure male han_ethn rural, absorb(county_num birth_i) vce(cluster county_num)
estimates store model2
estadd scalar ar2 = e(r2_a)
estadd local Controls "Y"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd scalar N_counties = `ncounty2'
restore

*******************************************************
* Step 5. Table output
*******************************************************

esttab model1 model2 using "${proj}/result/table/treatyport_micro1990_yedu_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(did_post_exposure) ///
    coeflabels(did_post_exposure "Post × War exposure") ///
    mtitles("P0" "P1") ///
    stats(Controls County_FE Cohort_FE N_counties N r2 ar2, ///
        labels("Controls" "County FE" "Cohort FE" "Counties" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' str12 subgroup double b se p n_obs n_counties using "${proj}/result/table/treatyport_micro1990_yedu_summary_v1_tmp.dta", replace

estimates restore model1
post `memhold' ("P0") (_b[did_post_exposure]) (_se[did_post_exposure]) (2*ttail(e(df_r), abs(_b[did_post_exposure] / _se[did_post_exposure]))) (e(N)) (`ncounty1')
estimates restore model2
post `memhold' ("P1") (_b[did_post_exposure]) (_se[did_post_exposure]) (2*ttail(e(df_r), abs(_b[did_post_exposure] / _se[did_post_exposure]))) (e(N)) (`ncounty2')

postclose `memhold'

use "${proj}/result/table/treatyport_micro1990_yedu_summary_v1_tmp.dta", clear
export delimited using "${proj}/result/table/treatyport_micro1990_yedu_summary_v1.csv", replace
save "${proj}/result/table/treatyport_micro1990_yedu_summary_v1.dta", replace
