/*  ================================================================
    Summary statistics for pooled sample
    - Treatment group (d_count_high == 1) vs Control (d_count_high == 0)
    - Also by rate dummy
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 = cond(fileexists("${proj}/data/temp/census_1990_mainvars_v1.dta"), "${proj}/data/temp/census_1990_mainvars_v1.dta", "${proj}/data/raw/census/census1990.dta")
global c2000 = cond(fileexists("${proj}/data/temp/census_2000_mainvars_v1.dta"), "${proj}/data/temp/census_2000_mainvars_v1.dta", "${proj}/data/raw/census/census2000.dta")
global outdir "${proj}/paper/assets/tables"

*--------------------------------------------------------------
* county dictionary + crosswalk  (abbreviated)
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
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
summ martyr_per100k_1953, detail
gen d_rate_high = (martyr_per100k_1953 > r(p50)) if !missing(martyr_per100k_1953)

rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
tempfile treat
save `treat'
global treat_tmp "`treat'"

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
*  Load each wave: 1920-1956
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
gen birth_i = floor(birthyr)
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
gen birth_i = floor(birthyr)
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
gen birth_i = floor(birthyr)
gen wave = 3
tempfile w2000
save `w2000'

*==============================================================
*  Pool
*==============================================================
use `w1982', clear
append using `w1990'
append using `w2000'

/* 1% winsorize */
summ eduy, detail
scalar p1 = r(p1)
scalar p99 = r(p99)
replace eduy = p1 if eduy < p1
replace eduy = p99 if eduy > p99 & !missing(eduy)

gen post = (birth_i >= 1940)

di "=== FULL SAMPLE ==="
di "N = " _N

*==============================================================
*  Summary stats by treatment/control
*==============================================================
di ""
di "========================================="
di "  By d_count_high (count > median = 12)"
di "========================================="
di ""
di "--- Control (count <= 12) ---"
summ eduy birthyr minority martyr_count martyr_per100k_1953 if d_count_high == 0
di "--- Treatment (count > 12) ---"
summ eduy birthyr minority martyr_count martyr_per100k_1953 if d_count_high == 1

di ""
di "--- Pre-war cohorts (birth < 1940) ---"
di "  Control:"
summ eduy if d_count_high == 0 & post == 0
di "  Treatment:"
summ eduy if d_count_high == 1 & post == 0
di "--- Post-war cohorts (birth >= 1940) ---"
di "  Control:"
summ eduy if d_count_high == 0 & post == 1
di "  Treatment:"
summ eduy if d_count_high == 1 & post == 1

di ""
di "========================================="
di "  By d_rate_high (rate > median = 6.3)"
di "========================================="
di ""
di "--- Control (rate <= 6.3) ---"
summ eduy birthyr minority martyr_count martyr_per100k_1953 if d_rate_high == 0
di "--- Treatment (rate > 6.3) ---"
summ eduy birthyr minority martyr_count martyr_per100k_1953 if d_rate_high == 1

di ""
di "--- Pre-war (birth < 1940), by rate ---"
di "  Control:"
summ eduy if d_rate_high == 0 & post == 0
di "  Treatment:"
summ eduy if d_rate_high == 1 & post == 0
di "--- Post-war (birth >= 1940), by rate ---"
di "  Control:"
summ eduy if d_rate_high == 0 & post == 1
di "  Treatment:"
summ eduy if d_rate_high == 1 & post == 1

