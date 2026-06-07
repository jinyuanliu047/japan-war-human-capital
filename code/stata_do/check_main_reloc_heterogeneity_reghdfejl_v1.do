*******************************************************
* Relocation heterogeneity (reloc_any subgroup)
* Estimator: reghdfejl
* Note: reloc_any is used as subgroup split (0/1), no reloc*post term
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

use "${proj}/data/temp/county_university_relocation_any_v1.dta", clear
keep countyid_curr6 reloc_any
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
replace reloc_any = 0 if missing(reloc_any)
duplicates drop countyid_curr6, force
tempfile reloc
save `reloc'
global reloc_tmp "`reloc'"

capture program drop _run_wave_reloc
program define _run_wave_reloc, rclass
    syntax , WAVE(integer) HI(integer)

    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr)==1939
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="" | countyid_curr6=="000000"

    merge m:1 countyid_curr6 using "$reloc_tmp", keep(master match) nogen
    replace reloc_any = 0 if missing(reloc_any)

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)

    quietly count if reloc_any==0
    return scalar n_cells0 = r(N)
    quietly count if reloc_any==1
    return scalar n_cells1 = r(N)

    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post if reloc_any==0, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store r`wave'_g0
    estadd local Group "reloc0"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    return scalar b0 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se0 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p0 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))

    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post if reloc_any==1, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store r`wave'_g1
    estadd local Group "reloc1"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    return scalar b1 = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se1 = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p1 = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
end

eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str10 subgroup = ""
gen b = .
gen se = .
gen p = .
gen n_cells = .
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978

    quietly _run_wave_reloc, wave(`w') hi(`hi')

    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace subgroup = "reloc0" in `n'
    replace b = r(b0) in `n'
    replace se = r(se0) in `n'
    replace p = r(p0) in `n'
    replace n_cells = r(n_cells0) in `n'
    save `summary', replace

    use `summary', clear
    local n = _N + 1
    set obs `n'
    replace wave = "`w'" in `n'
    replace subgroup = "reloc1" in `n'
    replace b = r(b1) in `n'
    replace se = r(se1) in `n'
    replace p = r(p1) in `n'
    replace n_cells = r(n_cells1) in `n'
    save `summary', replace
}

use `summary', clear
sort wave subgroup
export delimited using "${proj}/result/table/main_reloc_heterogeneity_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_reloc_heterogeneity_reghdfejl_summary_v1.dta", replace

esttab r1982_g0 r1982_g1 r1990_g0 r1990_g1 r2000_g0 r2000_g1 ///
    using "${proj}/result/table/main_reloc_heterogeneity_reghdfejl_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab r1982_g0 r1982_g1 r1990_g0 r1990_g1 r2000_g0 r2000_g1 ///
    using "${proj}/result/table/main_reloc_heterogeneity_reghdfejl_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Group County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
