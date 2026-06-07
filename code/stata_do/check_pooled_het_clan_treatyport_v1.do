/*  ================================================================
    Pooled heterogeneity: Clan density + Treaty port
    Uses pre-built pooled dataset structure
    ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global c1982 = cond(fileexists("${proj}/data/temp/census_1982_mainvars_v1.dta"), "${proj}/data/temp/census_1982_mainvars_v1.dta", "${proj}/data/temp/census_1982_cleaned.dta")
global c1990 "${proj}/data/raw/census/census1990.dta"
global c2000 "${proj}/data/raw/census/census2000.dta"
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
* treatment + controls
*--------------------------------------------------------------
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw pop_1953

gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_count = ln(martyr_count + sqrt(martyr_count^2 + 1))
gen ihs_rate  = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

summ martyr_count, detail
gen d_count_high = (martyr_count > r(p50)) if !missing(martyr_count)

rename countyid_curr6 county_curr6
replace county_curr6 = substr("000000" + county_curr6, strlen("000000" + county_curr6)-5, 6)
duplicates drop county_curr6, force

/* merge clan data */
rename county_curr6 countyid_curr6
merge 1:1 countyid_curr6 using "${proj}/data/temp/county_clan_quake_controls_v1.dta", keep(master match) nogen keepusing(clan_num ln_clan)
/* clan indicator: any clans present */
gen clan_any = (clan_num > 0 & !missing(clan_num))

tempfile treat
save `treat'
global treat_tmp "`treat'"

*--------------------------------------------------------------
* mapping
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

gen post1940 = (birth_i >= 1940)
gen drop1939 = (birth_i == 1939)

di "=== POOLED N = " _N " ==="

/* treaty port mapping */
gen str4 pref4 = substr(countyid_curr6, 1, 4)

gen treaty_port_pref = 0
/* Treaty port prefectures (74 codes → 30 ports) */
replace treaty_port_pref = 1 if inlist(pref4, "1201", "1202", "1301", "2101", "2102", "2201")
replace treaty_port_pref = 1 if inlist(pref4, "2301", "3101", "3201", "3202", "3203", "3204")
replace treaty_port_pref = 1 if inlist(pref4, "3205", "3206", "3207", "3210", "3211", "3301")
replace treaty_port_pref = 1 if inlist(pref4, "3302", "3304", "3305", "3307", "3402", "3501")
replace treaty_port_pref = 1 if inlist(pref4, "3502", "3601", "3701", "3702", "3706", "3707")
replace treaty_port_pref = 1 if inlist(pref4, "4101", "4201", "4202", "4301", "4401", "4402")
replace treaty_port_pref = 1 if inlist(pref4, "4403", "4404", "4405", "4406", "4419", "4420")
replace treaty_port_pref = 1 if inlist(pref4, "4501", "4504", "5001", "5101", "5301", "5401")
replace treaty_port_pref = 1 if inlist(pref4, "6201", "6501")

tab treaty_port_pref
tab clan_any

*--------------------------------------------------------------
* Stars helper
*--------------------------------------------------------------
capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*##############################################################
*  PART 1: CLAN HETEROGENEITY
*##############################################################
di ""
di "========================================"
di "  PART 1: Clan Density Heterogeneity"
di "========================================"

foreach cl in 0 1 {
    if `cl' == 0 local clabel "No ancestral clans"
    if `cl' == 1 local clabel "Has ancestral clans"

    di "=== `clabel', IHS rate ==="
    reghdfejl eduy c.ihs_rate##ib0.post1940 minority i.wave if !drop1939 & clan_any == `cl', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_cl`cl'_ihs = _b[1.post1940#c.ihs_rate]
    local se_cl`cl'_ihs = _se[1.post1940#c.ihs_rate]
    local p_cl`cl'_ihs = 2*ttail(e(df_r), abs(`b_cl`cl'_ihs'/`se_cl`cl'_ihs'))
    local n_cl`cl'_ihs = e(N)

    di "=== `clabel', Dummy ==="
    reghdfejl eduy i.d_count_high##ib0.post1940 minority i.wave if !drop1939 & clan_any == `cl', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_cl`cl'_dum = _b[1.d_count_high#1.post1940]
    local se_cl`cl'_dum = _se[1.d_count_high#1.post1940]
    local p_cl`cl'_dum = 2*ttail(e(df_r), abs(`b_cl`cl'_dum'/`se_cl`cl'_dum'))
    local n_cl`cl'_dum = e(N)

    di "  IHS: b=" %8.4f `b_cl`cl'_ihs' " p=" %6.4f `p_cl`cl'_ihs'
    di "  Dum: b=" %8.4f `b_cl`cl'_dum' " p=" %6.4f `p_cl`cl'_dum'
}

/* Output clan table */
tempname fh
file open `fh' using "${outdir}/pooled_heterogeneity_clan_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{No ancestral clans}&\multicolumn{2}{c}{Has ancestral clans}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &Dummy&IHS(rate)&Dummy&IHS(rate)\\" _n
file write `fh' "\midrule" _n
forvalues c = 0/1 {
    _stars `p_cl`c'_dum'
    local sd`c' "`r(star)'"
    _stars `p_cl`c'_ihs'
    local si`c' "`r(star)'"
}
file write `fh' "Post $\times$ Treatment&" ///
    %10.4f (`b_cl0_dum') "\sym{`sd0'}&" %10.4f (`b_cl0_ihs') "\sym{`si0'}&" ///
    %10.4f (`b_cl1_dum') "\sym{`sd1'}&" %10.4f (`b_cl1_ihs') "\sym{`si1'}\\" _n
file write `fh' "            &(" %7.4f (`se_cl0_dum') ")&(" %7.4f (`se_cl0_ihs') ")&(" %7.4f (`se_cl1_dum') ")&(" %7.4f (`se_cl1_ihs') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Observations&" %12.0fc (`n_cl0_dum') "&" %12.0fc (`n_cl0_ihs') "&" %12.0fc (`n_cl1_dum') "&" %12.0fc (`n_cl1_ihs') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Clan heterogeneity table saved ==="

