/*  ================================================================
    Pooled sample: figures + revised tables
    1. Cohort-level education means by treatment (figure data)
    2. Cohort size by treatment (figure data)
    3. Treatment distribution (figure data)
    4. Revised suggestive evidence tables (paper style)
    5. Revised summary statistics table (paper style)
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")
global outdir "${proj}/paper/assets/tables"
global figdir "${proj}/paper/assets/figures"
capture mkdir "${figdir}"

*--------------------------------------------------------------
* county dictionary + crosswalk
*--------------------------------------------------------------
import excel "${proj}/data/raw/China_Map/County0010.xlsx", sheet("County0010") firstrow clear
keep GBCounty
destring GBCounty, replace force
drop if missing(GBCounty)
gen str6 county_curr6 = string(GBCounty, "%06.0f")
gen str6 old6 = county_curr6
gen str6 curr_dict = county_curr6
keep old6 curr_dict
duplicates drop old6, force
tempfile county_dict
save `county_dict'
global county_dict_tmp "`county_dict'"

import delimited "${proj}/data/temp/countyid_1982_to_current_crosswalk_v2.csv", clear varnames(1) stringcols(_all)
rename countyid_old6 old6
rename countyid_curr6_final county_curr6
replace old6 = substr("000000" + old6, strlen("000000" + old6)-5, 6)
replace county_curr6 = subinstr(county_curr6, ".0", "", .)
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
keep old6 county_curr6 route_final
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'
global cw1982_tmp "`cw1982'"

capture program drop _resolve_old6_map
program define _resolve_old6_map
    gen str6 county_curr6 = ""
    gen str30 route = "unmatched"
    replace county_curr6 = "310101" if old6=="310103"
    replace route = "manual_successor" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace route = "manual_successor" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace route = "manual_successor" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"
    replace route = "manual_successor" if old6=="110010"
    tempfile left
    save `left'
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6 route_final)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    replace route = "crosswalk_1982" if county_curr6!="" & route=="unmatched"
    drop county_curr6 route_final
    rename curr_res county_curr6
    save `left', replace
    use `left', clear
    rename county_curr6 curr_res
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace curr_res = curr_dict if curr_res=="" & curr_dict!=""
    replace route = "exact_code" if curr_dict!="" & route=="unmatched"
    drop curr_dict
    rename curr_res county_curr6
    gen str6 muni6 = substr(old6,1,2) + "01" + substr(old6,5,2) ///
        if inlist(substr(old6,1,2),"11","12","31") & substr(old6,3,2)=="00" & county_curr6==""
    tempfile muni_exact
    tempfile muni_cw
    preserve
        keep old6
        keep if 0
        gen str6 curr_from_muni_exact = ""
        save `muni_exact', replace
    restore
    preserve
        keep old6
        keep if 0
        gen str6 curr_from_muni_cw = ""
        save `muni_cw', replace
    restore
    preserve
        keep if muni6!="" & county_curr6==""
        count
        if r(N)>0 {
            keep old6 muni6
            rename muni6 old6_muni
            rename old6 old6_orig
            rename old6_muni old6
            merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
            keep if curr_dict!=""
            drop old6
            rename old6_orig old6
            rename curr_dict curr_from_muni_exact
            keep old6 curr_from_muni_exact
            save `muni_exact', replace
        }
    restore
    merge 1:1 old6 using `muni_exact', keep(master match) nogen
    replace county_curr6 = curr_from_muni_exact if county_curr6=="" & curr_from_muni_exact!=""
    replace route = "municipality_geo3_recode" if county_curr6==curr_from_muni_exact & curr_from_muni_exact!=""
    drop curr_from_muni_exact
    preserve
        keep if muni6!="" & county_curr6==""
        count
        if r(N)>0 {
            keep old6 muni6
            rename muni6 old6_muni
            rename old6 old6_orig
            rename old6_muni old6
            merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
            keep if county_curr6!=""
            drop old6
            rename old6_orig old6
            rename county_curr6 curr_from_muni_cw
            keep old6 curr_from_muni_cw
            save `muni_cw', replace
        }
    restore
    merge 1:1 old6 using `muni_cw', keep(master match) nogen
    replace county_curr6 = curr_from_muni_cw if county_curr6=="" & curr_from_muni_cw!=""
    replace route = "municipality_then_crosswalk_1982" if county_curr6==curr_from_muni_cw & curr_from_muni_cw!=""
    drop curr_from_muni_cw muni6
end

*--------------------------------------------------------------
* treatment
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw pop_1953

gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)

summ martyr_count, detail
local median_count = r(p50)
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)

rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
tempfile treat
save `treat'
global treat_tmp "`treat'"

di "Median martyr count = `median_count'"

*--------------------------------------------------------------
* mapping 1990/2000
*--------------------------------------------------------------
use county age_c age educ using "$c1990", clear
drop if missing(county)
gen str6 old6 = string(county, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map1990
save `map1990'
global map1990_tmp "`map1990'"

use uid birthyr eduyr using "$c2000", clear
drop if missing(uid)
gen str6 old6 = string(uid, "%06.0f")
keep old6
duplicates drop old6, force
_resolve_old6_map
keep old6 county_curr6
drop if county_curr6==""
tempfile map2000
save `map2000'
global map2000_tmp "`map2000'"

*==============================================================
*  Load each wave
*==============================================================
use countyid birthyr eduy ethniccn using "$c1982", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen minority = (ethniccn != 1) if !missing(ethniccn)
keep if inrange(birthyr, 1920, 1956)
rename county_curr6 countyid_curr6
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen wave = 1
tempfile w1982
save `w1982'

use county age_c age educ race using "$c1990", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birthyr = 1000 + age_c*100 + age
gen eduy = .
replace eduy = 0  if educ==1
replace eduy = 6  if educ==2
replace eduy = 9  if educ==3
replace eduy = 12 if inlist(educ,4,5)
replace eduy = 15 if educ==6
replace eduy = 16 if educ==7
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen wave = 2
tempfile w1990
save `w1990'

use uid birthyr eduyr race using "$c2000", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen wave = 3
tempfile w2000
save `w2000'

*==============================================================
*  Pool & winsorize
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'

summ eduy, detail
scalar p1 = r(p1)
scalar p99 = r(p99)
replace eduy = p1 if eduy < p1
replace eduy = p99 if eduy > p99 & !missing(eduy)

di "=== POOLED SAMPLE ==="
di "N = " _N

*==============================================================
*  Figure 1: Mean education by birth cohort × treatment
*==============================================================
preserve
    collapse (mean) mean_edu = eduy (count) n = eduy, by(birthyr d_count_high)

    /* reshape wide for plotting */
    reshape wide mean_edu n, i(birthyr) j(d_count_high)

    twoway (connected mean_edu0 birthyr, msymbol(circle) msize(small) lcolor(navy) mcolor(navy) lpattern(solid)) ///
           (connected mean_edu1 birthyr, msymbol(triangle) msize(small) lcolor(cranberry) mcolor(cranberry) lpattern(dash)), ///
           xline(1940, lcolor(gs8) lpattern(dash)) ///
           xline(1946, lcolor(gs8) lpattern(shortdash)) ///
           xtitle("Birth Year") ytitle("Mean Years of Education") ///
           legend(order(1 "Control (count {&le} 12)" 2 "Treatment (count > 12)") rows(1) position(6) size(small)) ///
           xlabel(1920(5)1955, labsize(small)) ylabel(, labsize(small)) ///
           graphregion(color(white)) plotregion(color(white)) ///
           text(2.5 1940 "1940", size(vsmall) color(gs6)) ///
           text(2.2 1946 "1946", size(vsmall) color(gs6)) ///
           scheme(s2color)
    graph export "${figdir}/cohort_education_by_treatment.pdf", replace
