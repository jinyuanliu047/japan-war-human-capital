*******************************************************
* CGSS 2008 all eligible attitude/value questions
* Individual-level regressions, one outcome at a time
* Controls: female + minority + urban_hukou + local_hukou
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace
capture which reghdfe
if _rc != 0 {
    di as error "reghdfe not found"
    exit 198
}

use serial countyid a1 a2 a6 a14a a14d e3a e3b e3c e3d e3e e3f using "${proj}/data/raw/cgss2008_14.dta", clear
merge 1:1 serial using "${proj}/data/raw/cgss2008b_14.dta", keep(match) nogen

gen str6 countyid_curr6 = string(countyid, "%06.0f")
merge m:1 countyid_curr6 using "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", ///
    keep(match) nogen keepusing(ln_martyr_per100k_1953)

gen birth_i = floor(a2)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940

gen female = (a1 == 2) if inlist(a1, 1, 2)
gen minority = (a6 != 1) if inrange(a6, 1, 56)
gen urban_hukou = inlist(a14a, 1, 2, 3, 4, 5) if inrange(a14a, 1, 6)
gen local_hukou = inlist(a14d, 1, 2) if inrange(a14d, 1, 4)

egen county_num = group(countyid_curr6)

* 1-4 frequency/affect: higher = more frequent / more affect
gen japan_anime_freq = 5 - ga1 if inrange(ga1, 1, 4)
gen chinese_movie_freq = 5 - ga2 if inrange(ga2, 1, 4)
gen korean_drama_freq = 5 - ga3 if inrange(ga3, 1, 4)
gen hometown_affect = 5 - ge1a if inrange(ge1a, 1, 4)
gen country_affect = 5 - ge1b if inrange(ge1b, 1, 4)
gen eastasia_affect = 5 - ge1c if inrange(ge1c, 1, 4)

* 1-7 agreement: higher = stronger agreement
gen import_protect = 8 - gl1a if inrange(gl1a, 1, 7)
gen nat_interest = 8 - gl1b if inrange(gl1b, 1, 7)
gen culture_protect = 8 - gl1c if inrange(gl1c, 1, 7)
gen wife_support_husband = 8 - gd1a if inrange(gd1a, 1, 7)
gen father_authority = 8 - gd1b if inrange(gd1b, 1, 7)
gen follow_majority = 8 - gd2a if inrange(gd2a, 1, 7)
gen avoid_complaint = 8 - gd2b if inrange(gd2b, 1, 7)
gen hire_own_people = 8 - gd3a if inrange(gd3a, 1, 7)
gen local_pride = 8 - gd3b if inrange(gd3b, 1, 7)
gen obey_superior = 8 - gd4a if inrange(gd4a, 1, 7)
gen strong_leader = 8 - gd4b if inrange(gd4b, 1, 7)
gen risk_life = 8 - gd5a if inrange(gd5a, 1, 7)
gen risk_invest = 8 - gd5b if inrange(gd5b, 1, 7)

* 1-5 scales with 6 = cannot choose
gen rich_family_importance = 6 - f1a if inrange(f1a, 1, 5)
gen parent_edu_importance = 6 - f1b if inrange(f1b, 1, 5)
gen own_edu_importance = 6 - f1c if inrange(f1c, 1, 5)
gen ambition_importance = 6 - f1d if inrange(f1d, 1, 5)
gen hardwork_importance = 6 - f1e if inrange(f1e, 1, 5)
gen connections_importance = 6 - f1f if inrange(f1f, 1, 5)
gen political_ties_importance = 6 - f1g if inrange(f1g, 1, 5)
gen bribery_importance = 6 - f1h if inrange(f1h, 1, 5)
gen ethnicity_importance = 6 - f1i if inrange(f1i, 1, 5)
gen religion_importance = 6 - f1j if inrange(f1j, 1, 5)
gen gender_importance = 6 - f1k if inrange(f1k, 1, 5)
gen corruption_needed = 6 - f2a if inrange(f2a, 1, 5)
gen best_school_gatekeep = 6 - f2b if inrange(f2b, 1, 5)
gen college_only_for_rich = 6 - f2c if inrange(f2c, 1, 5)
gen edu_equal_opportunity = 6 - f2d if inrange(f2d, 1, 5)
gen pro_health_ineq = 6 - f8a if inrange(f8a, 1, 5)
gen pro_edu_ineq = 6 - f8b if inrange(f8b, 1, 5)
gen guanxi_common = 6 - e3a if inrange(e3a, 1, 5)
gen guanxi_tradition = 6 - e3b if inrange(e3b, 1, 5)
gen guanxi_lowability = 6 - e3c if inrange(e3c, 1, 5)
gen guanxi_fair = 6 - e3d if inrange(e3d, 1, 5)
gen guanxi_firstmove = 6 - e3e if inrange(e3e, 1, 5)
gen guanxi_close_ties = 6 - e3f if inrange(e3f, 1, 5)

