*******************************************************
* X-measurement x education-Y sweep
* eduy_mean: full DID
* pri_comp / mid_comp: explicitly marked unavailable if only post cohorts exist
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
}

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
duplicates drop countyid_curr6, force
tempfile ctrl
save `ctrl'

capture program drop _make_treat
program define _make_treat
    syntax , XSPEC(string)
    if "`xspec'" == "ln_per100k" {
        gen treat = ln_martyr_per100k_1953
    }
    else if "`xspec'" == "ihs_per100k" {
        gen treat = asinh(martyr_per100k_1953)
    }
    else if "`xspec'" == "raw_count" {
        gen treat = martyr_count_1931_1945
    }
    else if "`xspec'" == "ln_raw" {
        gen treat = ln_martyr_raw
    }
    else if "`xspec'" == "share_winsor" {
        gen __share = martyr_count_1931_1945 / pop_1953 if pop_1953 > 0
        egen __tag = tag(county_num)
        quietly _pctile __share if __tag == 1, p(1 99)
        local p1 = r(r1)
        local p99 = r(r2)
        gen treat = __share
        replace treat = `p1' if treat < `p1'
        replace treat = `p99' if treat > `p99'
        drop __share __tag
    }
    else if "`xspec'" == "ihs_share" {
        gen __share = martyr_count_1931_1945 / pop_1953 if pop_1953 > 0
        gen treat = asinh(__share * 1000)
        drop __share
    }
end

capture program drop _post_result
program define _post_result
    syntax , YVAR(string) XSPEC(string) WAVE(integer) SPEC(string) STATUS(string) NCELLS(real)
    local b = .
    local se = .
    local p = .
    if "`status'" == "ok" {
        capture local b = _b[1.post#c.treat]
        capture local se = _se[1.post#c.treat]
        if _rc != 0 {
            local b = _b[c.treat#1.post]
            local se = _se[c.treat#1.post]
        }
        local p = 2*ttail(e(df_r), abs(`b' / `se'))
    }
    post $POSTH ("`yvar'") ("`xspec'") (`wave') ("`spec'") ("`status'") (`b') (`se') (`p') (`ncells')
end

tempname posth
tempfile out
postfile `posth' str16 yvar str16 xspec int wave str18 spec str24 status ///
    double b se p long n_cells using "`out'", replace
global POSTH "`posth'"

foreach w in 1982 1990 2000 {
    local hi = 1960
    if `w' == 1990 local hi = 1968
    if `w' == 2000 local hi = 1978

    use "${proj}/data/temp/did_`w'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr) == 1939
    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)
    merge m:1 countyid_curr6 using `ctrl', keep(master match) nogen
    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
        ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
        massacre_event_w ln_massacre_death {
        replace `v' = 0 if missing(`v')
    }

    foreach x in ln_per100k ihs_per100k raw_count ln_raw share_winsor ihs_share {
        preserve
            quietly _make_treat, xspec("`x'")
            keep if !missing(eduy_mean, treat, post, county_num, birth_i, n_obs)
            quietly count
            local n = r(N)
            quietly reghdfejl eduy_mean c.treat##ib0.post [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
            quietly _post_result, yvar("eduy_mean") xspec("`x'") wave(`w') spec("wt_base") status("ok") ncells(`n')

            quietly reghdfejl eduy_mean c.treat##ib0.post ///
                c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
                c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
                c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post ///
                [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
            quietly _post_result, yvar("eduy_mean") xspec("`x'") wave(`w') spec("wt_fullctrl") status("ok") ncells(`n')
        restore
    }

    foreach y in pri_comp mid_comp {
        foreach x in ln_per100k ihs_per100k raw_count ln_raw share_winsor ihs_share {
            quietly _post_result, yvar("`y'") xspec("`x'") wave(`w') spec("wt_base") status("postonly_unavailable") ncells(.)
            quietly _post_result, yvar("`y'") xspec("`x'") wave(`w') spec("wt_fullctrl") status("postonly_unavailable") ncells(.)
        }
    }
}

postclose `posth'
use "`out'", clear
sort yvar xspec wave spec
export delimited using "${proj}/result/table/xy_education_sweep_reghdfejl_summary_v3.csv", replace
save "${proj}/result/table/xy_education_sweep_reghdfejl_summary_v3.dta", replace

exit, clear