restore

*==============================================================
*  Figure 2: Cohort size by birth year × treatment
*==============================================================
preserve
    collapse (count) n = eduy, by(birthyr d_count_high)
    reshape wide n, i(birthyr) j(d_count_high)
    replace n0 = n0 / 1000
    replace n1 = n1 / 1000

    twoway (bar n0 birthyr, barwidth(0.4) color(navy%60) fintensity(60)) ///
           (bar n1 birthyr, barwidth(0.4) color(cranberry%60) fintensity(60)), ///
           xline(1940, lcolor(gs8) lpattern(dash)) ///
           xline(1946, lcolor(gs8) lpattern(shortdash)) ///
           xtitle("Birth Year") ytitle("Number of Individuals (thousands)") ///
           legend(order(1 "Control (count {&le} 12)" 2 "Treatment (count > 12)") rows(1) position(6) size(small)) ///
           xlabel(1920(5)1955, labsize(small)) ylabel(, labsize(small)) ///
           graphregion(color(white)) plotregion(color(white)) ///
           scheme(s2color)
    graph export "${figdir}/cohort_size_by_treatment.pdf", replace
restore

*==============================================================
*  Figure 3: Education gap (treatment - control) by cohort
*==============================================================
preserve
    collapse (mean) mean_edu = eduy, by(birthyr d_count_high)
    reshape wide mean_edu, i(birthyr) j(d_count_high)
    gen gap = mean_edu1 - mean_edu0

    twoway (connected gap birthyr, msymbol(circle) msize(small) lcolor(dkorange) mcolor(dkorange)) ///
           (lfit gap birthyr if birthyr < 1940, lcolor(navy) lpattern(dash) range(1920 1939)) ///
           (lfit gap birthyr if birthyr >= 1940, lcolor(cranberry) lpattern(dash) range(1940 1956)), ///
           yline(0, lcolor(gs10) lpattern(solid)) ///
           xline(1940, lcolor(gs8) lpattern(dash)) ///
           xline(1946, lcolor(gs8) lpattern(shortdash)) ///
           xtitle("Birth Year") ytitle("Education Gap (Treatment {&minus} Control)") ///
           legend(order(1 "Gap" 2 "Pre-1940 trend" 3 "Post-1940 trend") rows(1) position(6) size(small)) ///
           xlabel(1920(5)1955, labsize(small)) ylabel(, labsize(small)) ///
           graphregion(color(white)) plotregion(color(white)) ///
           text(-0.35 1940 "1940", size(vsmall) color(gs6)) ///
           text(-0.40 1946 "1946", size(vsmall) color(gs6)) ///
           scheme(s2color)
    graph export "${figdir}/cohort_edugap_by_year.pdf", replace
