/*  ================================================================
    Pooled heterogeneity analysis (updated treatment: dummy count)
    1) Gender: male vs female
    2) Base education: county pre-war education level (high vs low)
    3) Minority: Han vs minority

    Pooled 1982+1990+2000, birth cohorts 1920-1956, cutoff 1940 & 1946
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
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))

summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)

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
*  Load each wave
*  NOTE: 1982 mainvars doesn't have sex — load without sex,
*  gender heterogeneity uses 1990+2000 only
*==============================================================
use countyid birthyr eduy ethniccn using "$c1982", clear
drop if missing(countyid) | missing(birthyr) | missing(eduy)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
gen minority = (ethniccn != 1) if !missing(ethniccn)
gen female = .
keep if inrange(birthyr, 1920, 1956)
rename county_curr6 countyid_curr6
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 1
tempfile w1982
save `w1982'

use county age_c age educ race sex using "${proj}/data/raw/census/census1990.dta", clear
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
gen female = (sex == 2) if !missing(sex)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
gen wave = 2
tempfile w1990
save `w1990'

use uid birthyr eduyr sex race using "${proj}/data/raw/census/census2000.dta", clear
drop if missing(uid) | missing(birthyr) | missing(eduyr)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen eduy = eduyr
gen minority = (race != 1) if !missing(race)
gen female = (sex == 2) if !missing(sex)
keep if inrange(birthyr, 1920, 1956)
drop if missing(eduy)
merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen
gen birth_i = floor(birthyr)
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

encode countyid_curr6, gen(county_num)

/* cohort cell size */
bysort county_num birth_i wave: gen cohort_n = _N
gen ln_cohort_n = ln(cohort_n)

/* compute county-level pre-war education (base education) */
bysort countyid_curr6: egen base_edu = mean(cond(birthyr < 1940, eduy, .))
summ base_edu, detail
gen high_base_edu = (base_edu > r(p50)) if !missing(base_edu)

di "=== POOLED N = " _N " ==="
di "Female share = "
summ female
di "High base edu counties: "
tab high_base_edu

*==============================================================
*  Heterogeneity regressions
*==============================================================