*##############################################################
*  PART 2: TREATY PORT HETEROGENEITY
*##############################################################
di ""
di "========================================"
di "  PART 2: Treaty Port Heterogeneity"
di "========================================"

foreach tp in 0 1 {
    if `tp' == 0 local tplabel "Non-treaty-port prefecture"
    if `tp' == 1 local tplabel "Treaty-port prefecture"

    di "=== `tplabel', IHS rate ==="
    reghdfejl eduy c.ihs_rate##ib0.post1940 minority i.wave if !drop1939 & treaty_port_pref == `tp', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_tp`tp'_ihs = _b[1.post1940#c.ihs_rate]
    local se_tp`tp'_ihs = _se[1.post1940#c.ihs_rate]
    local p_tp`tp'_ihs = 2*ttail(e(df_r), abs(`b_tp`tp'_ihs'/`se_tp`tp'_ihs'))
    local n_tp`tp'_ihs = e(N)

    di "=== `tplabel', Dummy ==="
    reghdfejl eduy i.d_count_high##ib0.post1940 minority i.wave if !drop1939 & treaty_port_pref == `tp', ///
        absorb(county_num birth_i) vce(cluster county_num)
    local b_tp`tp'_dum = _b[1.d_count_high#1.post1940]
    local se_tp`tp'_dum = _se[1.d_count_high#1.post1940]
    local p_tp`tp'_dum = 2*ttail(e(df_r), abs(`b_tp`tp'_dum'/`se_tp`tp'_dum'))
    local n_tp`tp'_dum = e(N)

    di "  IHS: b=" %8.4f `b_tp`tp'_ihs' " p=" %6.4f `p_tp`tp'_ihs'
    di "  Dum: b=" %8.4f `b_tp`tp'_dum' " p=" %6.4f `p_tp`tp'_dum'
}

/* Output treaty port table */
tempname fh
file open `fh' using "${outdir}/pooled_heterogeneity_treatyport_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{Non-treaty-port}&\multicolumn{2}{c}{Treaty-port}\\" _n
file write `fh' "            \cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &Dummy&IHS(rate)&Dummy&IHS(rate)\\" _n
file write `fh' "\midrule" _n
forvalues t = 0/1 {
    _stars `p_tp`t'_dum'
    local sd`t' "`r(star)'"
    _stars `p_tp`t'_ihs'
    local si`t' "`r(star)'"
}
file write `fh' "Post $\times$ Treatment&" ///
    %10.4f (`b_tp0_dum') "\sym{`sd0'}&" %10.4f (`b_tp0_ihs') "\sym{`si0'}&" ///
    %10.4f (`b_tp1_dum') "\sym{`sd1'}&" %10.4f (`b_tp1_ihs') "\sym{`si1'}\\" _n
file write `fh' "            &(" %7.4f (`se_tp0_dum') ")&(" %7.4f (`se_tp0_ihs') ")&(" %7.4f (`se_tp1_dum') ")&(" %7.4f (`se_tp1_ihs') ")\\" _n
file write `fh' "\midrule" _n
file write `fh' "Observations&" %12.0fc (`n_tp0_dum') "&" %12.0fc (`n_tp0_ihs') "&" %12.0fc (`n_tp1_dum') "&" %12.0fc (`n_tp1_ihs') "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== Treaty port heterogeneity table saved ==="

di ""
di "========================================="
di "  CLAN + TREATY PORT REGRESSIONS COMPLETE"
di "========================================="

exit, clear
