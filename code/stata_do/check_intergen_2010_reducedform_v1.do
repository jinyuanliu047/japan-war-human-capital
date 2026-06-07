* intergen_2010_reducedform_v1

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/raw/census_2010_clean.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace

use "${proj}/data/raw/census_2010_clean.dta", clear

* Keep cohorts old enough to have largely completed schooling by 2010.
keep if year_birth <= 1988
keep if !missing(yedu, region2010, year_birth, treat_p, sdy_density, male, han_ethn)

gen primary_comp = yedu >= 6 if !missing(yedu)
gen junior_high_comp = yedu >= 9 if !missing(yedu)
gen senior_high_comp = yedu >= 12 if !missing(yedu)
gen college_comp = yedu >= 15 if !missing(yedu)

label var yedu "Years of education"
label var primary_comp "Primary completion"
label var junior_high_comp "Junior high completion"
label var senior_high_comp "Senior high completion"
label var college_comp "College completion"

tempname memhold
postfile `memhold' str24 outcome double coef se pval N using ///
    "${proj}/result/table/intergen_2010_reducedform_summary_v1.dta", replace

reghdfejl yedu c.sdy_density##i.treat_p male han_ethn, ///
    absorb(region2010 year_birth) vce(cluster region2010)
estimates store model1
estadd local Sample "Born <= 1988"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Controls "Y"
local b = _b[1.treat_p#c.sdy_density]
local se = _se[1.treat_p#c.sdy_density]
local p = 2*ttail(e(df_r), abs(`b'/`se'))
post `memhold' ("yedu") (`b') (`se') (`p') (e(N))

reghdfejl primary_comp c.sdy_density##i.treat_p male han_ethn, ///
    absorb(region2010 year_birth) vce(cluster region2010)
estimates store model2
estadd local Sample "Born <= 1988"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Controls "Y"
local b = _b[1.treat_p#c.sdy_density]
local se = _se[1.treat_p#c.sdy_density]
local p = 2*ttail(e(df_r), abs(`b'/`se'))
post `memhold' ("primary_comp") (`b') (`se') (`p') (e(N))

reghdfejl junior_high_comp c.sdy_density##i.treat_p male han_ethn, ///
    absorb(region2010 year_birth) vce(cluster region2010)
estimates store model3
estadd local Sample "Born <= 1988"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Controls "Y"
local b = _b[1.treat_p#c.sdy_density]
local se = _se[1.treat_p#c.sdy_density]
local p = 2*ttail(e(df_r), abs(`b'/`se'))
post `memhold' ("junior_high_comp") (`b') (`se') (`p') (e(N))

reghdfejl senior_high_comp c.sdy_density##i.treat_p male han_ethn, ///
    absorb(region2010 year_birth) vce(cluster region2010)
estimates store model4
estadd local Sample "Born <= 1988"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Controls "Y"
local b = _b[1.treat_p#c.sdy_density]
local se = _se[1.treat_p#c.sdy_density]
local p = 2*ttail(e(df_r), abs(`b'/`se'))
post `memhold' ("senior_high_comp") (`b') (`se') (`p') (e(N))

reghdfejl college_comp c.sdy_density##i.treat_p male han_ethn, ///
    absorb(region2010 year_birth) vce(cluster region2010)
estimates store model5
estadd local Sample "Born <= 1988"
estadd local County_FE "Y"
estadd local Cohort_FE "Y"
estadd local Controls "Y"
local b = _b[1.treat_p#c.sdy_density]
local se = _se[1.treat_p#c.sdy_density]
local p = 2*ttail(e(df_r), abs(`b'/`se'))
post `memhold' ("college_comp") (`b') (`se') (`p') (e(N))

postclose `memhold'

use "${proj}/result/table/intergen_2010_reducedform_summary_v1.dta", clear
export delimited using "${proj}/result/table/intergen_2010_reducedform_summary_v1.csv", replace

esttab model1 model2 model3 model4 model5 using ///
    "${proj}/result/table/intergen_2010_reducedform_v1.rtf", ///
    replace ///
    keep(1.treat_p#c.sdy_density) ///
    coeflabels(1.treat_p#c.sdy_density "War exposure × Parent treated") ///
    mtitles("Yedu" "Primary" "Junior high" "Senior high" "College") ///
    scalars(Sample County_FE Cohort_FE Controls) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 model5 using ///
    "${proj}/result/table/intergen_2010_reducedform_v1.tex", ///
    replace ///
    booktabs ///
    nonotes ///
    keep(1.treat_p#c.sdy_density) ///
    coeflabels(1.treat_p#c.sdy_density "War exposure $\\times$ Parent treated") ///
    mtitles("Yedu" "Primary" "Junior high" "Senior high" "College") ///
    scalars(Sample County_FE Cohort_FE Controls) ///
    se r2 ar2 ///
    star(* 0.1 ** 0.05 *** 0.01)

exit, clear
