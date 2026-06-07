*******************************************************
* Gender and urban-rural heterogeneity from subgroup panels
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global paneldir "${proj}/data/temp/gender_urban_groups_v2"

capture which esttab
if _rc != 0 {
    ssc install estout, replace
}

capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
}

capture program drop _run_group
program define _run_group, rclass
    syntax , WAVE(integer) GROUP(string) MODEL(string)
    use "${paneldir}/panel_`wave'_`group'.dta", clear
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)
    quietly count
    return scalar n_cells = r(N)
    quietly count if !missing(county_num)
    return scalar n_rows = r(N)
    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post c.minority_share, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Group "`group'"
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
end

eststo clear

tempfile gsum
clear
set obs 0
gen str6 wave = ""
gen str12 subgroup = ""
gen b = .
gen se = .
gen p = .
gen n_cells = .
save `gsum', replace

foreach w in 1982 1990 2000 {
    foreach g in male female {
        local m = "g`w'_`g'"
        quietly _run_group, wave(`w') group("`g'") model("`m'")
        use `gsum', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        replace subgroup = "`g'" in `n'
        replace b = r(b) in `n'
        replace se = r(se) in `n'
        replace p = r(p) in `n'
        replace n_cells = r(n_cells) in `n'
        save `gsum', replace
    }
}

use `gsum', clear
export delimited using "${proj}/result/table/main_individual_heterogeneity_gender_reghdfejl_summary_v3.csv", replace
save "${proj}/result/table/main_individual_heterogeneity_gender_reghdfejl_summary_v3.dta", replace

esttab g1982_male g1982_female g1990_male g1990_female g2000_male g2000_female ///
    using "${proj}/result/table/main_individual_heterogeneity_gender_reghdfejl_v3.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab g1982_male g1982_female g1990_male g1990_female g2000_male g2000_female ///
    using "${proj}/result/table/main_individual_heterogeneity_gender_reghdfejl_v3.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

tempfile usum
clear
set obs 0
gen str6 wave = ""
gen str12 subgroup = ""
gen b = .
gen se = .
gen p = .
gen n_cells = .
save `usum', replace

foreach w in 1990 2000 {
    foreach g in urban rural {
        local m = "u`w'_`g'"
        quietly _run_group, wave(`w') group("`g'") model("`m'")
        use `usum', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        replace subgroup = "`g'" in `n'
        replace b = r(b) in `n'
        replace se = r(se) in `n'
        replace p = r(p) in `n'
        replace n_cells = r(n_cells) in `n'
        save `usum', replace
    }
}

use `usum', clear
export delimited using "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfejl_summary_v3.csv", replace
save "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfejl_summary_v3.dta", replace

esttab u1990_urban u1990_rural u2000_urban u2000_rural ///
    using "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfejl_v3.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab u1990_urban u1990_rural u2000_urban u2000_rural ///
    using "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfejl_v3.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group Controls County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
