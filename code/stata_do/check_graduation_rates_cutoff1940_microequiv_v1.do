*******************************************************
* Graduation-rate regressions by wave
* Micro-equivalent county-birth-minority cells
* Treat starts in 1940, drop 1939
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

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

capture program drop _run_wave_grad
program define _run_wave_grad
    syntax , PANEL(string) LO(integer) HI(integer) DROPYEAR(integer) OUTFILE(string) TREATFILE(string) HISTFILE(string)
    import delimited "`panel'", clear varnames(1) stringcols(1)
    keep if inrange(birth_i, `lo', `hi')
    drop if birth_i == `dropyear'
    collapse (sum) n_obs eduy_sum (mean) eduy_mean primary_comp junior_comp college_comp, by(county_curr6 birth_i)
    merge m:1 county_curr6 using "`treatfile'", keep(master match) nogen
    merge m:1 county_curr6 using "`histfile'", keep(master match) nogen
    foreach v in sdy_density ins_famine victims_cr grain_output urbanratio64 {
        replace `v' = 0 if missing(`v')
    }
    gen post = birth_i >= 1940
    egen county_num = group(county_curr6)

    reghdfe primary_comp c.ln_martyr_per100k_1953##i.post [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m1
    estadd local Hist_Control "None"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Weight "Cell size"
    estadd local Cutoff "1940"
    reghdfe primary_comp c.ln_martyr_per100k_1953##i.post $hist_controls_all [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m2
    estadd local Hist_Control "All five"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Weight "Cell size"
    estadd local Cutoff "1940"

    reghdfe junior_comp c.ln_martyr_per100k_1953##i.post [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m3
    estadd local Hist_Control "None"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Weight "Cell size"
    estadd local Cutoff "1940"
    reghdfe junior_comp c.ln_martyr_per100k_1953##i.post $hist_controls_all [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m4
    estadd local Hist_Control "All five"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Weight "Cell size"
    estadd local Cutoff "1940"

    reghdfe college_comp c.ln_martyr_per100k_1953##i.post [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m5
    estadd local Hist_Control "None"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Weight "Cell size"
    estadd local Cutoff "1940"
    reghdfe college_comp c.ln_martyr_per100k_1953##i.post $hist_controls_all [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    estimates store m6
    estadd local Hist_Control "All five"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd local Weight "Cell size"
    estadd local Cutoff "1940"

    esttab m1 m2 m3 m4 m5 m6 using "`outfile'.rtf", replace keep(1.post#c.ln_martyr_per100k_1953) coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") mtitles("Primary baseline" "Primary + all five" "Junior baseline" "Junior + all five" "College baseline" "College + all five") stats(Hist_Control County_FE Cohort_FE Weight Cutoff N r2 ar2, labels("County history control" "County FE" "Cohort FE" "Weights" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) se star(* 0.1 ** 0.05 *** 0.01)
    esttab m1 m2 m3 m4 m5 m6 using "`outfile'.tex", replace keep(1.post#c.ln_martyr_per100k_1953) coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") mtitles("Primary baseline" "Primary + all five" "Junior baseline" "Junior + all five" "College baseline" "College + all five") stats(Hist_Control County_FE Cohort_FE Weight Cutoff N r2 ar2, labels("County history control" "County FE" "Cohort FE" "Weights" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) se star(* 0.1 ** 0.05 *** 0.01)

    tempfile tmp
    tempname memhold
    postfile `memhold' str12 outcome str12 spec double b se p N using `tmp', replace
    foreach specid in 1 2 3 4 5 6 {
        estimates restore m`specid'
        local outcome = cond(`specid'<=2,"primary",cond(`specid'<=4,"junior","college"))
        local spec = cond(mod(`specid',2)==1,"baseline","all_five")
        post `memhold' ("`outcome'") ("`spec'") (_b[1.post#c.ln_martyr_per100k_1953]) (_se[1.post#c.ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953]/_se[1.post#c.ln_martyr_per100k_1953]))) (e(N))
    }
    postclose `memhold'
    use `tmp', clear
    export delimited using "`outfile'.csv", replace
end

_run_wave_grad, panel("${proj}/data/temp/micro_equiv_panel_1982_v1.csv") lo(1920) hi(1960) dropyear(1939) outfile("${proj}/result/table/graduation_rates_1982_cutoff1940_microequiv_v1") treatfile("`treat'") histfile("`histctrl'")
_run_wave_grad, panel("${proj}/data/temp/micro_equiv_panel_1990_v1.csv") lo(1920) hi(1968) dropyear(1939) outfile("${proj}/result/table/graduation_rates_1990_cutoff1940_microequiv_v1") treatfile("`treat'") histfile("`histctrl'")
_run_wave_grad, panel("${proj}/data/temp/micro_equiv_panel_2000_v1.csv") lo(1920) hi(1978) dropyear(1939) outfile("${proj}/result/table/graduation_rates_2000_cutoff1940_microequiv_v1") treatfile("`treat'") histfile("`histctrl'")
exit, clear
