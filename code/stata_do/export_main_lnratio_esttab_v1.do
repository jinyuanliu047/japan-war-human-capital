*******************************************************
* Re-estimate main DID (ln(1+ratio)) and export esttab RTF
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 {
    ssc install estout, replace
}

eststo clear

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'" == "1990" local hi = 1968
    if "`w'" == "2000" local hi = 1978

    use "${proj}/data/temp/did_`w'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr, 1920, `hi')
    drop if floor(birthyr) == 1939
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="000000"

    gen birth_i = floor(birthyr)
    egen county_num = group(countyid_curr6)
    gen post = birth_i >= 1940

    quietly count
    local n_cells = r(N)
    egen tag_county = tag(county_num)
    quietly count if tag_county==1
    local n_counties = r(N)
    drop tag_county

    quietly areg eduy_mean c.ln_martyr_per100k_1953##ib0.post i.birth_i, ///
        absorb(county_num) vce(cluster county_num)

    eststo m`w'
    estadd local county_fe "Yes"
    estadd local cohort_fe "Yes"
    estadd local se_cluster "County"
    estadd local drop1939 "Yes"
    estadd scalar n_cells = `n_cells'
    estadd scalar n_counties = `n_counties'
}

esttab m1982 m1990 m2000 using "${proj}/result/table/main_regression_lnratio_esttab_v1.rtf", replace ///
    mtitles("Census 1982" "Census 1990" "Census 2000") ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post x ln(1+martyrs per 100k)") ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    compress label nonumbers ///
    stats(county_fe cohort_fe se_cluster drop1939 n_cells n_counties N r2_a, ///
          labels("County FE" "Birth-year FE" "SE cluster" "Drop 1939 cohort" "Cell observations" "Counties" "N (estimation)" "Adj. R2"))

exit, clear
