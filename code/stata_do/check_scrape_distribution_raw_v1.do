*******************************************************
* Raw scrape distribution (native vs sacrifice counts)
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

import delimited "${proj}/data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts_clean_county_fallback.csv", clear
rename martyr_count native_count
keep place_id place_name native_count
tempfile native
save `native'

import delimited "${proj}/data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_sacrifice_place_counts_clean_county_fallback.csv", clear
rename martyr_count sacrifice_count
keep place_id place_name sacrifice_count
tempfile sacrifice
save `sacrifice'

merge 1:1 place_id using `native', nogen
replace native_count = 0 if missing(native_count)
replace sacrifice_count = 0 if missing(sacrifice_count)

gen ln_native = ln(1+native_count)
gen ln_sacrifice = ln(1+sacrifice_count)

preserve
    keep native_count sacrifice_count
    quietly summarize native_count, detail
    scalar n_p50 = r(p50)
    scalar n_p90 = r(p90)
    scalar n_p95 = r(p95)
    scalar n_p99 = r(p99)
    quietly summarize sacrifice_count, detail
    scalar s_p50 = r(p50)
    scalar s_p90 = r(p90)
    scalar s_p95 = r(p95)
    scalar s_p99 = r(p99)
restore

clear
set obs 1
gen native_p50 = n_p50
gen native_p90 = n_p90
gen native_p95 = n_p95
gen native_p99 = n_p99
gen sacrifice_p50 = s_p50
gen sacrifice_p90 = s_p90
gen sacrifice_p95 = s_p95
gen sacrifice_p99 = s_p99
export delimited using "${proj}/result/table/scrape_raw_distribution_check_v1.csv", replace

use `sacrifice', clear
rename sacrifice_count martyr_count
merge 1:1 place_id using `native', nogen
replace native_count = 0 if missing(native_count)
replace martyr_count = 0 if missing(martyr_count)
gen ln_native = ln(1+native_count)
gen ln_sacrifice = ln(1+martyr_count)

histogram native_count, frequency color(navy%75) lcolor(navy) ///
    xtitle("Native-place count") ytitle("Counties") title("A. Native Count") name(g1, replace)
histogram ln_native, frequency color(navy%45) lcolor(navy) ///
    xtitle("ln(1+native)") ytitle("Counties") title("B. ln Native Count") name(g2, replace)
histogram martyr_count, frequency color(maroon%75) lcolor(maroon) ///
    xtitle("Sacrifice-place count") ytitle("Counties") title("C. Sacrifice Count") name(g3, replace)
histogram ln_sacrifice, frequency color(maroon%45) lcolor(maroon) ///
    xtitle("ln(1+sacrifice)") ytitle("Counties") title("D. ln Sacrifice Count") name(g4, replace)

graph combine g1 g2 g3 g4, cols(2) imargin(3 3 3 3) ///
    title("Raw Scrape Distribution (1931-1945)") name(gall, replace)

graph export "${proj}/result/figure/scrape_raw_distribution_2x2_v1.png", replace width(2400)
graph export "${proj}/result/figure/scrape_raw_distribution_2x2_v1.pdf", replace

exit, clear
