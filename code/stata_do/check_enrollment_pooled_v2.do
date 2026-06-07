*******************************************************
* POOLED ENROLLMENT-RATE LADDER  (direct categorical indicator)
* County-cohort-wave panel from 1982+1990+2000 censuses.
*
* Outcome: share whose highest schooling level reached is
* at least the given rung. Constructed directly from the
* categorical schooling variable in each wave.
*
*   enroll_pri   = ever attended primary or higher
*   enroll_mid   = ever attended junior high or higher
*   enroll_hgh   = ever attended senior high or higher
*   enroll_col   = ever attended college (大专) or higher
*
* For 2000 we additionally use schst (Nature of Education
* Completion) to define a strict graduation flag at each
* rung (graduate or higher level reached).
*
* Wave-specific code maps:
*   1982 IPUMS educcn (string-decoded):
*     "illiterate" / "primary" / "junior" / "secondary" /
*     "some college" / "graduated"
*   1990 raw educ:
*     0 unknown, 1 illiterate, 2 primary, 3 junior,
*     4 senior, 5 secondary tech, 6 junior college,
*     7 university
*   2000 raw educ:
*     1 no schooling, 2 literacy, 3 primary, 4 junior,
*     5 high, 6 secondary tech, 7 college specialist,
*     8 university, 9 graduate
*******************************************************

clear all
set more off
set maxvar 10000

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/census_1982_cleaned.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

global census1982 "${proj}/data/temp/census_1982_cleaned.dta"
global census1990 "${proj}/data/raw/census/census1990.dta"
global census2000 "${proj}/data/raw/census/census2000.dta"

global outdir "${proj}/paper/assets/tables"

capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

*--- county dictionary + crosswalk ----------------------------------
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
keep old6 county_curr6
drop if old6=="" | county_curr6==""
duplicates drop old6, force
tempfile cw1982
save `cw1982'
global cw1982_tmp "`cw1982'"

capture program drop _resolve_old6_map
program define _resolve_old6_map
    gen str6 county_curr6 = ""
    replace county_curr6 = "310101" if old6=="310103"
    replace county_curr6 = "310106" if old6=="310108"
    replace county_curr6 = "310115" if old6=="310119"
    replace county_curr6 = "110110" if old6=="110010"
    tempfile left
    save `left'
    rename county_curr6 curr_res
    merge 1:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
    replace curr_res = county_curr6 if curr_res=="" & county_curr6!=""
    drop county_curr6
    rename curr_res county_curr6
    merge m:1 old6 using "$county_dict_tmp", keep(master match) nogen keepusing(curr_dict)
    replace county_curr6 = curr_dict if county_curr6=="" & curr_dict!=""
    drop curr_dict
end

use county using "$census1990", clear
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

use uid using "$census2000", clear
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

*--- treatment ------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw
gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)
rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force
rename county_curr6 countyid_curr6
tempfile treat
save `treat'
global treat_tmp "`treat'"

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*=== Wave 1982: educcn string decode ================================
use countyid birthyr educcn ethniccn using "$census1982", clear
drop if missing(countyid) | missing(birthyr) | missing(educcn)
decode educcn, gen(edu_str)
gen byte enroll_pri = .
gen byte enroll_mid = .
gen byte enroll_hgh = .
gen byte enroll_col = .
* baseline: anyone non-illiterate, non-NIU is at primary or higher
replace enroll_pri = 0 if strpos(edu_str,"illiterate") | strpos(edu_str,"less than primary") | strpos(edu_str,"none")
replace enroll_pri = 1 if strpos(edu_str,"primary") | strpos(edu_str,"junior") | strpos(edu_str,"secondary") | strpos(edu_str,"college") | strpos(edu_str,"graduated")
replace enroll_mid = 0 if !missing(enroll_pri) & enroll_pri==0
replace enroll_mid = 0 if strpos(edu_str,"primary") & !strpos(edu_str,"junior")
replace enroll_mid = 1 if strpos(edu_str,"junior") | strpos(edu_str,"secondary") | strpos(edu_str,"college") | strpos(edu_str,"graduated")
replace enroll_hgh = 0 if !missing(enroll_mid) & enroll_mid==0
replace enroll_hgh = 0 if strpos(edu_str,"junior") & !strpos(edu_str,"secondary") & !strpos(edu_str,"college")
replace enroll_hgh = 1 if strpos(edu_str,"secondary") | strpos(edu_str,"college") | strpos(edu_str,"graduated")
replace enroll_col = 0 if !missing(enroll_hgh) & enroll_hgh==0
replace enroll_col = 0 if strpos(edu_str,"secondary") & !strpos(edu_str,"college") & !strpos(edu_str,"graduated")
replace enroll_col = 1 if strpos(edu_str,"college") | strpos(edu_str,"graduated")
drop if missing(enroll_pri)
gen str6 old6 = string(countyid, "%06.0f")
merge m:1 old6 using "$cw1982_tmp", keep(master match) nogen keepusing(county_curr6)
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birth_i = floor(birthyr)
gen minority = (ethniccn != 1) if !missing(ethniccn)
gen byte nonmigrant = 1   /* 1982 IPUMS: cannot identify movers within China; treat all as in-sample */
keep if inrange(birth_i, 1920, 1956)
gen wave = 1
keep countyid_curr6 birth_i enroll_pri enroll_mid enroll_hgh enroll_col minority nonmigrant wave
tempfile w1982
save `w1982'

*=== Wave 1990: educ 1-7 ============================================
use county age_c age educ race regstatu using "$census1990", clear
drop if missing(county) | missing(age_c) | missing(age) | missing(educ)
gen str6 old6 = string(county, "%06.0f")
merge m:1 old6 using "$map1990_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birthyr = 1000 + age_c*100 + age
gen birth_i = floor(birthyr)
gen minority = (race != 1) if !missing(race)
* educ:1=illit; 2=primary; 3=junior; 4=senior; 5=secondary tech; 6=junior college; 7=univ
drop if educ==0
gen byte enroll_pri = (educ >= 2)
gen byte enroll_mid = (educ >= 3)
gen byte enroll_hgh = (educ >= 4)
gen byte enroll_col = (educ >= 6)
gen byte nonmigrant = (regstatu == 1) if !missing(regstatu)
replace nonmigrant = 1 if missing(regstatu)
keep if inrange(birth_i, 1920, 1956)
gen wave = 2
keep countyid_curr6 birth_i enroll_pri enroll_mid enroll_hgh enroll_col minority nonmigrant wave
tempfile w1990
save `w1990'