di ""
di "========================================="
di "  By wave"
di "========================================="
forvalues w = 1/3 {
    di "--- Wave `w' ---"
    summ eduy birthyr minority if wave == `w'
}

di ""
di "========================================="
di "  Overall individual-level stats"
di "========================================="
summ eduy birthyr minority wave, detail

di ""
di "========================================="
di "  County-level treatment stats (in regression sample)"
di "========================================="
preserve
    collapse (mean) martyr_count martyr_per100k_1953 ihs_count ihs_rate ln_martyr_raw ln_martyr_per100k_1953 pop_1953 d_count_high d_rate_high, by(countyid_curr6)
    di "Counties in sample: " _N
    summ martyr_count martyr_per100k_1953 ihs_count ihs_rate ln_martyr_raw ln_martyr_per100k_1953 pop_1953, detail
    tab d_count_high
    tab d_rate_high
restore

*==============================================================
*  Output tex table: treat vs control
*==============================================================

/* Compute all means and SDs */
/* Full sample */
summ eduy
local m_edu_all = r(mean)
local sd_edu_all = r(sd)
summ birthyr
local m_by_all = r(mean)
summ minority
local m_min_all = r(mean)
count
local n_all = r(N)

/* By count dummy */
foreach g in 0 1 {
    summ eduy if d_count_high == `g'
    local m_edu_c`g' = r(mean)
    local sd_edu_c`g' = r(sd)
    summ birthyr if d_count_high == `g'
    local m_by_c`g' = r(mean)
    summ minority if d_count_high == `g'
    local m_min_c`g' = r(mean)
    count if d_count_high == `g'
    local n_c`g' = r(N)

    /* pre/post */
    summ eduy if d_count_high == `g' & post == 0
    local m_edu_c`g'_pre = r(mean)
    summ eduy if d_count_high == `g' & post == 1
    local m_edu_c`g'_post = r(mean)
}

/* county-level treatment means */
foreach g in 0 1 {
    summ martyr_count if d_count_high == `g'
    local m_mc_c`g' = r(mean)
    summ martyr_per100k_1953 if d_count_high == `g'
    local m_mr_c`g' = r(mean)
}

