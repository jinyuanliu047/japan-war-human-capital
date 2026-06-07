*******************************************************
* Compare weighted vs unweighted in main spec
* Y: county-birth eduy_mean
* FE: county + birth-year
* Weight option: [aw=n_obs]
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

eststo clear

tempfile summary
clear
set obs 0
gen str6 wave = ""
gen str12 spec = ""
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

    use "${proj}/data/temp/did_`w'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr,1920,`hi')
    drop if floor(birthyr)==1939
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="" | countyid_curr6=="000000"

    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)

    quietly count
    local n_cells = r(N)
    egen __tagc = tag(county_num)
    quietly count if __tagc==1
    local n_counties = r(N)
    drop __tagc

    // unweighted
    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post, absorb(county_num birth_i) vce(cluster county_num)
    estimates store uw`w'
    estadd local Weighted "N"
    estadd scalar N_counties = `n_counties'

    local b1 = _b[1.post#c.ln_martyr_per100k_1953]
    local se1 = _se[1.post#c.ln_martyr_per100k_1953]
    local p1 = 2*ttail(e(df_r), abs(`b1'/`se1'))

    // weighted by cell size
    quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store wt`w'
    estadd local Weighted "Y"
    estadd scalar N_counties = `n_counties'

    local b2 = _b[1.post#c.ln_martyr_per100k_1953]
    local se2 = _se[1.post#c.ln_martyr_per100k_1953]
    local p2 = 2*ttail(e(df_r), abs(`b2'/`se2'))

    use `summary', clear
    local n = _N + 1
    set obs `=`n'+1'
    replace wave = "`w'" in `n'
    replace spec = "unweighted" in `n'
    replace b = `b1' in `n'
    replace se = `se1' in `n'
    replace p = `p1' in `n'
    replace n_cells = `n_cells' in `n'
    replace n_counties = `n_counties' in `n'

    replace wave = "`w'" in `=`n'+1'
    replace spec = "weighted" in `=`n'+1'
    replace b = `b2' in `=`n'+1'
    replace se = `se2' in `=`n'+1'
    replace p = `p2' in `=`n'+1'
    replace n_cells = `n_cells' in `=`n'+1'
    replace n_counties = `n_counties' in `=`n'+1'
    save `summary', replace
}

use `summary', clear
gen t_abs = abs(b/se)
export delimited using "${proj}/result/table/main_weighted_unweighted_compare_summary_v1.csv", replace
save "${proj}/result/table/main_weighted_unweighted_compare_summary_v1.dta", replace

esttab uw1982 wt1982 uw1990 wt1990 uw2000 wt2000 using "${proj}/result/table/main_weighted_unweighted_compare_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Weighted N_counties) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab uw1982 wt1982 uw1990 wt1990 uw2000 wt2000 using "${proj}/result/table/main_weighted_unweighted_compare_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) scalar(Weighted N_counties) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