*=== Wave 2000: educ 1-9 ============================================
use uid birthyr educ race r061 using "$census2000", clear
drop if missing(uid) | missing(birthyr) | missing(educ)
gen str6 old6 = string(uid, "%06.0f")
merge m:1 old6 using "$map2000_tmp", keep(master match) nogen
keep if county_curr6!=""
rename county_curr6 countyid_curr6
gen birth_i = floor(birthyr)
gen minority = (race != 1) if !missing(race)
* educ:1=none; 2=literacy; 3=primary; 4=junior; 5=high; 6=secondary tech; 7=college specialist; 8=undergrad; 9=grad
gen byte enroll_pri = (educ >= 3)
gen byte enroll_mid = (educ >= 4)
gen byte enroll_hgh = (educ >= 5)
gen byte enroll_col = (educ >= 7)
gen byte nonmigrant = (r061 == 1) if !missing(r061)
replace nonmigrant = 1 if missing(r061)
keep if inrange(birth_i, 1920, 1956)
gen wave = 3
keep countyid_curr6 birth_i enroll_pri enroll_mid enroll_hgh enroll_col minority nonmigrant wave
tempfile w2000
save `w2000'

*=== Pool, merge treatment, collapse ================================
use `w1982', clear
append using `w1990'
append using `w2000'

merge m:1 countyid_curr6 using "$treat_tmp", keep(match) nogen

encode countyid_curr6, gen(county_num)
gen cell_n = 1
collapse (mean) enroll_pri enroll_mid enroll_hgh enroll_col ///
                minority_share=minority nonmigrant_share=nonmigrant ///
         (sum) cell_n, by(countyid_curr6 county_num birth_i wave ihs_rate d_count_high)

di "=== POOLED county-cohort-wave cells = " _N " ==="

*=== Regressions ====================================================
local outcomes "enroll_pri enroll_mid enroll_hgh enroll_col"

