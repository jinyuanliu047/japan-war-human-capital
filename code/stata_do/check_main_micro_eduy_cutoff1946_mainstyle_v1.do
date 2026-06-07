*******************************************************
* Main education regressions, cutoff 1946
* Micro-equivalent weighted county-birth-minority cells
* Treat starts in 1946, drop 1945
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/county_controls_full_v1.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

global hist_controls_all "c.sdy_density#c.post c.ins_famine#c.post c.ln_victims_cr#c.post c.ln_grain_output#c.post c.urbanratio64#c.post"

use "${proj}/data/temp/county_controls_full_v1.dta", clear
keep countyid_curr6 sdy_density ins_famine victims_cr grain_output urbanratio64
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
drop if county_curr6=="" | county_curr6=="000000"
duplicates drop county_curr6, force
foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
    replace `v' = 0 if missing(`v')
}
gen ln_victims_cr = ln(victims_cr + 1)
gen ln_grain_output = ln(grain_output + 1)
tempfile histctrl
save `histctrl'

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 ln_martyr_per100k_1953
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
drop if county_curr6=="" | county_curr6=="000000"
duplicates drop county_curr6, force
tempfile treat
save `treat'

capture program drop _run_wave
program define _run_wave
    syntax , WAVE(integer) PANEL(string) LO(integer) HI(integer) DROPYEAR(integer) BASEMODEL(name) FULLMODEL(name) TREATFILE(string) HISTFILE(string)

    import delimited "`panel'", clear varnames(1) stringcols(1)
    keep if inrange(birth_i, `lo', `hi')
    drop if birth_i == `dropyear'
    merge m:1 county_curr6 using "`treatfile'", keep(master match) nogen
    merge m:1 county_curr6 using "`histfile'", keep(master match) nogen
    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 ln_victims_cr ln_grain_output {
        replace `v' = 0 if missing(`v')
    }
    gen post = birth_i >= 1946
    egen county_num = group(county_curr6)

    reghdfe eduy_mean c.ln_martyr_per100k_1953##i.post minority [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store `basemodel'
    estadd local Controls "Y"
    estadd local Hist_Control "None"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "1946"
    estadd local Weight "Cell size"

    reghdfe eduy_mean c.ln_martyr_per100k_1953##i.post minority $hist_controls_all [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store `fullmodel'
    estadd local Controls "Y"
    estadd local Hist_Control "All five"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Cutoff "1946"
    estadd local Weight "Cell size"
end

_run_wave, wave(1982) panel("${proj}/data/temp/micro_equiv_panel_1982_v1.csv") lo(1920) hi(1960) dropyear(1945) basemodel(model1) fullmodel(model2) treatfile("`treat'") histfile("`histctrl'")
_run_wave, wave(1990) panel("${proj}/data/temp/micro_equiv_panel_1990_v1.csv") lo(1920) hi(1968) dropyear(1945) basemodel(model3) fullmodel(model4) treatfile("`treat'") histfile("`histctrl'")
_run_wave, wave(2000) panel("${proj}/data/temp/micro_equiv_panel_2000_v1.csv") lo(1920) hi(1978) dropyear(1945) basemodel(model5) fullmodel(model6) treatfile("`treat'") histfile("`histctrl'")

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_micro_eduy_cutoff1946_mainstyle_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 baseline" "1982 + all five" "1990 baseline" "1990 + all five" "2000 baseline" "2000 + all five") ///
    stats(Controls Hist_Control County_FE Cohort_FE Weight Cutoff N r2 ar2, ///
        labels("Individual controls" "County history control" "County FE" "Cohort FE" "Weights" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 model6 using "${proj}/result/table/main_micro_eduy_cutoff1946_mainstyle_v1.tex", ///
    replace booktabs nonotes keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("1982 baseline" "1982 + all five" "1990 baseline" "1990 + all five" "2000 baseline" "2000 + all five") ///
    stats(Controls Hist_Control County_FE Cohort_FE Weight Cutoff N r2 ar2, ///
        labels("Individual controls" "County history control" "County FE" "Cohort FE" "Weights" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' str4 wave str12 spec double b se p N using "${proj}/result/table/main_micro_eduy_cutoff1946_mainstyle_v1_tmp.dta", replace
foreach i in 1 2 3 4 5 6 {
    estimates restore model`i'
    local wave = cond(`i'<=2,"1982",cond(`i'<=4,"1990","2000"))
    local spec = cond(mod(`i',2)==1,"baseline","all_five")
    post `memhold' ("`wave'") ("`spec'") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N))
}
postclose `memhold'
use "${proj}/result/table/main_micro_eduy_cutoff1946_mainstyle_v1_tmp.dta", clear
export delimited using "${proj}/result/table/main_micro_eduy_cutoff1946_mainstyle_v1.csv", replace
erase "${proj}/result/table/main_micro_eduy_cutoff1946_mainstyle_v1_tmp.dta"
exit, clear
