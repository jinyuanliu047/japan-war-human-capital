*******************************************************
* Main DID robustness: alternative treatment construction
* Baseline design kept fixed across waves:
*   - cohorts 1920..hi (1982:1960, 1990:1968, 2000:1978)
*   - drop cohort 1939
*   - post = 1[birth >= 1940]
*   - county FE + birth-year FE, cluster at county
*
* Specs:
*  1) ratio_winsor_p1p99: winsorized martyr_per100k_1953
*  2) ihs_ratio: asinh(martyr_per100k_1953)
*  3) raw_count_ctrl_lnpop_post: raw martyr count + ln(pop1953)#post control
*  4) raw_count_by_popq{1,2,3}: raw count within pop terciles
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture program drop _run_one
program define _run_one, rclass
    syntax , WAVE(string) DATAFILE(string) HI(integer) SPEC(string) [POPQ(integer 0)]

    use "`datafile'", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr) == 1939
    keep if !missing(eduy_mean) & !missing(countyid_curr6)
    drop if countyid_curr6=="000000"

    keep if !missing(martyr_per100k_1953) & !missing(martyr_count_1931_1945) & !missing(pop_1953)

    gen birth_i = floor(birthyr)
    egen county_num = group(countyid_curr6)
    gen post = birth_i >= 1940
    gen ln_pop1953 = ln(pop_1953) if pop_1953>0

    * county-level population tercile (constant within county)
    egen tag_county = tag(county_num)
    tempvar pop_q_tmp
    xtile `pop_q_tmp' = pop_1953 if tag_county==1, nq(3)
    sort county_num
    by county_num: egen pop_q = max(`pop_q_tmp')
    drop `pop_q_tmp'

    if `popq' > 0 {
        keep if pop_q == `popq'
    }

    quietly count
    return scalar n_cells = r(N)
    quietly count if tag_county==1
    return scalar n_counties = r(N)
    drop tag_county

    scalar w_p1 = .
    scalar w_p99 = .

    if "`spec'" == "ratio_winsor_p1p99" {
        preserve
            keep county_num martyr_per100k_1953
            duplicates drop county_num, force
            _pctile martyr_per100k_1953, p(1 99)
            scalar w_p1 = r(r1)
            scalar w_p99 = r(r2)
        restore

        gen treat = martyr_per100k_1953
        replace treat = w_p1 if treat < w_p1
        replace treat = w_p99 if treat > w_p99

        quietly areg eduy_mean c.treat##ib0.post i.birth_i, ///
            absorb(county_num) vce(cluster county_num)
        quietly lincom 1.post#c.treat
    }
    else if "`spec'" == "ihs_ratio" {
        gen treat = asinh(martyr_per100k_1953)

        quietly areg eduy_mean c.treat##ib0.post i.birth_i, ///
            absorb(county_num) vce(cluster county_num)
        quietly lincom 1.post#c.treat
    }
    else if "`spec'" == "raw_count_ctrl_lnpop_post" {
        gen treat = martyr_count_1931_1945

        quietly areg eduy_mean c.treat##ib0.post c.ln_pop1953##ib0.post i.birth_i, ///
            absorb(county_num) vce(cluster county_num)
        quietly lincom 1.post#c.treat
    }
    else if "`spec'" == "raw_count_by_popq" {
        gen treat = martyr_count_1931_1945

        quietly areg eduy_mean c.treat##ib0.post i.birth_i, ///
            absorb(county_num) vce(cluster county_num)
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
end

tempname posth
tempfile out
postfile `posth' str6 wave str30 spec int sample_hi int pop_group ///
    double b se p w_p1 w_p99 ///
    long n_cells n_counties using "`out'", replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'" == "1990" local hi = 1968
    if "`w'" == "2000" local hi = 1978

    local d "${proj}/data/temp/did_`w'_county_birthyr_pop1953_unwt_v2.dta"

    quietly _run_one, wave("`w'") datafile("`d'") hi(`hi') spec("ratio_winsor_p1p99")
    post `posth' ("`w'") ("ratio_winsor_p1p99") (`hi') (0) ///
        (r(b)) (r(se)) (r(p)) (r(w_p1)) (r(w_p99)) (r(n_cells)) (r(n_counties))

    quietly _run_one, wave("`w'") datafile("`d'") hi(`hi') spec("ihs_ratio")
    post `posth' ("`w'") ("ihs_ratio") (`hi') (0) ///
        (r(b)) (r(se)) (r(p)) (r(w_p1)) (r(w_p99)) (r(n_cells)) (r(n_counties))

    quietly _run_one, wave("`w'") datafile("`d'") hi(`hi') spec("raw_count_ctrl_lnpop_post")
    post `posth' ("`w'") ("raw_count_ctrl_lnpop_post") (`hi') (0) ///
        (r(b)) (r(se)) (r(p)) (r(w_p1)) (r(w_p99)) (r(n_cells)) (r(n_counties))

    foreach g in 1 2 3 {
        quietly _run_one, wave("`w'") datafile("`d'") hi(`hi') spec("raw_count_by_popq") popq(`g')
        post `posth' ("`w'") ("raw_count_by_popq") (`hi') (`g') ///
            (r(b)) (r(se)) (r(p)) (r(w_p1)) (r(w_p99)) (r(n_cells)) (r(n_counties))
    }
}

postclose `posth'
use "`out'", clear
sort spec wave pop_group
export delimited using "${proj}/data/temp/main_alt_treatment_specs_summary_v1.csv", replace
save "${proj}/data/temp/main_alt_treatment_specs_summary_v1.dta", replace
list, clean noobs