tempname memhold
postfile `memhold' str20 subgroup str5 cohort_cut ///
    beta se pval n_obs using "${proj}/data/temp/pooled_heterogeneity_results.dta", replace

foreach cutoff in 1940 1946 {
    capture drop post drop_yr
    gen post = (birth_i >= `cutoff')
    gen byte drop_yr = (birth_i == `cutoff' - 1)

    /* === Baseline (full sample) === */
    di ""
    di "=== Cutoff `cutoff': FULL SAMPLE ==="
    reghdfejl eduy i.d_count_high##ib0.post minority i.wave if !drop_yr, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b  = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p  = 2*ttail(e(df_r), abs(`b'/`se'))
    di "  Full: beta=" %8.4f `b' " se=" %8.4f `se' " p=" %6.4f `p'
    post `memhold' ("full") ("`cutoff'") (`b') (`se') (`p') (e(N))

    /* === Gender: Male === */
    di "=== Cutoff `cutoff': MALE ==="
    reghdfejl eduy i.d_count_high##ib0.post minority i.wave if !drop_yr & female==0, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b  = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p  = 2*ttail(e(df_r), abs(`b'/`se'))
    di "  Male: beta=" %8.4f `b' " se=" %8.4f `se' " p=" %6.4f `p'
    post `memhold' ("male") ("`cutoff'") (`b') (`se') (`p') (e(N))

    /* === Gender: Female === */
    di "=== Cutoff `cutoff': FEMALE ==="
    reghdfejl eduy i.d_count_high##ib0.post minority i.wave if !drop_yr & female==1, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b  = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p  = 2*ttail(e(df_r), abs(`b'/`se'))
    di "  Female: beta=" %8.4f `b' " se=" %8.4f `se' " p=" %6.4f `p'
    post `memhold' ("female") ("`cutoff'") (`b') (`se') (`p') (e(N))

    /* === Base education: Low === */
    di "=== Cutoff `cutoff': LOW BASE EDU ==="
    reghdfejl eduy i.d_count_high##ib0.post minority i.wave if !drop_yr & high_base_edu==0, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b  = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p  = 2*ttail(e(df_r), abs(`b'/`se'))
    di "  Low base: beta=" %8.4f `b' " se=" %8.4f `se' " p=" %6.4f `p'
    post `memhold' ("low_base_edu") ("`cutoff'") (`b') (`se') (`p') (e(N))

    /* === Base education: High === */
    di "=== Cutoff `cutoff': HIGH BASE EDU ==="
    reghdfejl eduy i.d_count_high##ib0.post minority i.wave if !drop_yr & high_base_edu==1, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b  = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p  = 2*ttail(e(df_r), abs(`b'/`se'))
    di "  High base: beta=" %8.4f `b' " se=" %8.4f `se' " p=" %6.4f `p'
    post `memhold' ("high_base_edu") ("`cutoff'") (`b') (`se') (`p') (e(N))

    /* === Han vs Minority === */
    di "=== Cutoff `cutoff': HAN ==="
    reghdfejl eduy i.d_count_high##ib0.post i.wave if !drop_yr & minority==0, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b  = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p  = 2*ttail(e(df_r), abs(`b'/`se'))
    di "  Han: beta=" %8.4f `b' " se=" %8.4f `se' " p=" %6.4f `p'
    post `memhold' ("han") ("`cutoff'") (`b') (`se') (`p') (e(N))

    di "=== Cutoff `cutoff': MINORITY ==="
    reghdfejl eduy i.d_count_high##ib0.post i.wave if !drop_yr & minority==1, ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b  = _b[1.d_count_high#1.post]
    local se = _se[1.d_count_high#1.post]
    local p  = 2*ttail(e(df_r), abs(`b'/`se'))
    di "  Minority: beta=" %8.4f `b' " se=" %8.4f `se' " p=" %6.4f `p'
    post `memhold' ("minority_only") ("`cutoff'") (`b') (`se') (`p') (e(N))

    drop post drop_yr
}

postclose `memhold'

/* display and output */
use "${proj}/data/temp/pooled_heterogeneity_results.dta", clear
list, sep(7) noobs

/* generate tex table */
tempname fh
file open `fh' using "${outdir}/pooled_heterogeneity_v1.tex", write replace

file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "                    &\multicolumn{2}{c}{Cutoff 1940}  &\multicolumn{2}{c}{Cutoff 1946}  \\" _n
file write `fh' "                    & Coeff. & Obs. & Coeff. & Obs.  \\" _n
file write `fh' "\midrule" _n

/* read data back */
local row = 1
local labels `" "Full sample" "Male" "Female" "Low pre-war education" "High pre-war education" "Han" "Ethnic minority" "'
local groups `" "full" "male" "female" "low_base_edu" "high_base_edu" "han" "minority_only" "'

forvalues i = 1/7 {
    local lab : word `i' of `labels'
    local grp : word `i' of `groups'

    /* cutoff 1940 */
    summ beta if subgroup == "`grp'" & cohort_cut == "1940"
    local b1940 = r(mean)
    summ se if subgroup == "`grp'" & cohort_cut == "1940"
    local se1940 = r(mean)
    summ pval if subgroup == "`grp'" & cohort_cut == "1940"
    local p1940 = r(mean)
    summ n_obs if subgroup == "`grp'" & cohort_cut == "1940"
    local n1940 = r(mean)

    /* cutoff 1946 */
    summ beta if subgroup == "`grp'" & cohort_cut == "1946"
    local b1946 = r(mean)
    summ se if subgroup == "`grp'" & cohort_cut == "1946"
    local se1946 = r(mean)
    summ pval if subgroup == "`grp'" & cohort_cut == "1946"
    local p1946 = r(mean)
    summ n_obs if subgroup == "`grp'" & cohort_cut == "1946"
    local n1946 = r(mean)

    /* stars */
    local s1940 ""
    if `p1940' < 0.01 local s1940 "{***}"
    else if `p1940' < 0.05 local s1940 "{**}"
    else if `p1940' < 0.10 local s1940 "{*}"

    local s1946 ""
    if `p1946' < 0.01 local s1946 "{***}"
    else if `p1946' < 0.05 local s1946 "{**}"
    else if `p1946' < 0.10 local s1946 "{*}"

    if `i' == 1 | `i' == 2 | `i' == 4 | `i' == 6 {
        if `i' == 2 file write `fh' "\multicolumn{5}{l}{\textit{A. Gender}} \\[0.2em]" _n
        if `i' == 4 file write `fh' "\multicolumn{5}{l}{\textit{B. County pre-war education}} \\[0.2em]" _n
        if `i' == 6 file write `fh' "\multicolumn{5}{l}{\textit{C. Ethnicity}} \\[0.2em]" _n
    }

    file write `fh' "`lab'  &" %8.3f (`b1940') "\sym`s1940'  &" %12.0fc (`n1940') "  &" %8.3f (`b1946') "\sym`s1946'  &" %12.0fc (`n1946') "  \\" _n
    file write `fh' "                    & (" %5.3f (`se1940') ")  &  & (" %5.3f (`se1946') ")  &  \\" _n

    if `i' == 1 | `i' == 3 | `i' == 5 | `i' == 7 {
        file write `fh' "[0.3em]" _n
    }
}

file write `fh' "\midrule" _n
file write `fh' "\multicolumn{5}{l}{Controls: minority, county FE, birth cohort FE, wave FE} \\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "\begin{tablenotes}[flushleft]" _n
file write `fh' "\footnotesize" _n
file write `fh' "\item[] \textit{Notes:} Pooled individual-level DiD with treatment dummy (county martyr count $>$ median). ``Pre-war education'' is the county-level mean education for cohorts born before the cutoff year. Standard errors clustered at the county level in parentheses. $^{*}p<0.10$; $^{**}p<0.05$; $^{***}p<0.01$." _n
file write `fh' "\end{tablenotes}" _n
file write `fh' "}" _n

file close `fh'

di ""
di "=== Heterogeneity table saved ==="

exit, clear
