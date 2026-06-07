clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

* Look at county_data crosswalk
use "${proj}/data/raw/county_data.dta", clear
describe
list countyid region2000 region1990 region1982 in 1/20
di "N counties: " _N

* Check format of region codes
summ region2000 region1990 region1982
* These might be 6-digit GB codes
gen str6 r2000 = string(region2000, "%06.0f") if !missing(region2000)
gen str6 r1990 = string(region1990, "%06.0f") if !missing(region1990)
gen str6 r1982 = string(region1982, "%06.0f") if !missing(region1982)
list countyid r2000 r1990 r1982 in 1/20

* Try merging via region2000
preserve
    use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
    keep countyid_curr6 martyr_per100k_1953 ln_martyr_raw
    gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
    replace martyr_count = 0 if missing(martyr_count)
    gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
    summ martyr_count, detail
    local med = r(p50)
    gen high_count = (martyr_count > `med') if !missing(martyr_count)
    tempfile treat
    save `treat'
restore

* Merge county_data with treatment via region2000
rename r2000 countyid_curr6
merge m:1 countyid_curr6 using `treat'
tab _merge
count if _merge == 3
di "Matched via region2000: " r(N)

* If matched, merge school expansion  
keep if _merge == 3
keep countyid ihs_rate high_count martyr_per100k_1953

* Now merge school expansion
merge 1:1 countyid using "${proj}/data/raw/rural_school_expansion.dta"
tab _merge
count if _merge == 3

keep if _merge == 3
di "=== School expansion + treatment matched ==="
summ primary_speed secondary_speed ihs_rate high_count

* Run quick regressions
reg primary_speed ihs_rate, robust
reg secondary_speed ihs_rate, robust
reg primary_speed high_count, robust
reg secondary_speed high_count, robust

exit, clear
