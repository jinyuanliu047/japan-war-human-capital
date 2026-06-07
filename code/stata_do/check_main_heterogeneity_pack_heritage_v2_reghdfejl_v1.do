*******************************************************
* Heterogeneity pack (reghdfejl)
* 1) Treatment intensity tercile: ln_martyr_per100k_1953
* 2) Base education tercile: pre-1940 county eduy_mean
* 3) National anti-war heritage site (harmonized): heritage_any (0/1)
* 4) Massacre severity: ln_massacre_death high/low (median split)
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
    di as error "reghdfejl not found"
    exit 198
}

use "${proj}/data/temp/county_controls_full_heritage_v2.dta", clear
keep countyid_curr6 heritage_any ln_massacre_death
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
replace heritage_any = 0 if missing(heritage_any)
replace ln_massacre_death = 0 if missing(ln_massacre_death)
keep countyid_curr6 heritage_any ln_massacre_death
duplicates drop countyid_curr6, force
tempfile ctrl
save `ctrl'
global ctrl_tmp "`ctrl'"

capture program drop _prep_wave
program define _prep_wave
    syntax , WAVE(integer) HI(integer)

    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr,1920,`hi')
    drop if floor(birthyr)==1939
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="" | countyid_curr6=="000000"

    merge m:1 countyid_curr6 using "$ctrl_tmp", keep(master match) nogen
    replace heritage_any = 0 if missing(heritage_any)
    replace ln_massacre_death = 0 if missing(ln_massacre_death)

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)
    sort county_num birth_i

    by county_num: egen __x = max(ln_martyr_per100k_1953)
    egen __tag = tag(county_num)
    xtile __tx_ter = __x if __tag==1, nq(3)
    by county_num: egen tx_tercile = max(__tx_ter)

    egen __base = mean(eduy_mean) if inrange(birth_i,1920,1938), by(county_num)
    by county_num: egen __base_fill = max(__base)
    replace __base = __base_fill if missing(__base)
    quietly summarize __base
    replace __base = r(mean) if missing(__base)
    xtile __be_ter = __base if __tag==1, nq(3)
    by county_num: egen baseedu_tercile = max(__be_ter)

    quietly summarize ln_massacre_death if __tag==1 & ln_massacre_death>0, detail
    local med = r(p50)
    gen massacre_high = (ln_massacre_death>`med') if ln_massacre_death>0
    replace massacre_high = 0 if ln_massacre_death==0

    drop __x __tag __tx_ter __base __base_fill __be_ter
end

capture program drop _run_one
program define _run_one, rclass
    syntax , PANEL(string) GROUPVAR(name) GROUPVAL(integer) MODEL(string) DIM(string) GLABEL(string)

    use "`panel'", clear

    quietly count if `groupvar'==`groupval'
    return scalar n_cells = r(N)

    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post if `groupvar'==`groupval', ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Dim "`dim'"
    estadd local Group "`glabel'"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))
end

eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str24 dim = ""
gen str16 grp = ""
gen b = .
gen se = .
gen p = .
gen n_cells = .
save `summary', replace

local models ""

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978

    quietly _prep_wave, wave(`w') hi(`hi')
    tempfile wpanel
    save `wpanel', replace

    foreach g in 1 2 3 {
        local m = "htx`w'_`g'"
        quietly _run_one, panel("`wpanel'") groupvar(tx_tercile) groupval(`g') model("`m'") dim("treat_tercile") glabel("T`g'")
        local models "`models' `m'"
        use `summary', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        replace dim = "treat_tercile" in `n'
        replace grp = "T`g'" in `n'
        replace b = r(b) in `n'
        replace se = r(se) in `n'
        replace p = r(p) in `n'
        replace n_cells = r(n_cells) in `n'
        save `summary', replace
    }

    foreach g in 1 2 3 {
        local m = "hbe`w'_`g'"
        quietly _run_one, panel("`wpanel'") groupvar(baseedu_tercile) groupval(`g') model("`m'") dim("baseedu_tercile") glabel("B`g'")
        local models "`models' `m'"
        use `summary', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        replace dim = "baseedu_tercile" in `n'
        replace grp = "B`g'" in `n'
        replace b = r(b) in `n'
        replace se = r(se) in `n'
        replace p = r(p) in `n'
        replace n_cells = r(n_cells) in `n'
        save `summary', replace
    }

    foreach g in 0 1 {
        local m = "hhr`w'_`g'"
        quietly _run_one, panel("`wpanel'") groupvar(heritage_any) groupval(`g') model("`m'") dim("heritage_any") glabel("H`g'")
        local models "`models' `m'"
        use `summary', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        replace dim = "heritage_any" in `n'
        replace grp = "H`g'" in `n'
        replace b = r(b) in `n'
        replace se = r(se) in `n'
        replace p = r(p) in `n'
        replace n_cells = r(n_cells) in `n'
        save `summary', replace
    }

    foreach g in 0 1 {
        local m = "hmc`w'_`g'"
        quietly _run_one, panel("`wpanel'") groupvar(massacre_high) groupval(`g') model("`m'") dim("massacre_ln_high") glabel("D`g'")
        local models "`models' `m'"
        use `summary', clear
        local n = _N + 1
        set obs `n'
        replace wave = "`w'" in `n'
        replace dim = "massacre_ln_high" in `n'
        replace grp = "D`g'" in `n'
        replace b = r(b) in `n'
        replace se = r(se) in `n'
        replace p = r(p) in `n'
        replace n_cells = r(n_cells) in `n'
        save `summary', replace
    }
}

use `summary', clear
gen t_abs = abs(b/se)
sort wave dim grp
export delimited using "${proj}/result/table/main_heterogeneity_pack_heritage_v2_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/main_heterogeneity_pack_heritage_v2_reghdfejl_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/main_heterogeneity_pack_heritage_v2_reghdfejl_v1.rtf", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Dim Group County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/main_heterogeneity_pack_heritage_v2_reghdfejl_v1.tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Dim Group County_FE Cohort_FE) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