restore

*==============================================================
*  Figure 4: Treatment distribution
*==============================================================
preserve
    collapse (first) martyr_count, by(countyid_curr6)
    summ martyr_count, detail
    local p99 = r(p99)
    gen mc_w = min(martyr_count, `p99')

    histogram mc_w, bin(50) fcolor(navy%70) lcolor(navy) ///
        xline(`median_count', lcolor(cranberry) lpattern(dash) lwidth(medium)) ///
        xtitle("Martyr Count (winsorised at p99)") ytitle("Density") ///
        graphregion(color(white)) plotregion(color(white)) ///
        text(0.003 15 "median = `median_count'", size(small) color(cranberry)) ///
        scheme(s2color)
    graph export "${figdir}/treatment_distribution.pdf", replace
restore

*==============================================================
*  Revised suggestive evidence tables (paper style)
*==============================================================

/* count counties */
preserve
    collapse (first) d_count_high, by(countyid_curr6)
    count if d_count_high == 0
    local n_county_ctrl = r(N)
    count if d_count_high == 1
    local n_county_treat = r(N)
    count
    local n_county_all = r(N)
restore

foreach cutoff in 1940 1946 {

    foreach g in 0 1 {
        summ eduy if d_count_high == `g' & birthyr < `cutoff'
        local pre_`g'  = r(mean)
        local n_pre_`g' = r(N)
        summ eduy if d_count_high == `g' & birthyr >= `cutoff'
        local post_`g' = r(mean)
        local n_post_`g' = r(N)
        count if d_count_high == `g'
        local n_`g' = r(N)
    }

    local chg_0     = `post_0'  - `pre_0'
    local chg_1     = `post_1'  - `pre_1'
    local did       = `chg_1'   - `chg_0'
    local diff_pre  = `pre_1'   - `pre_0'
    local diff_post = `post_1'  - `post_0'

    di ""
    di "=== Suggestive Evidence: Cutoff `cutoff' ==="
    di "Control  pre=" %5.3f `pre_0'  "  post=" %5.3f `post_0'  "  chg=" %5.3f `chg_0'
    di "Treat    pre=" %5.3f `pre_1'  "  post=" %5.3f `post_1'  "  chg=" %5.3f `chg_1'
    di "DiD = " %5.3f `did'

    tempname fh
    file open `fh' using "${outdir}/pooled_suggestive_evidence_`cutoff'_v1.tex", write replace

    file write `fh' "{" _n
    file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
    file write `fh' "\begin{table}[H]" _n
    file write `fh' "\centering" _n
    file write `fh' "\caption{Suggestive Evidence: Mean Years of Education (Cutoff `cutoff')}" _n
    file write `fh' "\label{tab:suggestive_`cutoff'}" _n
    file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}lccc}" _n
    file write `fh' "\toprule" _n
    file write `fh' "                    & Pre-war & Post-war & $\Delta$ (Post $-$ Pre) \\" _n
    file write `fh' "                    & (born before `cutoff') & (born `cutoff'--1956) & \\" _n
    file write `fh' "\midrule" _n
    file write `fh' "Control (count $\leq$ `median_count')  & " %8.3f (`pre_0') "  & " %8.3f (`post_0') "  & " %8.3f (`chg_0') " \\" _n
    file write `fh' "                    & [" %12.0fc (`n_pre_0') "]  & [" %12.0fc (`n_post_0') "]  & \\" _n
    file write `fh' "Treatment (count $>$ `median_count')  & " %8.3f (`pre_1') "  & " %8.3f (`post_1') "  & " %8.3f (`chg_1') " \\" _n
    file write `fh' "                    & [" %12.0fc (`n_pre_1') "]  & [" %12.0fc (`n_post_1') "]  & \\[0.3em]" _n
    file write `fh' "\midrule" _n
    file write `fh' "Difference (T $-$ C) & " %8.3f (`diff_pre') "  & " %8.3f (`diff_post') "  & \textbf{" %8.3f (`did') "} \\" _n
    file write `fh' "\midrule" _n
    file write `fh' "Observations        & " %12.0fc (`n_pre_0' + `n_pre_1') "  & " %12.0fc (`n_post_0' + `n_post_1') "  & " %12.0fc (`n_0' + `n_1') " \\" _n
    file write `fh' "Counties            & " %12.0fc (`n_county_all') "  &  & \\" _n
    file write `fh' "\bottomrule" _n
    file write `fh' "\end{tabular*}" _n
    file write `fh' "\begin{tablenotes}[flushleft]" _n
    file write `fh' "\footnotesize" _n
    file write `fh' "\item[] \textit{Notes:} Pooled individual-level data from the 1982, 1990, and 2000 Chinese population censuses. Birth cohorts 1920--1956. Years of education winsorised at the 1st and 99th percentiles. Treatment is a binary indicator equal to one if the county's total number of officially recognised war martyrs exceeds the cross-county median (`median_count'). The last column reports $\Delta_{\text{Treatment}} - \Delta_{\text{Control}}$, the raw difference-in-differences. Sample sizes in brackets." _n
    file write `fh' "\end{tablenotes}" _n
    file write `fh' "\end{table}" _n
    file write `fh' "}" _n

    file close `fh'
}

