*******************************************************
* Major-case split-sample regressions
* Split by raw massacre_death_w: zero / low / high
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 {
    ssc install estout, replace
}

capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found. Please install reghdfejl first."
    exit 198
}

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w massacre_death_w
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
drop if countyid_curr6=="" | countyid_curr6=="000000"
duplicates drop countyid_curr6, force

foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
    ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
    massacre_event_w massacre_death_w {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)

tempfile ctrl
save `ctrl'
global ctrl_tmp "`ctrl'"

capture program drop _run_wave_split
program define _run_wave_split, rclass
    syntax , WAVE(integer) HI(integer)

    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="" | countyid_curr6=="000000"

    merge m:1 countyid_curr6 using "$ctrl_tmp", keep(master match) nogen
    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ///
        ln_clan qk_cnt_m45_pre1940 qk_maxmag_pre1940 ln_memorial_cnt ///
        massacre_event_w massacre_death_w {
        replace `v' = 0 if missing(`v')
    }

    egen county_num = group(countyid_curr6)
    egen __tag = tag(county_num)
    quietly summarize massacre_death_w if __tag==1 & massacre_death_w>0, detail
    local med = r(p50)
    drop __tag

    gen death_grp = 0 if massacre_death_w==0
    replace death_grp = 1 if massacre_death_w>0 & massacre_death_w<=`med'
    replace death_grp = 2 if massacre_death_w>`med'

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940

    forvalues g = 0/2 {
        quietly count if death_grp==`g'
        return scalar n_cells`g' = r(N)

        quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post if death_grp==`g', ///
            absorb(county_num birth_i) vce(cluster county_num)
        estimates store s`wave'_g`g'_b
        estadd local Group "death`g'"
        estadd local FullControls "N"
        estadd local County_FE "Y"
        estadd local Cohort_FE "Y"
        return scalar b`g'b = _b[1.post#c.ln_martyr_per100k_1953]
        return scalar se`g'b = _se[1.post#c.ln_martyr_per100k_1953]
        return scalar p`g'b = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))

        quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post ///
            c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
            c.ln_clan#c.post c.qk_cnt_m45_pre1940#c.post c.qk_maxmag_pre1940#c.post c.ln_memorial_cnt#c.post ///
            if death_grp==`g', absorb(county_num birth_i) vce(cluster county_num)
        estimates store s`wave'_g`g'_f
        estadd local Group "death`g'"
        estadd local FullControls "Y"
        estadd local County_FE "Y"
        estadd local Cohort_FE "Y"
        return scalar b`g'f = _b[1.post#c.ln_martyr_per100k_1953]
        return scalar se`g'f = _se[1.post#c.ln_martyr_per100k_1953]
        return scalar p`g'f = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
    }
end

eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str10 subgroup = ""
gen str16 spec = ""
gen b = .
gen se = .
gen p = .
gen n_cells = .
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978

    quietly _run_wave_split, wave(`w') hi(`hi')

    foreach g in 0 1 2 {
        foreach s in b f {
            use `summary', clear
            local n = _N + 1
            set obs `n'
            replace wave = "`w'" in `n'
            replace subgroup = "death`g'" in `n'
            if "`s'"=="b" replace spec = "baseline" in `n'
            if "`s'"=="f" replace spec = "full_controls" in `n'
            replace b = r(b`g'`s') in `n'
            replace se = r(se`g'`s') in `n'
            replace p = r(p`g'`s') in `n'
            replace n_cells = r(n_cells`g') in `n'
            save `summary', replace
        }
    }
}

use `summary', clear
sort wave subgroup spec
export delimited using "${proj}/result/table/main_majorcase_rawdeath_split_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_majorcase_rawdeath_split_reghdfejl_summary_v1.dta", replace

esttab s1982_g0_b s1982_g0_f s1982_g1_b s1982_g1_f s1982_g2_b s1982_g2_f ///
       s1990_g0_b s1990_g0_f s1990_g1_b s1990_g1_f s1990_g2_b s1990_g2_f ///
       s2000_g0_b s2000_g0_f s2000_g1_b s2000_g1_f s2000_g2_b s2000_g2_f ///
    using "${proj}/result/table/main_majorcase_rawdeath_split_reghdfejl_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group FullControls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab s1982_g0_b s1982_g0_f s1982_g1_b s1982_g1_f s1982_g2_b s1982_g2_f ///
       s1990_g0_b s1990_g0_f s1990_g1_b s1990_g1_f s1990_g2_b s1990_g2_f ///
       s2000_g0_b s2000_g0_f s2000_g1_b s2000_g1_f s2000_g2_b s2000_g2_f ///
    using "${proj}/result/table/main_majorcase_rawdeath_split_reghdfejl_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group FullControls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
