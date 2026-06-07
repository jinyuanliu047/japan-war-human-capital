clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear

di "=== Total obs in treatment file ==="
count
di "=== Unique countyid_curr6 ==="
duplicates report countyid_curr6
di "=== Missing values ==="
count if countyid_curr6 == ""
count if missing(martyr_per100k_1953)
count if missing(ln_martyr_per100k_1953)
count if missing(pop_1953)

di "=== _merge distribution ==="
tab _merge

di "=== Counties with martyr_count == 0 but pop > 0 ==="
count if ln_martyr_raw == 0 & pop_1953 > 0 & !missing(pop_1953)

di "=== Counties with missing pop ==="
count if missing(pop_1953) | pop_1953 == 0

di "=== First 10 duplicates if any ==="
duplicates tag countyid_curr6, gen(dup)
list countyid_curr6 pop_1953 ln_martyr_raw martyr_per100k_1953 if dup > 0, noobs clean

di "=== Total counties with nonmissing rate ==="
count if !missing(martyr_per100k_1953)

di "=== Unique county codes with nonmissing rate ==="
preserve
keep if !missing(martyr_per100k_1953)
duplicates drop countyid_curr6, force
count
restore

exit, clear