*==============================================================
*  Revised summary statistics table (paper style)
*==============================================================

/* compute stats */
summ eduy
local m_edu_all = r(mean)
local sd_edu_all = r(sd)
summ birthyr
local m_by_all = r(mean)
local sd_by_all = r(sd)
summ minority
local m_min_all = r(mean)
local sd_min_all = r(sd)
count
local n_all = r(N)

foreach g in 0 1 {
    summ eduy if d_count_high == `g'
    local m_edu_c`g' = r(mean)
    local sd_edu_c`g' = r(sd)
    summ birthyr if d_count_high == `g'
    local m_by_c`g' = r(mean)
    local sd_by_c`g' = r(sd)
    summ minority if d_count_high == `g'
    local m_min_c`g' = r(mean)
    local sd_min_c`g' = r(sd)
    count if d_count_high == `g'
    local n_c`g' = r(N)

    /* pre/post (cutoff 1940) */
    summ eduy if d_count_high == `g' & birthyr < 1940
    local m_edu_c`g'_pre = r(mean)
    summ eduy if d_count_high == `g' & birthyr >= 1940
    local m_edu_c`g'_post = r(mean)
}

/* county-level treatment means */
preserve
    collapse (first) martyr_count martyr_per100k_1953 d_count_high, by(countyid_curr6)
    foreach g in 0 1 {
        summ martyr_count if d_count_high == `g'
        local m_mc_c`g' = r(mean)
        local sd_mc_c`g' = r(sd)
        summ martyr_per100k_1953 if d_count_high == `g'
        local m_mr_c`g' = r(mean)
        local sd_mr_c`g' = r(sd)
    }
    summ martyr_count
    local m_mc_all = r(mean)
    local sd_mc_all = r(sd)
    summ martyr_per100k_1953
    local m_mr_all = r(mean)
    local sd_mr_all = r(sd)
restore

tempname fh
file open `fh' using "${outdir}/pooled_sumstats_treat_control_v1.tex", write replace

file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{table}[H]" _n
file write `fh' "\centering" _n
file write `fh' "\caption{Summary Statistics by Treatment Status}" _n
file write `fh' "\label{tab:sumstats_treat_ctrl}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{3}{cc}}" _n
file write `fh' "\toprule" _n
file write `fh' "                    &\multicolumn{2}{c}{Control}  &\multicolumn{2}{c}{Treatment}  &\multicolumn{2}{c}{Full sample}  \\" _n
file write `fh' "                    &\multicolumn{2}{c}{(count $\leq$ `median_count')}  &\multicolumn{2}{c}{(count $>$ `median_count')}  &\multicolumn{2}{c}{}  \\" _n
file write `fh' "                    &        mean&          sd&        mean&          sd&        mean&          sd\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{7}{l}{\textit{Panel A: Individual characteristics}} \\[0.3em]" _n
file write `fh' "Years of education  &" %12.3f (`m_edu_c0') "&     (" %4.3f (`sd_edu_c0') ")&" %12.3f (`m_edu_c1') "&     (" %4.3f (`sd_edu_c1') ")&" %12.3f (`m_edu_all') "&     (" %4.3f (`sd_edu_all') ")\\" _n
file write `fh' "~~Pre-war cohorts   &" %12.3f (`m_edu_c0_pre') "&            &" %12.3f (`m_edu_c1_pre') "&            &            &            \\" _n
file write `fh' "~~Post-war cohorts  &" %12.3f (`m_edu_c0_post') "&            &" %12.3f (`m_edu_c1_post') "&            &            &            \\" _n
file write `fh' "Birth year          &" %12.1f (`m_by_c0') "&     (" %4.1f (`sd_by_c0') ")&" %12.1f (`m_by_c1') "&     (" %4.1f (`sd_by_c1') ")&" %12.1f (`m_by_all') "&     (" %4.1f (`sd_by_all') ")\\" _n
file write `fh' "Minority            &" %12.3f (`m_min_c0') "&     (" %4.3f (`sd_min_c0') ")&" %12.3f (`m_min_c1') "&     (" %4.3f (`sd_min_c1') ")&" %12.3f (`m_min_all') "&     (" %4.3f (`sd_min_all') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{7}{l}{\textit{Panel B: County-level treatment (county means)}} \\[0.3em]" _n
file write `fh' "Martyr count        &" %12.1f (`m_mc_c0') "&     (" %5.1f (`sd_mc_c0') ")&" %12.1f (`m_mc_c1') "&     (" %5.1f (`sd_mc_c1') ")&" %12.1f (`m_mc_all') "&     (" %5.1f (`sd_mc_all') ")\\" _n
file write `fh' "Martyrs per 100k    &" %12.1f (`m_mr_c0') "&     (" %5.1f (`sd_mr_c0') ")&" %12.1f (`m_mr_c1') "&     (" %5.1f (`sd_mr_c1') ")&" %12.1f (`m_mr_all') "&     (" %5.1f (`sd_mr_all') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Observations        &  " %12.0fc (`n_c0') "&            &  " %12.0fc (`n_c1') "&            &  " %12.0fc (`n_all') "&            \\" _n
file write `fh' "Counties            &  " %12.0fc (`n_county_ctrl') "&            &  " %12.0fc (`n_county_treat') "&            &  " %12.0fc (`n_county_all') "&            \\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "\begin{tablenotes}[flushleft]" _n
file write `fh' "\footnotesize" _n
file write `fh' "\item[] \textit{Notes:} Pooled individual-level data from the 1982, 1990, and 2000 Chinese population censuses. Birth cohorts 1920--1956. Years of education winsorised at the 1st and 99th percentiles. Treatment is a binary indicator equal to one if the county's total number of officially recognised war martyrs exceeds the cross-county median (`median_count'). Panel~B reports county-level means (each county counted once). Standard deviations in parentheses." _n
file write `fh' "\end{tablenotes}" _n
file write `fh' "\end{table}" _n
file write `fh' "}" _n

file close `fh'

di ""
di "=== All tables and figures saved ==="

exit, clear
