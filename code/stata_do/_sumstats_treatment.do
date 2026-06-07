clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear

gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)

gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

di "========================================"
di "  Treatment Variable Distributions"
di "========================================"

di ""
di "--- Raw martyr count ---"
summ martyr_count, detail

di ""
di "--- Martyr per 100k (raw rate) ---"
summ martyr_per100k_1953, detail

di ""
di "--- ln(1 + per100k) ---"
summ ln_martyr_per100k_1953, detail

di ""
di "--- ln(1 + count) ---"
summ ln_martyr_raw, detail

di ""
di "--- IHS(count) ---"
summ ihs_count, detail

di ""
di "--- IHS(rate) ---"
summ ihs_rate, detail

di ""
di "--- Population 1953 ---"
summ pop_1953, detail

di ""
di "========================================"
di "  Percentile table"
di "========================================"
di ""
di "Percentile | count | rate/100k | ln(1+rate) | IHS(count) | IHS(rate)"
_pctile martyr_count, p(1 5 10 25 50 75 90 95 99)
local pc1  = r(r1)
local pc5  = r(r2)
local pc10 = r(r3)
local pc25 = r(r4)
local pc50 = r(r5)
local pc75 = r(r6)
local pc90 = r(r7)
local pc95 = r(r8)
local pc99 = r(r9)

_pctile martyr_per100k_1953, p(1 5 10 25 50 75 90 95 99)
local pr1  = r(r1)
local pr5  = r(r2)
local pr10 = r(r3)
local pr25 = r(r4)
local pr50 = r(r5)
local pr75 = r(r6)
local pr90 = r(r7)
local pr95 = r(r8)
local pr99 = r(r9)

di "p1:   count=" %8.0f `pc1'  "  rate=" %8.1f `pr1'
di "p5:   count=" %8.0f `pc5'  "  rate=" %8.1f `pr5'
di "p10:  count=" %8.0f `pc10' "  rate=" %8.1f `pr10'
di "p25:  count=" %8.0f `pc25' "  rate=" %8.1f `pr25'
di "p50:  count=" %8.0f `pc50' "  rate=" %8.1f `pr50'
di "p75:  count=" %8.0f `pc75' "  rate=" %8.1f `pr75'
di "p90:  count=" %8.0f `pc90' "  rate=" %8.1f `pr90'
di "p95:  count=" %8.0f `pc95' "  rate=" %8.1f `pr95'
di "p99:  count=" %8.0f `pc99' "  rate=" %8.1f `pr99'

di ""
di "========================================"
di "  Zero counts"
di "========================================"
count if martyr_count == 0
di "Counties with 0 martyrs: " r(N)
count
di "Total counties: " r(N)
count if martyr_count == 0
local n0 = r(N)
count
local ntot = r(N)
di "Share with 0: " %5.1f (`n0'/`ntot'*100) "%"

count if martyr_per100k_1953 == 0
di "Counties with 0 rate: " r(N)
count if !missing(martyr_per100k_1953)
di "Total with rate: " r(N)

di ""
di "========================================"
di "  Correlation matrix"
di "========================================"
correlate martyr_count martyr_per100k_1953 ln_martyr_raw ln_martyr_per100k_1953 ihs_count ihs_rate

exit, clear
