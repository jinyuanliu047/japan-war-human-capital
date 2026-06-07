*******************************************************
* Scrape treatment distribution check (county level)
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear

* Basic checks
isid countyid_curr6

quietly count
scalar N = r(N)
quietly count if missing(martyr_count_1931_1945)
scalar miss_count = r(N)
quietly count if missing(pop_1953)
scalar miss_pop = r(N)
quietly count if missing(martyr_per100k_1953)
scalar miss_ratio = r(N)
quietly count if missing(ln_martyr_per100k_1953)
scalar miss_ln = r(N)
quietly count if martyr_count_1931_1945 < 0
scalar neg_count = r(N)
quietly count if pop_1953 <= 0
scalar nonpos_pop = r(N)

* Summary stats for key vars
preserve
    keep martyr_count_1931_1945 pop_1953 martyr_per100k_1953 ln_martyr_per100k_1953
    quietly summarize martyr_count_1931_1945, detail
    scalar c_p50 = r(p50)
    scalar c_p90 = r(p90)
    scalar c_p95 = r(p95)
    scalar c_p99 = r(p99)

    quietly summarize martyr_per100k_1953, detail
    scalar r_p50 = r(p50)
    scalar r_p90 = r(p90)
    scalar r_p95 = r(p95)
    scalar r_p99 = r(p99)

    quietly summarize ln_martyr_per100k_1953, detail
    scalar l_p50 = r(p50)
    scalar l_p90 = r(p90)
    scalar l_p95 = r(p95)
    scalar l_p99 = r(p99)
restore

clear
set obs 1
gen N_counties = N
gen miss_martyr_count = miss_count
gen miss_pop1953 = miss_pop
gen miss_ratio = miss_ratio
gen miss_ln_ratio = miss_ln
gen neg_martyr_count = neg_count
gen nonpos_pop1953 = nonpos_pop

gen p50_count = c_p50
gen p90_count = c_p90
gen p95_count = c_p95
gen p99_count = c_p99

gen p50_ratio = r_p50
gen p90_ratio = r_p90
gen p95_ratio = r_p95
gen p99_ratio = r_p99

gen p50_ln = l_p50
gen p90_ln = l_p90
gen p95_ln = l_p95
gen p99_ln = l_p99

export delimited using "${proj}/result/table/scrape_distribution_check_v1.csv", replace
save "${proj}/result/table/scrape_distribution_check_v1.dta", replace

* Plots
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear

gen ln_count = ln(1 + martyr_count_1931_1945)
quietly summarize martyr_per100k_1953, detail
scalar q99 = r(p99)
gen ratio_trim99 = martyr_per100k_1953
replace ratio_trim99 = q99 if ratio_trim99 > q99

histogram martyr_count_1931_1945, discrete frequency color(navy%75) lcolor(navy) ///
    xtitle("Martyr count") ytitle("Counties") title("A. Martyr Count") name(g1, replace)

histogram ln_count, frequency color(maroon%75) lcolor(maroon) ///
    xtitle("ln(1+count)") ytitle("Counties") title("B. ln(1+Martyr Count)") name(g2, replace)

histogram ratio_trim99, frequency color(forest_green%75) lcolor(forest_green) ///
    xtitle("Martyrs per 100k (top 1% trimmed)") ytitle("Counties") title("C. Per-100k (trimmed)") name(g3, replace)

histogram ln_martyr_per100k_1953, frequency color(dkorange%75) lcolor(dkorange) ///
    xtitle("ln(1+per100k)") ytitle("Counties") title("D. ln(1+Per-100k)") name(g4, replace)

graph combine g1 g2 g3 g4, cols(2) imargin(3 3 3 3) ///
    title("Scrape Intensity Distribution (County-level)") name(gall, replace)

graph export "${proj}/result/figure/scrape_intensity_distribution_2x2_v1.png", replace width(2400)
graph export "${proj}/result/figure/scrape_intensity_distribution_2x2_v1.pdf", replace

* CCDF-like tail plot using ranks
sort martyr_count_1931_1945
gen rank = _n
gen ccdf = 1 - rank/_N
replace ccdf = . if ccdf<=0

twoway line ccdf martyr_count_1931_1945 if martyr_count_1931_1945>0 & ccdf<., ///
    xscale(log) yscale(log) lcolor(navy) lwidth(medthick) ///
    xtitle("Martyr count (log)") ytitle("CCDF (log)") title("County Count Tail (CCDF)")

graph export "${proj}/result/figure/scrape_intensity_count_ccdf_v1.png", replace width(1800)
graph export "${proj}/result/figure/scrape_intensity_count_ccdf_v1.pdf", replace

exit, clear
