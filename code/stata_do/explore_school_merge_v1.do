clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

* Check if countyid in school data matches our treatment data
use "${proj}/data/raw/county_year_data.dta", clear
keep countyid
duplicates drop
gen str6 countyid_str = string(countyid, "%06.0f")

* Try merging with treatment
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

* Try direct merge on countyid
rename countyid_str countyid_curr6
merge 1:1 countyid_curr6 using `treat'
tab _merge
di "Matched: " r(N)

* Now check school expansion data
use "${proj}/data/raw/rural_school_expansion.dta", clear
gen str6 countyid_str = string(countyid, "%06.0f")
rename countyid_str countyid_curr6
merge 1:1 countyid_curr6 using `treat'
tab _merge
di "School expansion matched: "

* Try cross-section regression
keep if _merge == 3
reg primary_speed ihs_rate, robust
reg secondary_speed ihs_rate, robust
reg primary_speed high_count, robust
reg secondary_speed high_count, robust

exit, clear
