*******************************************************
* X-measurement full pack (reghdfejl)
* For each X spec, run:
*   A) Main regression: baseline / full controls
*   B) Heterogeneity: heritage_any=0/1 (harmonized v2)
*   C) Robustness: + reloc_any#post
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
}

use "${proj}/data/temp/county_controls_full_heritage_v2.dta", clear
keep countyid_curr6 heritage_any sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
replace heritage_any = 0 if missing(heritage_any)
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w ln_massacre_death {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
keep countyid_curr6 heritage_any sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt massacre_event_w ln_massacre_death
duplicates drop countyid_curr6, force
tempfile ctrl
save `ctrl'
global ctrl_tmp "`ctrl'"

use "${proj}/data/temp/county_university_relocation_any_v1.dta", clear
keep countyid_curr6 reloc_any
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
replace reloc_any = 0 if missing(reloc_any)
duplicates drop countyid_curr6, force
tempfile reloc
save `reloc'
global reloc_tmp "`reloc'"

capture program drop _make_treat
program define _make_treat
    syntax , XSPEC(string)
    if "`xspec'"=="ln_per100k" {
        gen treat = ln_martyr_per100k_1953
    }
    else if "`xspec'"=="ihs_per100k" {
        gen treat = asinh(martyr_per100k_1953)
    }
    else if "`xspec'"=="raw_count" {
        gen treat = martyr_count_1931_1945
    }
    else if "`xspec'"=="ln_raw" {
        gen treat = ln_martyr_raw
    }
    else if "`xspec'"=="share_winsor" {
        gen __share = martyr_count_1931_1945/pop_1953 if pop_1953>0
        egen __tag = tag(county_num)
        quietly _pctile __share if __tag==1, p(1 99)
        local p1 = r(r1)
        local p99 = r(r2)
        gen treat = __share
        replace treat = `p1' if treat<`p1'
        replace treat = `p99' if treat>`p99'
        drop __share __tag
    }
    else if "`xspec'"=="ihs_share" {
        gen __share = martyr_count_1931_1945/pop_1953 if pop_1953>0
        gen treat = asinh(__share*1000)
        drop __share
    }
    else {
        di as error "unknown xspec: `xspec'"
        exit 198
    }
end

capture program drop _prep_wave
program define _prep_wave
    syntax , WAVE(integer) HI(integer)
    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr,1920,`hi')
    drop if floor(birthyr)==1939
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953) & !missing(martyr_count_1931_1945) & !missing(pop_1953)
    drop if countyid_curr6=="" | countyid_curr6=="000000"
    merge m:1 countyid_curr6 using "$ctrl_tmp", keep(master match) nogen
    merge m:1 countyid_curr6 using "$reloc_tmp", keep(master match) nogen
    replace heritage_any = 0 if missing(heritage_any)
    replace reloc_any = 0 if missing(reloc_any)
    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)
end

capture program drop _post_result
program define _post_result
    syntax , MODULE(string) XSPEC(string) WAVE(integer) LABEL(string) Ncells(real)
    local b = _b[1.post#c.treat]
    local se = _se[1.post#c.treat]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    post $POSTH ("`module'") ("`xspec'") (`wave') ("`label'") (`b') (`se') (`p') (`ncells')
end

tempname posth
tempfile out
postfile `posth' str12 module str16 xspec int wave str24 spec ///
    double b se p long n_cells using "`out'", replace
global POSTH "`posth'"

foreach x in ln_per100k ihs_per100k raw_count ln_raw share_winsor ihs_share {
    foreach w in 1982 1990 2000 {
        local hi = 1960
        if "`w'"=="1990" local hi = 1968
        if "`w'"=="2000" local hi = 1978

        quietly _prep_wave, wave(`w') hi(`hi')
        quietly _make_treat, xspec("`x'")
        quietly count
        local n = r(N)

        quietly reghdfejl eduy_mean c.treat##ib0.post, absorb(county_num birth_i) vce(cluster county_num)
        quietly _post_result, module("main") xspec("`x'") wave(`w') label("baseline") ncells(`n')

        quietly reghdfejl eduy_mean c.treat##ib0.post ///
            c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
            c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
            c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
            absorb(county_num birth_i) vce(cluster county_num)
        quietly _post_result, module("main") xspec("`x'") wave(`w') label("full_ctrl") ncells(`n')

        quietly reghdfejl eduy_mean c.treat##ib0.post if heritage_any==0, absorb(county_num birth_i) vce(cluster county_num)
        quietly count if heritage_any==0
        local n0 = r(N)
        quietly _post_result, module("hetero_herit") xspec("`x'") wave(`w') label("herit0") ncells(`n0')

        quietly reghdfejl eduy_mean c.treat##ib0.post if heritage_any==1, absorb(county_num birth_i) vce(cluster county_num)
        quietly count if heritage_any==1
        local n1 = r(N)
        quietly _post_result, module("hetero_herit") xspec("`x'") wave(`w') label("herit1") ncells(`n1')

        quietly reghdfejl eduy_mean c.treat##ib0.post c.reloc_any#c.post, ///
            absorb(county_num birth_i) vce(cluster county_num)
        quietly _post_result, module("robust") xspec("`x'") wave(`w') label("reloc_post") ncells(`n')

        quietly reghdfejl eduy_mean c.treat##ib0.post c.reloc_any#c.post ///
            c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
            c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post ///
            c.massacre_event_w#c.post c.ln_massacre_death#c.post c.ln_memorial_cnt#c.post, ///
            absorb(county_num birth_i) vce(cluster county_num)
        quietly _post_result, module("robust") xspec("`x'") wave(`w') label("full+reloc") ncells(`n')
    }
}

postclose `posth'
use "`out'", clear
gen t_abs = abs(b/se)
sort module xspec wave spec
export delimited using "${proj}/result/table/xspec_fullpack_heritage_v2_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/xspec_fullpack_heritage_v2_reghdfejl_summary_v1.dta", replace

exit, clear
