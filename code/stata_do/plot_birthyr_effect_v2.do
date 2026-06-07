*******************************************************
* Plot cohort-varying treatment slope by birth year
* Data: did_1982_county_birthyr_martyr_native_v2.dta
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

use "${proj}/data/temp/did_1982_county_birthyr_martyr_native_v2.dta", clear

* Keep baseline DID window for interpretable cohort dynamics
keep if sample_schoolage_did == 1

* Optional quality filter (kept for robustness; after strict-only mapping this is usually all rows)
keep if strict_share_wt >= 0.8

local baseyr 1930

* County FE + birth-year dummies (via i.birthyr) with year-varying treatment slope
reghdfe eduy_wmean ib`baseyr'.birthyr##c.ln_martyr_native_count [aw=wt_sum], ///
    absorb(countyid_curr6) vce(cluster countyid_curr6)

tempfile birthyrcoef
tempname posth
postfile `posth' int birthyr double beta se lb ub using "`birthyrcoef'", replace

levelsof birthyr, local(years)

foreach y of local years {
    if `y' == `baseyr' {
        quietly lincom _b[c.ln_martyr_native_count]
    }
    else {
        quietly lincom _b[c.ln_martyr_native_count] + _b[`y'.birthyr#c.ln_martyr_native_count]
    }
    post `posth' (`y') (r(estimate)) (r(se)) (r(estimate)-1.96*r(se)) (r(estimate)+1.96*r(se))
}

postclose `posth'
use "`birthyrcoef'", clear
sort birthyr

label var beta "Marginal effect of ln(1+martyrs) on eduy"
label var birthyr "Birth year"

export delimited using "${proj}/data/temp/birthyr_effect_ln_martyr_v2.csv", replace
save "${proj}/data/temp/birthyr_effect_ln_martyr_v2.dta", replace

twoway ///
    (rarea ub lb birthyr, color(navy%14) lcolor(none)) ///
    (line beta birthyr, lcolor(navy) lwidth(medthick)), ///
    yline(0, lcolor(gs8) lpattern(dash)) ///
    xline(1931 1937 1945, lcolor(maroon) lpattern(shortdash)) ///
    xtitle("Birth year") ///
    ytitle("Effect of ln(1+martyr native count) on eduy") ///
    title("Cohort-varying treatment slope", size(medsmall)) ///
    subtitle("95% CI shaded; county FE, clustered by county", size(small)) ///
    legend(off) ///
    graphregion(color(white))

graph export "${proj}/result/figure/birthyr_effect_ln_martyr_v2.png", replace width(2400)