label var japan_anime_freq "Watch Japanese anime"
label var chinese_movie_freq "Watch Chinese movies"
label var korean_drama_freq "Watch Korean TV"
label var hometown_affect "Affect to hometown"
label var country_affect "Affect to country"
label var eastasia_affect "Affect to East Asia"
label var import_protect "Support import limits"
label var nat_interest "National interest first"
label var culture_protect "Foreign culture harmful"
label var rich_family_importance "Rich family matters"
label var parent_edu_importance "Parents' education matters"
label var own_edu_importance "Own education matters"
label var ambition_importance "Ambition matters"
label var hardwork_importance "Hard work matters"
label var connections_importance "Connections matter"
label var political_ties_importance "Political ties matter"
label var bribery_importance "Bribery matters"
label var ethnicity_importance "Ethnicity matters"
label var religion_importance "Religion matters"
label var gender_importance "Gender matters"
label var corruption_needed "Corruption needed"
label var best_school_gatekeep "Top high school gatekeep"
label var college_only_for_rich "College only for rich"
label var edu_equal_opportunity "Equal college opportunity"
label var pro_health_ineq "Health inequality acceptable"
label var pro_edu_ineq "Education inequality acceptable"
label var wife_support_husband "Wife support husband"
label var father_authority "Father authority"
label var follow_majority "Follow majority"
label var avoid_complaint "Avoid complaint"
label var hire_own_people "Hire own people"
label var local_pride "Pride in locals"
label var obey_superior "Obey superior"
label var strong_leader "Strong leader decides"
label var risk_life "Prefer risky life"
label var risk_invest "Prefer risky investment"
label var guanxi_common "Guanxi common"
label var guanxi_tradition "Guanxi is tradition"
label var guanxi_lowability "Guanxi for low ability"
label var guanxi_fair "Guanxi is fair"
label var guanxi_firstmove "Guanxi should come early"
label var guanxi_close_ties "Close ties help guanxi"

tempfile cgss_att_main
save `cgss_att_main', replace
global cgss_att_tmp "`cgss_att_main'"

local outcomes ///
    japan_anime_freq chinese_movie_freq korean_drama_freq ///
    hometown_affect country_affect eastasia_affect ///
    import_protect nat_interest culture_protect ///
    rich_family_importance parent_edu_importance own_edu_importance ambition_importance ///
    hardwork_importance connections_importance political_ties_importance bribery_importance ///
    ethnicity_importance religion_importance gender_importance ///
    corruption_needed best_school_gatekeep college_only_for_rich edu_equal_opportunity ///
    pro_health_ineq pro_edu_ineq ///
    wife_support_husband father_authority follow_majority avoid_complaint ///
    hire_own_people local_pride obey_superior strong_leader risk_life risk_invest ///
    guanxi_common guanxi_tradition guanxi_lowability guanxi_fair guanxi_firstmove guanxi_close_ties

capture program drop _run_outcome
program define _run_outcome, rclass
    syntax , YVAR(name) MODEL(name)
    use "$cgss_att_tmp", clear
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou)
    local n = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou) & post == 0
    local n_pre = r(N)
    quietly count if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou) & post == 1
    local n_post = r(N)
    quietly reghdfe `yvar' c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou ///
        if !missing(`yvar', ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou), ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `model'
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar N_sample = `n'
    estadd scalar N_pre = `n_pre'
    estadd scalar N_post = `n_post'
    return scalar b = _b[1.post#c.ln_martyr_per100k_1953]
    return scalar se = _se[1.post#c.ln_martyr_per100k_1953]
    return scalar p = 2*ttail(e(df_r), abs(_b[1.post#c.ln_martyr_per100k_1953] / _se[1.post#c.ln_martyr_per100k_1953]))
    return scalar n = `n'
    return scalar n_pre = `n_pre'
    return scalar n_post = `n_post'
end

eststo clear

tempfile summary
clear
set obs 0
gen str40 outcome = ""
gen str80 outcome_label = ""
gen b = .
gen se = .
gen p = .
gen n = .
gen n_pre = .
gen n_post = .
save `summary', replace

local models ""
foreach y of local outcomes {
    local m = "m_`y'"
    use "$cgss_att_tmp", clear
    quietly count if !missing(`y', ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou)
    local n = r(N)
    quietly count if !missing(`y', ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou) & post == 0
    local n_pre = r(N)
    quietly count if !missing(`y', ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou) & post == 1
    local n_post = r(N)
    quietly reghdfe `y' c.ln_martyr_per100k_1953##ib0.post female minority urban_hukou local_hukou ///
        if !missing(`y', ln_martyr_per100k_1953, post, county_num, birth_i, female, minority, urban_hukou, local_hukou), ///
        absorb(county_num birth_i) vce(cluster county_num)
    estimates store `m'
    estadd local Controls "Y"
    estadd local County_FE "Y"
    estadd local Cohort_FE "Y"
    estadd scalar N_sample = `n'
    estadd scalar N_pre = `n_pre'
    estadd scalar N_post = `n_post'
    local b = _b[1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b' / `se'))
    local models "`models' `m'"
    use `summary', clear
    local row = _N + 1
    set obs `row'
    replace outcome = "`y'" in `row'
    replace outcome_label = "`y'" in `row'
    replace b = `b' in `row'
    replace se = `se' in `row'
    replace p = `p' in `row'
    replace n = `n' in `row'
    replace n_pre = `n_pre' in `row'
    replace n_post = `n_post' in `row'
    save `summary', replace
}

use `summary', clear
sort outcome
export delimited using "${proj}/result/table/mechanism_cgss_attitudes_all_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/mechanism_cgss_attitudes_all_reghdfejl_summary_v1.dta", replace

esttab `models' using "${proj}/result/table/mechanism_cgss_attitudes_all_reghdfejl_v1.rtf", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

esttab `models' using "${proj}/result/table/mechanism_cgss_attitudes_all_reghdfejl_v1.tex", ///
    replace keep(1.post#c.ln_martyr_per100k_1953) ///
    scalar(Controls County_FE Cohort_FE N_sample N_pre N_post) se r2 ar2 star(* 0.1 ** 0.05 *** 0.01)

exit, clear