foreach cutoff in 1940 1946 {
    capture drop post treat_ihs_post treat_d_post
    gen post = (birth_i >= `cutoff')
    gen treat_ihs_post = ihs_rate * post
    gen treat_d_post = d_count_high * post
    local omit = cond(`cutoff'==1940, 1939, 1945)

    foreach y of local outcomes {
        quietly reghdfejl `y' treat_ihs_post ihs_rate post minority_share i.wave [aw=cell_n] if birth_i != `omit', absorb(county_num birth_i) vce(cluster county_num)
        local b_`y'_i_`cutoff' = _b[treat_ihs_post]
        local se_`y'_i_`cutoff' = _se[treat_ihs_post]
        local p_`y'_i_`cutoff' = 2*ttail(e(df_r), abs(`b_`y'_i_`cutoff''/`se_`y'_i_`cutoff''))
        local n_`y'_i_`cutoff' = e(N)

        quietly reghdfejl `y' treat_d_post d_count_high post minority_share i.wave [aw=cell_n] if birth_i != `omit', absorb(county_num birth_i) vce(cluster county_num)
        local b_`y'_d_`cutoff' = _b[treat_d_post]
        local se_`y'_d_`cutoff' = _se[treat_d_post]
        local p_`y'_d_`cutoff' = 2*ttail(e(df_r), abs(`b_`y'_d_`cutoff''/`se_`y'_d_`cutoff''))
        local n_`y'_d_`cutoff' = e(N)
    }
    drop post treat_ihs_post treat_d_post
}

*=== Output table ===================================================
foreach cutoff in 1940 1946 {
    foreach y of local outcomes {
        foreach v in i d {
            _stars `p_`y'_`v'_`cutoff''
            local s_`y'_`v'_`cutoff' "`r(star)'"
            local fb_`y'_`v'_`cutoff' : di %9.4f `b_`y'_`v'_`cutoff''
            local fse_`y'_`v'_`cutoff' : di %7.4f `se_`y'_`v'_`cutoff''
        }
    }
    local fn_i_`cutoff' : di %12.0fc `n_enroll_pri_i_`cutoff''
    local fn_d_`cutoff' : di %12.0fc `n_enroll_pri_d_`cutoff''
}

foreach cutoff in 1940 1946 {
    tempname fh
    file open `fh' using "$outdir/enrollment_pooled_cut`cutoff'_v2.tex", write replace
    file write `fh' "{"                                                           _n
    file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}"              _n
    file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
    file write `fh' "\toprule"                                                    _n
    file write `fh' "            &Primary&Middle&Senior High&College\\" _n
    file write `fh' "\midrule"                                                    _n
    file write `fh' "\multicolumn{5}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
    file write `fh' "Post $\times$ IHS(rate)&`fb_enroll_pri_i_`cutoff''\sym{`s_enroll_pri_i_`cutoff''}&`fb_enroll_mid_i_`cutoff''\sym{`s_enroll_mid_i_`cutoff''}&`fb_enroll_hgh_i_`cutoff''\sym{`s_enroll_hgh_i_`cutoff''}&`fb_enroll_col_i_`cutoff''\sym{`s_enroll_col_i_`cutoff''}\\" _n
    file write `fh' "            &( `fse_enroll_pri_i_`cutoff'')&( `fse_enroll_mid_i_`cutoff'')&( `fse_enroll_hgh_i_`cutoff'')&( `fse_enroll_col_i_`cutoff'')\\[0.5em]" _n
    file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
    file write `fh' "Post $\times$ High count&`fb_enroll_pri_d_`cutoff''\sym{`s_enroll_pri_d_`cutoff''}&`fb_enroll_mid_d_`cutoff''\sym{`s_enroll_mid_d_`cutoff''}&`fb_enroll_hgh_d_`cutoff''\sym{`s_enroll_hgh_d_`cutoff''}&`fb_enroll_col_d_`cutoff''\sym{`s_enroll_col_d_`cutoff''}\\" _n
    file write `fh' "            &( `fse_enroll_pri_d_`cutoff'')&( `fse_enroll_mid_d_`cutoff'')&( `fse_enroll_hgh_d_`cutoff'')&( `fse_enroll_col_d_`cutoff'')\\" _n
    file write `fh' "\midrule"                                                    _n
    file write `fh' "County FE&\multicolumn{4}{c}{Yes}\\"                        _n
    file write `fh' "Cohort FE&\multicolumn{4}{c}{Yes}\\"                        _n
    file write `fh' "Wave FE&\multicolumn{4}{c}{Yes}\\"                          _n
    file write `fh' "Weights&\multicolumn{4}{c}{County $\times$ cohort $\times$ wave population}\\" _n
    file write `fh' "Obs (IHS)&\multicolumn{4}{c}{`fn_i_`cutoff''}\\"            _n
    file write `fh' "Obs (Dummy)&\multicolumn{4}{c}{`fn_d_`cutoff''}\\"          _n
    file write `fh' "\bottomrule"                                                 _n
    file write `fh' "\end{tabular*}"                                              _n
    file write `fh' "}"                                                           _n
    file close `fh'
}

di as text "Written: $outdir/enrollment_pooled_cut1940_v2.tex"
di as text "Written: $outdir/enrollment_pooled_cut1946_v2.tex"

exit, clear
