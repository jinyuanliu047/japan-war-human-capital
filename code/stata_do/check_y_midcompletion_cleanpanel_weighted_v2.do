*******************************************************
* Y = county-by-cohort middle-school completion rate
* Built from cleaned census (AER-style harmonized files)
* county x birth cohort means of 1[yedu>=9]
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
}

* old->current county maps from AER county_data
use "${proj}/data/raw/county_data.dta", clear
keep region1982 region1990 region2000 region2010
drop if missing(region2010)
gen str6 county_curr6 = string(region2010, "%06.0f")

preserve
    keep region1982 county_curr6
    drop if missing(region1982)
    gen str6 old6 = string(region1982, "%06.0f")
    keep old6 county_curr6
    duplicates drop old6, force
    tempfile map82
    save `map82'
restore

preserve
    keep region1990 county_curr6
    drop if missing(region1990)
    gen str6 old6 = string(region1990, "%06.0f")
    keep old6 county_curr6
    duplicates drop old6, force
    tempfile map90
    save `map90'
restore

keep region2000 county_curr6
drop if missing(region2000)
gen str6 old6 = string(region2000, "%06.0f")
keep old6 county_curr6
duplicates drop old6, force
tempfile map00
save `map00'

* treatment and controls
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
duplicates drop countyid_curr6, force
tempfile treat
save `treat'

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64
duplicates drop countyid_curr6, force
tempfile ctrls
save `ctrls'

capture program drop _build_mid_panel
program define _build_mid_panel
    syntax , WAVE(integer) HI(integer)

    if `wave'==1982 {
        use region1982 year_birth yedu using "${proj}/data/raw/census_1982_clean.dta", clear
        drop if missing(region1982) | missing(year_birth) | missing(yedu)
        gen str6 old6 = string(region1982, "%06.0f")
        merge m:1 old6 using `map82', keep(master match) nogen
    }

    if `wave'==1990 {
        use region1990 year_birth yedu using "${proj}/data/raw/census_1990_clean.dta", clear
        drop if missing(region1990) | missing(year_birth) | missing(yedu)
        gen str6 old6 = string(region1990, "%06.0f")
        merge m:1 old6 using `map90', keep(master match) nogen
    }

    if `wave'==2000 {
        use region2000 year_birth yedu using "${proj}/data/raw/census_2000_clean.dta", clear
        drop if missing(region2000) | missing(year_birth) | missing(yedu)
        gen str6 old6 = string(region2000, "%06.0f")
        merge m:1 old6 using `map00', keep(master match) nogen
    }

    rename county_curr6 countyid_curr6
    keep if countyid_curr6!="" & countyid_curr6!="000000"

    keep if inrange(year_birth, 1920, `hi')
    drop if floor(year_birth)==1939
    keep if inrange(yedu,0,25)

    gen birth_i = floor(year_birth)
    gen mid = (yedu>=9)

    collapse (mean) mid_comp=mid (count) n_obs=mid, by(countyid_curr6 birth_i)

    merge m:1 countyid_curr6 using `treat', keep(master match) nogen
    merge m:1 countyid_curr6 using `ctrls', keep(master match) nogen
    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
        replace `v' = 0 if missing(`v')
    }

    gen post = birth_i>=1940
    egen county_num = group(countyid_curr6)
end

eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str14 spec = ""
gen b = .
gen se = .
gen p = .
gen n_cells = .
gen n_counties = .
save `summary', replace

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978

    quietly _build_mid_panel, wave(`w') hi(`hi')

    quietly count
    local n_cells = r(N)
    egen __tagc = tag(county_num)
    quietly count if __tagc==1
    local n_counties = r(N)
    drop __tagc

    quietly reghdfejl mid_comp c.ln_martyr_per100k_1953##ib0.post, absorb(county_num birth_i) vce(cluster county_num)
    estimates store y`w'_u1
    estadd local Weighted "N"
    estadd local AER_Post "N"
    estadd scalar N_counties = `n_counties'
    local b1 = _b[1.post#c.ln_martyr_per100k_1953]
    local se1 = _se[1.post#c.ln_martyr_per100k_1953]
    local p1 = 2*ttail(e(df_r), abs(`b1'/`se1'))

    quietly reghdfejl mid_comp c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post, ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store y`w'_u2
    estadd local Weighted "N"
    estadd local AER_Post "Y"
    estadd scalar N_counties = `n_counties'
    local b2 = _b[1.post#c.ln_martyr_per100k_1953]
    local se2 = _se[1.post#c.ln_martyr_per100k_1953]
    local p2 = 2*ttail(e(df_r), abs(`b2'/`se2'))

    quietly reghdfejl mid_comp c.ln_martyr_per100k_1953##ib0.post [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store y`w'_w1
    estadd local Weighted "Y"
    estadd local AER_Post "N"
    estadd scalar N_counties = `n_counties'
    local b3 = _b[1.post#c.ln_martyr_per100k_1953]
    local se3 = _se[1.post#c.ln_martyr_per100k_1953]
    local p3 = 2*ttail(e(df_r), abs(`b3'/`se3'))

    quietly reghdfejl mid_comp c.ln_martyr_per100k_1953##ib0.post ///
        c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post ///
        [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store y`w'_w2
    estadd local Weighted "Y"
    estadd local AER_Post "Y"
    estadd scalar N_counties = `n_counties'
    local b4 = _b[1.post#c.ln_martyr_per100k_1953]
    local se4 = _se[1.post#c.ln_martyr_per100k_1953]
    local p4 = 2*ttail(e(df_r), abs(`b4'/`se4'))

    use `summary', clear
    local n = _N + 1
    set obs `=`n'+3'
    replace wave = "`w'" in `n'
    replace spec = "U1 baseline" in `n'
    replace b = `b1' in `n'
    replace se = `se1' in `n'
    replace p = `p1' in `n'
    replace n_cells = `n_cells' in `n'
    replace n_counties = `n_counties' in `n'

    replace wave = "`w'" in `=`n'+1'
    replace spec = "U2 + AER" in `=`n'+1'
    replace b = `b2' in `=`n'+1'
    replace se = `se2' in `=`n'+1'
    replace p = `p2' in `=`n'+1'
    replace n_cells = `n_cells' in `=`n'+1'
    replace n_counties = `n_counties' in `=`n'+1'

    replace wave = "`w'" in `=`n'+2'
    replace spec = "W1 baseline" in `=`n'+2'
    replace b = `b3' in `=`n'+2'
    replace se = `se3' in `=`n'+2'
    replace p = `p3' in `=`n'+2'
    replace n_cells = `n_cells' in `=`n'+2'
    replace n_counties = `n_counties' in `=`n'+2'

    replace wave = "`w'" in `=`n'+3'
    replace spec = "W2 + AER" in `=`n'+3'
    replace b = `b4' in `=`n'+3'
    replace se = `se4' in `=`n'+3'
    replace p = `p4' in `=`n'+3'
    replace n_cells = `n_cells' in `=`n'+3'
    replace n_counties = `n_counties' in `=`n'+3'
    save `summary', replace
}

use `summary', clear
gen t_abs = abs(b/se)
export delimited using "${proj}/result/table/y_midcompletion_cleanpanel_compare_summary_v2.csv", replace
save "${proj}/result/table/y_midcompletion_cleanpanel_compare_summary_v2.dta", replace

esttab y1982_u1 y1982_u2 y1982_w1 y1982_w2 ///
       y1990_u1 y1990_u2 y1990_w1 y1990_w2 ///
       y2000_u1 y2000_u2 y2000_w1 y2000_w2 using "${proj}/result/table/y_midcompletion_cleanpanel_compare_v2.rtf", ///
       replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Weighted AER_Post N_counties) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab y1982_u1 y1982_u2 y1982_w1 y1982_w2 ///
       y1990_u1 y1990_u2 y1990_w1 y1990_w2 ///
       y2000_u1 y2000_u2 y2000_w1 y2000_w2 using "${proj}/result/table/y_midcompletion_cleanpanel_compare_v2.tex", ///
       replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Weighted AER_Post N_counties) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
