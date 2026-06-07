*******************************************************
* Illiteracy-rate regressions by wave
* County-birth panels
* Treat starts in 1946, drop 1945
* Denominator = total county-cohort persons
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

use "${proj}/data/raw/county_data.dta", clear
keep region1982 region1990 region2000 region2010
drop if missing(region2010)
gen str6 county_curr6 = string(region2010, "%06.0f")

preserve
    keep region1982 county_curr6
    drop if missing(region1982)
    gen str6 old6 = string(region1982, "%06.0f")
    keep old6 county_curr6
    duplicates drop old6, force
    tempfile map82
    save `map82'
restore

preserve
    keep region1990 county_curr6
    drop if missing(region1990)
    gen str6 old6 = string(region1990, "%06.0f")
    keep old6 county_curr6
    duplicates drop old6, force
    tempfile map90
    save `map90'
restore

keep region2000 county_curr6
drop if missing(region2000)
gen str6 old6 = string(region2000, "%06.0f")
keep old6 county_curr6
duplicates drop old6, force
tempfile map00
save `map00'

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
duplicates drop countyid_curr6, force
tempfile treat
save `treat'

tempname memhold
postfile `memhold' int wave double b se p N r2 ar2 using "${proj}/result/table/illiteracy_rates_cutoff1946_summary_v1.dta", replace

*******************************************************
* 1982
*******************************************************
use region1982 year_birth yedu using "${proj}/data/raw/census_1982_clean.dta", clear
drop if missing(region1982) | missing(year_birth)
gen str6 old6 = string(region1982, "%06.0f")
merge m:1 old6 using `map82', keep(master match) nogen
rename county_curr6 countyid_curr6
keep if countyid_curr6!="" & countyid_curr6!="000000"
gen birth_i = floor(year_birth)
keep if inrange(birth_i, 1920, 1960)
drop if birth_i == 1945
gen total_n = 1
gen yedu_valid = inrange(yedu, 0, 25)
gen illit_num = (yedu == 0) if yedu_valid == 1
replace illit_num = 0 if missing(illit_num)
collapse (sum) total_n illit_num, by(countyid_curr6 birth_i)
gen illiteracy_rate = illit_num / total_n
merge m:1 countyid_curr6 using `treat', keep(master match) nogen
gen post = birth_i >= 1946
egen county_num = group(countyid_curr6)
reghdfe illiteracy_rate c.ln_martyr_per100k_1953##i.post [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
post `memhold' (1982) (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(r2)) (e(r2_a))

*******************************************************
* 1990
*******************************************************
use region1990 year_birth yedu using "${proj}/data/raw/census_1990_clean.dta", clear
drop if missing(region1990) | missing(year_birth)
gen str6 old6 = string(region1990, "%06.0f")
merge m:1 old6 using `map90', keep(master match) nogen
rename county_curr6 countyid_curr6
keep if countyid_curr6!="" & countyid_curr6!="000000"
gen birth_i = floor(year_birth)
keep if inrange(birth_i, 1920, 1968)
drop if birth_i == 1945
gen total_n = 1
gen yedu_valid = inrange(yedu, 0, 25)
gen illit_num = (yedu == 0) if yedu_valid == 1
replace illit_num = 0 if missing(illit_num)
collapse (sum) total_n illit_num, by(countyid_curr6 birth_i)
gen illiteracy_rate = illit_num / total_n
merge m:1 countyid_curr6 using `treat', keep(master match) nogen
gen post = birth_i >= 1946
egen county_num = group(countyid_curr6)
reghdfe illiteracy_rate c.ln_martyr_per100k_1953##i.post [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
post `memhold' (1990) (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(r2)) (e(r2_a))

*******************************************************
* 2000
*******************************************************
use region2000 year_birth yedu using "${proj}/data/raw/census_2000_clean.dta", clear
drop if missing(region2000) | missing(year_birth)
gen str6 old6 = string(region2000, "%06.0f")
merge m:1 old6 using `map00', keep(master match) nogen
rename county_curr6 countyid_curr6
keep if countyid_curr6!="" & countyid_curr6!="000000"
gen birth_i = floor(year_birth)
keep if inrange(birth_i, 1920, 1978)
drop if birth_i == 1945
gen total_n = 1
gen yedu_valid = inrange(yedu, 0, 25)
gen illit_num = (yedu == 0) if yedu_valid == 1
replace illit_num = 0 if missing(illit_num)
collapse (sum) total_n illit_num, by(countyid_curr6 birth_i)
gen illiteracy_rate = illit_num / total_n
merge m:1 countyid_curr6 using `treat', keep(master match) nogen
gen post = birth_i >= 1946
egen county_num = group(countyid_curr6)
reghdfe illiteracy_rate c.ln_martyr_per100k_1953##i.post [aw=total_n], absorb(county_num birth_i) vce(cluster county_num)
post `memhold' (2000) (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) ///
    (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N)) (e(r2)) (e(r2_a))

postclose `memhold'
use "${proj}/result/table/illiteracy_rates_cutoff1946_summary_v1.dta", clear
export delimited using "${proj}/result/table/illiteracy_rates_cutoff1946_summary_v1.csv", replace

exit, clear
