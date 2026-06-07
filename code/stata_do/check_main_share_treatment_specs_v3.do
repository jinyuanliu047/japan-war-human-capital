*******************************************************
* Main DID robustness: share-based treatment construction (I/O optimized)
* Keep original ln(per100k) spec unchanged as benchmark
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

tempname posth
tempfile out
postfile `posth' str6 wave str32 spec int sample_hi ///
    double b se p w_p1 w_p99 pop_p5 ///
    long n_cells n_counties using "`out'", replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'" == "1990" local hi = 1968
    if "`w'" == "2000" local hi = 1978

    use "${proj}/data/temp/did_`w'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr) == 1939
    keep if !missing(eduy_mean) & !missing(countyid_curr6)
    drop if countyid_curr6=="000000"
    keep if !missing(martyr_per100k_1953) & !missing(martyr_count_1931_1945) & !missing(pop_1953)

    gen birth_i = floor(birthyr)
    egen county_num = group(countyid_curr6)
    gen post = birth_i >= 1940
    gen share = martyr_count_1931_1945 / pop_1953 if pop_1953>0

    egen tag_county = tag(county_num)

    quietly _pctile share if tag_county==1, p(1 99)
    scalar w_p1 = r(r1)
    scalar w_p99 = r(r2)

    quietly _pctile pop_1953 if tag_county==1, p(5)
    scalar pop_p5 = r(r1)

    tempfile base
    save `base'

    * 1) baseline ln(per100k)
    use `base', clear
    quietly count
    scalar n_cells = r(N)
    quietly count if tag_county==1
    scalar n_counties = r(N)
    gen treat = ln_martyr_per100k_1953
    quietly areg eduy_mean c.treat##ib0.post i.birth_i, absorb(county_num) vce(cluster county_num)
    quietly lincom 1.post#c.treat
    scalar b = r(estimate)
    scalar se = r(se)
    scalar p = 2 * ttail(e(df_r), abs(r(estimate)/r(se)))
    post `posth' ("`w'") ("baseline_ln_per100k") (`hi') (b) (se) (p) (w_p1) (w_p99) (pop_p5) (n_cells) (n_counties)

    * 2) share winsor p1-p99
    use `base', clear
    quietly count
    scalar n_cells = r(N)
    quietly count if tag_county==1
    scalar n_counties = r(N)
    gen treat = share
    replace treat = w_p1 if treat < w_p1
    replace treat = w_p99 if treat > w_p99
    quietly areg eduy_mean c.treat##ib0.post i.birth_i, absorb(county_num) vce(cluster county_num)
    quietly lincom 1.post#c.treat
    scalar b = r(estimate)
    scalar se = r(se)
    scalar p = 2 * ttail(e(df_r), abs(r(estimate)/r(se)))
    post `posth' ("`w'") ("share_winsor_p1p99") (`hi') (b) (se) (p) (w_p1) (w_p99) (pop_p5) (n_cells) (n_counties)

    * 3) IHS share
    use `base', clear
    quietly count
    scalar n_cells = r(N)
    quietly count if tag_county==1
    scalar n_counties = r(N)
    gen treat = asinh(share*1000)
    quietly areg eduy_mean c.treat##ib0.post i.birth_i, absorb(county_num) vce(cluster county_num)
    quietly lincom 1.post#c.treat
    scalar b = r(estimate)
    scalar se = r(se)
    scalar p = 2 * ttail(e(df_r), abs(r(estimate)/r(se)))
    post `posth' ("`w'") ("ihs_share_x1000") (`hi') (b) (se) (p) (w_p1) (w_p99) (pop_p5) (n_cells) (n_counties)

    * 4) share winsor, drop bottom-5% pop counties
    use `base', clear
    keep if pop_1953 >= pop_p5
    quietly count
    scalar n_cells = r(N)
    quietly count if tag_county==1
    scalar n_counties = r(N)
    gen treat = share
    replace treat = w_p1 if treat < w_p1
    replace treat = w_p99 if treat > w_p99
    quietly areg eduy_mean c.treat##ib0.post i.birth_i, absorb(county_num) vce(cluster county_num)
    quietly lincom 1.post#c.treat
    scalar b = r(estimate)
    scalar se = r(se)
    scalar p = 2 * ttail(e(df_r), abs(r(estimate)/r(se)))
    post `posth' ("`w'") ("share_winsor_p1p99_poptrim5") (`hi') (b) (se) (p) (w_p1) (w_p99) (pop_p5) (n_cells) (n_counties)

    * 5) IHS share, drop bottom-5% pop counties
    use `base', clear
    keep if pop_1953 >= pop_p5
    quietly count
    scalar n_cells = r(N)
    quietly count if tag_county==1
    scalar n_counties = r(N)
    gen treat = asinh(share*1000)
    quietly areg eduy_mean c.treat##ib0.post i.birth_i, absorb(county_num) vce(cluster county_num)
    quietly lincom 1.post#c.treat
    scalar b = r(estimate)
    scalar se = r(se)
    scalar p = 2 * ttail(e(df_r), abs(r(estimate)/r(se)))
    post `posth' ("`w'") ("ihs_share_x1000_poptrim5") (`hi') (b) (se) (p) (w_p1) (w_p99) (pop_p5) (n_cells) (n_counties)
}

postclose `posth'
use "`out'", clear
sort spec wave
export delimited using "${proj}/data/temp/main_share_treatment_specs_summary_v2.csv", replace
save "${proj}/data/temp/main_share_treatment_specs_summary_v2.dta", replace
list, clean noobs
exit, clear
