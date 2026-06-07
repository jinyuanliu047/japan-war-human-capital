* =========================================================
* 1. Environment & Path Setup
* =========================================================
global path "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage"
global path_raw    "$path/data/raw"
global path_temp   "$path/data/temp"
global path_figure "$path/result/figure"
global path_table  "$path/result/table"

* =========================================================
* 2. Data Processing
* =========================================================
use "$path_raw/census/census_1982.dta", clear

* ---------------------------------------------------------
* Part A: Geographic Identifiers
* ---------------------------------------------------------
gen geo_str = string(geo3_cn1982, "%08.0f")
gen countyid = substr(geo_str, 1, 2) + substr(geo_str, 4, 2) + substr(geo_str, 7, 2)
destring countyid, replace
drop geo_str

* ---------------------------------------------------------
* Part B: Demographics & Education (Using educcn)
* ---------------------------------------------------------
* 1. Generate Birth Year
gen birthyr = 1982 - age

* 2. Construct Years of Education (eduy)
decode educcn, gen(edu_str)
gen eduy = .

* --- Assignment Logic ---
replace eduy = 0   if strpos(edu_str, "illiterate")     // Illiterate (0)
replace eduy = 6   if strpos(edu_str, "primary")        // Primary (6)
replace eduy = 9   if strpos(edu_str, "junior")         // Junior Middle (9)
replace eduy = 12  if strpos(edu_str, "secondary")      // Secondary/High School (12)

* "Some college": User defined as 14 years
* (Represents 2-year college or half of 4-year degree)
replace eduy = 14  if strpos(edu_str, "some college")

replace eduy = 16  if strpos(edu_str, "graduated")      // University Graduate (16)

* --- Handle NIU / Missing ---
replace eduy = .   if strpos(edu_str, "niu") | strpos(edu_str, "unknown")

* Verification
tab educcn eduy, missing
drop edu_str
save "$path_temp/census_1982_cleaned.dta", replace


import excel "$path_raw/heritatge.xlsx", clear firstrow
keep countyid county heritagename
duplicates drop countyid, force

gen treat = 1
save "$path_temp/heritage_treat.dta", replace

use "$path_temp/census_1982_cleaned.dta", clear
merge m:1 countyid using "$path_temp/heritage_treat.dta"