tempname fh
file open `fh' using "${outdir}/pooled_sumstats_treat_control_v1.tex", write replace

file write `fh' "\begin{table}[H]" _n
file write `fh' "\centering" _n
file write `fh' "\caption{Summary Statistics: Treatment vs.\ Control Counties}" _n
file write `fh' "\label{tab:sumstats_treat_ctrl}" _n
file write `fh' "\small" _n
file write `fh' "\begin{tabular}{lccc}" _n
file write `fh' "\toprule" _n
file write `fh' " & Control & Treatment & Full sample \\" _n
file write `fh' " & (Count $\leq$ 12) & (Count $>$ 12) & \\" _n
file write `fh' "\midrule" _n

file write `fh' "\multicolumn{4}{l}{\textit{Panel A: Individual characteristics}} \\[0.3em]" _n
file write `fh' "Years of education & " %5.2f (`m_edu_c0') " & " %5.2f (`m_edu_c1') " & " %5.2f (`m_edu_all') " \\" _n
file write `fh' " & (" %5.2f (`sd_edu_c0') ") & (" %5.2f (`sd_edu_c1') ") & (" %5.2f (`sd_edu_all') ") \\[0.2em]" _n
file write `fh' "~~Pre-war cohorts & " %5.2f (`m_edu_c0_pre') " & " %5.2f (`m_edu_c1_pre') " & \\" _n
file write `fh' "~~Post-war cohorts & " %5.2f (`m_edu_c0_post') " & " %5.2f (`m_edu_c1_post') " & \\[0.2em]" _n
file write `fh' "Birth year & " %7.1f (`m_by_c0') " & " %7.1f (`m_by_c1') " & " %7.1f (`m_by_all') " \\" _n
file write `fh' "Minority share & " %5.3f (`m_min_c0') " & " %5.3f (`m_min_c1') " & " %5.3f (`m_min_all') " \\[0.5em]" _n

file write `fh' "\multicolumn{4}{l}{\textit{Panel B: County-level treatment}} \\[0.3em]" _n
file write `fh' "Martyr count (mean) & " %8.1f (`m_mc_c0') " & " %8.1f (`m_mc_c1') " & \\" _n
file write `fh' "Martyrs per 100k (mean) & " %8.1f (`m_mr_c0') " & " %8.1f (`m_mr_c1') " & \\[0.5em]" _n
file write `fh' "\midrule" _n
file write `fh' "Observations & " %12.0fc (`n_c0') " & " %12.0fc (`n_c1') " & " %12.0fc (`n_all') " \\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular}" _n
file write `fh' "\begin{tablenotes}[flushleft]" _n
file write `fh' "\footnotesize" _n
file write `fh' "\item[] \textit{Notes:} Pooled 1982, 1990, and 2000 censuses. Birth cohorts 1920--1956. Treatment defined as county martyr count above the median (12). Standard deviations in parentheses for education." _n
file write `fh' "\end{tablenotes}" _n
file write `fh' "\end{table}" _n

file close `fh'

*==============================================================
*  Suggestive evidence: 2x2 DiD table (treat vs control × pre vs post)
*  Both cutoffs: 1940 and 1946
*==============================================================

foreach cutoff in 1940 1946 {

    local dropyr = `cutoff' - 1   /* 1939 or 1945 */

    /* means by group × period */
    foreach g in 0 1 {
        summ eduy if d_count_high == `g' & birthyr < `cutoff' & birthyr != `dropyr'
        local pre_`g'  = r(mean)
        local n_pre_`g' = r(N)
        summ eduy if d_count_high == `g' & birthyr >= `cutoff' & birthyr != `dropyr'
        local post_`g' = r(mean)
        local n_post_`g' = r(N)
    }

    /* differences */
    local chg_0  = `post_0'  - `pre_0'
    local chg_1  = `post_1'  - `pre_1'
    local did    = `chg_1'   - `chg_0'
    local diff_pre  = `pre_1'  - `pre_0'
    local diff_post = `post_1' - `post_0'

    di ""
    di "=== Suggestive Evidence: Cutoff `cutoff' ==="
    di "Control  pre = " %5.3f `pre_0'  "  post = " %5.3f `post_0'  "  change = " %5.3f `chg_0'
    di "Treat    pre = " %5.3f `pre_1'  "  post = " %5.3f `post_1'  "  change = " %5.3f `chg_1'
    di "DiD = " %5.3f `did'

    /* output tex */
    tempname fh2
    file open `fh2' using "${outdir}/pooled_suggestive_evidence_`cutoff'_v1.tex", write replace

    file write `fh2' "\begin{table}[H]" _n
    file write `fh2' "\centering" _n
    file write `fh2' "\caption{Suggestive Evidence: Mean Years of Education by Treatment Status (Cutoff `cutoff')}" _n
    file write `fh2' "\label{tab:suggestive_`cutoff'}" _n
    file write `fh2' "\begin{tabular}{lccc}" _n
    file write `fh2' "\toprule" _n
    file write `fh2' " & Pre-war & Post-war & $\Delta$ (Post $-$ Pre) \\" _n
    file write `fh2' " & (born $<$ `cutoff') & (born $\geq$ `cutoff') & \\" _n
    file write `fh2' "\midrule" _n
    file write `fh2' "Control (count $\leq$ 12) & " %5.2f (`pre_0') " & " %5.2f (`post_0') " & " %5.2f (`chg_0') " \\" _n
    file write `fh2' " & [" %12.0fc (`n_pre_0') "] & [" %12.0fc (`n_post_0') "] & \\" _n
    file write `fh2' "Treatment (count $>$ 12) & " %5.2f (`pre_1') " & " %5.2f (`post_1') " & " %5.2f (`chg_1') " \\" _n
    file write `fh2' " & [" %12.0fc (`n_pre_1') "] & [" %12.0fc (`n_post_1') "] & \\[0.3em]" _n
    file write `fh2' "\midrule" _n
    file write `fh2' "Difference (T $-$ C) & " %5.2f (`diff_pre') " & " %5.2f (`diff_post') " & \textbf{" %5.2f (`did') "} \\" _n
    file write `fh2' "\bottomrule" _n
    file write `fh2' "\end{tabular}" _n
    file write `fh2' "\begin{tablenotes}[flushleft]" _n
    file write `fh2' "\footnotesize" _n
    file write `fh2' "\item[] \textit{Notes:} Pooled 1982, 1990, and 2000 censuses. Birth cohorts 1920--1956; year `dropyr' dropped. Years of education winsorised at the 1st and 99th percentiles. Treatment defined as county martyr count above the median (12). Observation counts in brackets." _n
    file write `fh2' "\end{tablenotes}" _n
    file write `fh2' "\end{table}" _n

    file close `fh2'
}

di ""
di "=== All tables saved ==="

exit, clear
