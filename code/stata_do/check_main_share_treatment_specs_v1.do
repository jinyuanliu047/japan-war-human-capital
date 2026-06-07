*******************************************************
* Main DID robustness: share-based treatment construction
* Keep original ln(per100k) spec unchanged as benchmark
* Baseline design fixed across waves:
*   - cohorts 1920..hi (1982:1960, 1990:1968, 2000:1978)
*   - drop cohort 1939
*   - post = 1[birth >= 1940]
*   - county FE + birth-year FE, cluster at county
*
* Specs:
*  1) baseline_ln_per100k
*  2) share_winsor_p1p99               : share=count/pop
*  3) ihs_share_x1000                  : asinh(share*1000)
*  4) share_winsor_p1p99_poptrim5      : drop bottom-5% pop counties
*  5) ihs_share_x1000_poptrim5         : drop bottom-5% pop counties
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _run_one
program define _run_one, rclass
    syntax , WAVE(string) DATAFILE(string) HI(integer) SPEC(string)

    use "`datafile'", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr) == 1939
    keep if !missing(eduy_mean) & !missing(countyid_curr6)
    drop if countyid_curr6=="000000"
    keep if !missing(martyr_per100k_1953) & !missing(martyr_count_1931_1945) & !missing(pop_1953)

    gen birth_i = floor(birthyr)
    egen county_num = group(countyid_curr6)
    gen post = birth_i >= 1940

    * County-level share (no *100k)
    gen share = martyr_count_1931_1945 / pop_1953 if pop_1953>0

    * County-level tags and thresholds
    egen tag_county = tag(county_num)

    scalar w_p1 = .
    scalar w_p99 = .
    scalar pop_p5 = .

    preserve
        keep if tag_county==1
        keep pop_1953 share
        _pctile share, p(1 99)
        scalar w_p1 = r(r1)
        scalar w_p99 = r(r2)
        _pctile pop_1953, p(5)
        scalar pop_p5 = r(r1)
    restore

    gen keep_poptrim5 = pop_1953 >= pop_p5 if pop_1953<.

    if inlist("`spec'", "share_winsor_p1p99_poptrim5", "ihs_share_x1000_poptrim5") {
        keep if keep_poptrim5==1
    }

    quietly count
    return scalar n_cells = r(N)
    quietly count if tag_county==1
    return scalar n_counties = r(N)
    drop tag_county

    if "`spec'" == "baseline_ln_per100k" {
        gen treat = ln_martyr_per100k_1953
        quietly areg eduy_mean c.treat##ib0.post i.birth_i, absorb(county_num) vce(cluster county_num)
        quietly lincom 1.post#c.treat
    }
    else if inlist("`spec'", "share_winsor_p1p99", "share_winsor_p1p99_poptrim5") {
        gen treat = share
        replace treat = w_p1 if treat < w_p1
        replace treat = w_p99 if treat > w_p99
        quietly areg eduy_mean c.treat##ib0.post i.birth_i, absorb(county_num) vce(cluster county_num)
        quietly lincom 1.post#c.treat
    }
    else if inlist("`spec'", "ihs_share_x1000", "ihs_share_x1000_poptrim5") {
        gen treat = asinh(share*1000)
        quietly areg eduy_mean c.treat##ib0.post i.birth_i, absorb(county_num) vce(cluster county_num)
        quietly lincom 1.post#c.treat
    }
    else {
        display as error "Unknown spec: `spec'"
        exit 198
    }

    return scalar b = r(estimate)
    return scalar se = r(se)
    return scalar p = 2 * ttail(e(df_r), abs(r(estimate) / r(se)))
    return scalar w_p1 = w_p1
    return scalar w_p99 = w_p99
    return scalar pop_p5 = pop_p5
end

tempname posth
tempfile out
postfile `posth' str6 wave str32 spec int sample_hi ///
    double b se p w_p1 w_p99 pop_p5 ///
    long n_cells n_counties using "`out'", replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'" == "1990" local hi = 1968
    if "`w'" == "2000" local hi = 1978

    local d "${proj}/data/temp/did_`w'_county_birthyr_pop1953_unwt_v2.dta"

    foreach s in baseline_ln_per100k share_winsor_p1p99 ihs_share_x1000 share_winsor_p1p99_poptrim5 ihs_share_x1000_poptrim5 {
        quietly _run_one, wave("`w'") datafile("`d'") hi(`hi') spec("`s'")
        post `posth' ("`w'") ("`s'") (`hi') ///
            (r(b)) (r(se)) (r(p)) (r(w_p1)) (r(w_p99)) (r(pop_p5)) ///
            (r(n_cells)) (r(n_counties))
    }
}

postclose `posth'
use "`out'", clear
sort spec wave
export delimited using "${proj}/data/temp/main_share_treatment_specs_summary_v1.csv", replace
save "${proj}/data/temp/main_share_treatment_specs_summary_v1.dta", replace
list, clean noobs
exit, clear
