/* ================================================================
   Additional analysis: Party membership and military service
   CGSS 2008 (county-level treatment) + CGSS 2003 / CGSS 2006
   (province-level treatment; those files lack county IDs).

   Columns:
     (1) CGSS 2003 CCP member     [province IHS]
     (2) CGSS 2006 CCP member     [province IHS]
     (3) CGSS 2008 CCP member     [county IHS]
     (4) CGSS 2003 Military       [province IHS]
     (5) CGSS 2006 Military       [province IHS]
   Panels A/B: IHS(rate) vs above-median dummy.
   CGSS 2008 has no military-service variable — hence the asymmetry.
   ================================================================ */

clear all
set more off
set maxvar 10000

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global outdir "${proj}/paper/assets/tables"

capture which reghdfejl
if _rc != 0 ssc install reghdfejl, replace

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*--- county-level treatment file (for CGSS 2008)
tempfile county_treat
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
summ martyr_count, detail
gen county_high = (martyr_count > r(p50)) if !missing(martyr_count)
keep countyid_curr6 ihs_rate county_high
save `county_treat'

*--- province-level treatment (for CGSS 2003/2006)
tempfile prov_treat prov_map
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_raw
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
gen str2 prov_code = substr(countyid_curr6, 1, 2)
collapse (mean) prov_ihs_rate=ihs_rate prov_martyr_rate=martyr_per100k_1953, by(prov_code)
summ prov_martyr_rate, detail
gen prov_high = (prov_martyr_rate > r(p50)) if !missing(prov_martyr_rate)
save `prov_treat'

clear
input str30 prov_name str2 prov_code
"北京" "11"
"北京市" "11"
"天津" "12"
"天津市" "12"
"河北" "13"
"河北省" "13"
"山西" "14"
"山西省" "14"
"内蒙古" "15"
"内蒙古自治区" "15"
"辽宁" "21"
"辽宁省" "21"
"吉林" "22"
"吉林省" "22"
"黑龙江" "23"
"黑龙江省" "23"
"上海" "31"
"上海市" "31"
"江苏" "32"
"江苏省" "32"
"浙江" "33"
"浙江省" "33"
"安徽" "34"
"安徽省" "34"
"福建" "35"
"福建省" "35"
"江西" "36"
"江西省" "36"
"山东" "37"
"山东省" "37"
"河南" "41"
"河南省" "41"
"湖北" "42"
"湖北省" "42"
"湖南" "43"
"湖南省" "43"
"广东" "44"
"广东省" "44"
"广西" "45"
"广西自治区" "45"
"广西壮族自治区" "45"
"海南" "46"
"海南省" "46"
"重庆" "50"
"重庆市" "50"
"四川" "51"
"四川省" "51"
"贵州" "52"
"贵州省" "52"
"云南" "53"
"云南省" "53"
"西藏" "54"
"西藏自治区" "54"
"陕西" "61"
"陕西省" "61"
"甘肃" "62"
"甘肃省" "62"
"青海" "63"
"青海省" "63"
"宁夏" "64"
"宁夏自治区" "64"
"新疆" "65"
"新疆自治区" "65"
"新疆维吾尔族自治区" "65"
end
duplicates drop prov_name, force
save `prov_map'

*=============================================================
* CGSS 2003 (province-level treatment)
*=============================================================
use "${proj}/data/raw/2003/原始数据（stata14.0版本）/cgss2003_14.dta", clear
capture decode province, gen(prov_name)
if _rc != 0 gen prov_name = province
merge m:1 prov_name using `prov_map', keep(match) nogen
merge m:1 prov_code using `prov_treat', keep(match) nogen

gen birth_i = floor(birth)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940
capture gen female = (sex == 2) if inlist(sex, 1, 2)
if _rc != 0 gen female = 0
capture gen minority = (race != 1) if inrange(race, 1, 56)
if _rc != 0 gen minority = 0
capture gen rural_hk = (hktype == 1) if inrange(hktype, 1, 4)
if _rc != 0 gen rural_hk = 0
destring prov_code, gen(prov_num)
gen is_party = (party == 1) if inlist(party, 1, 2)
gen military = (army == 1) if inlist(army, 0, 1)

reghdfejl is_party c.prov_ihs_rate##ib0.post female minority rural_hk, absorb(prov_num birth_i) vce(cluster prov_num)
local b_ihs_1 = _b[1.post#c.prov_ihs_rate]
local se_ihs_1 = _se[1.post#c.prov_ihs_rate]
local p_ihs_1 = 2*ttail(e(df_r), abs(`b_ihs_1'/`se_ihs_1'))
local n_ihs_1 = e(N)

reghdfejl is_party i.prov_high##ib0.post female minority rural_hk, absorb(prov_num birth_i) vce(cluster prov_num)
local b_dum_1 = _b[1.prov_high#1.post]
local se_dum_1 = _se[1.prov_high#1.post]
local p_dum_1 = 2*ttail(e(df_r), abs(`b_dum_1'/`se_dum_1'))
local n_dum_1 = e(N)

reghdfejl military c.prov_ihs_rate##ib0.post female minority rural_hk, absorb(prov_num birth_i) vce(cluster prov_num)
local b_ihs_4 = _b[1.post#c.prov_ihs_rate]
local se_ihs_4 = _se[1.post#c.prov_ihs_rate]
local p_ihs_4 = 2*ttail(e(df_r), abs(`b_ihs_4'/`se_ihs_4'))
local n_ihs_4 = e(N)

reghdfejl military i.prov_high##ib0.post female minority rural_hk, absorb(prov_num birth_i) vce(cluster prov_num)
local b_dum_4 = _b[1.prov_high#1.post]
local se_dum_4 = _se[1.prov_high#1.post]
local p_dum_4 = 2*ttail(e(df_r), abs(`b_dum_4'/`se_dum_4'))
local n_dum_4 = e(N)

*=============================================================
* CGSS 2006 (province-level treatment)
*=============================================================
use "${proj}/data/raw/2006/城市卷+农村卷原始数据（Stata14.0 版本）/cgss2006_14.dta", clear
capture decode province, gen(prov_name)
if _rc != 0 gen prov_name = province
merge m:1 prov_name using `prov_map', keep(match) nogen
merge m:1 prov_code using `prov_treat', keep(match) nogen

gen birth_i = year(qa02)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940
gen female = (qa01 == 2) if inlist(qa01, 1, 2)
capture gen rural_hk = (qa03a == 1) if inrange(qa03a, 1, 5)
if _rc != 0 gen rural_hk = 0
capture gen minority = (qa04 != 1) if inrange(qa04, 1, 56)
if _rc != 0 gen minority = 0
destring prov_code, gen(prov_num)
gen is_party = (qa08a == 1) if inrange(qa08a, 1, 4)
gen military = (qa11 == 1) if inlist(qa11, 1, 2)

reghdfejl is_party c.prov_ihs_rate##ib0.post female minority rural_hk, absorb(prov_num birth_i) vce(cluster prov_num)
local b_ihs_2 = _b[1.post#c.prov_ihs_rate]
local se_ihs_2 = _se[1.post#c.prov_ihs_rate]
local p_ihs_2 = 2*ttail(e(df_r), abs(`b_ihs_2'/`se_ihs_2'))
local n_ihs_2 = e(N)

reghdfejl is_party i.prov_high##ib0.post female minority rural_hk, absorb(prov_num birth_i) vce(cluster prov_num)
local b_dum_2 = _b[1.prov_high#1.post]
local se_dum_2 = _se[1.prov_high#1.post]
local p_dum_2 = 2*ttail(e(df_r), abs(`b_dum_2'/`se_dum_2'))
local n_dum_2 = e(N)

reghdfejl military c.prov_ihs_rate##ib0.post female minority rural_hk, absorb(prov_num birth_i) vce(cluster prov_num)
local b_ihs_5 = _b[1.post#c.prov_ihs_rate]
local se_ihs_5 = _se[1.post#c.prov_ihs_rate]
local p_ihs_5 = 2*ttail(e(df_r), abs(`b_ihs_5'/`se_ihs_5'))
local n_ihs_5 = e(N)

reghdfejl military i.prov_high##ib0.post female minority rural_hk, absorb(prov_num birth_i) vce(cluster prov_num)
local b_dum_5 = _b[1.prov_high#1.post]
local se_dum_5 = _se[1.prov_high#1.post]
local p_dum_5 = 2*ttail(e(df_r), abs(`b_dum_5'/`se_dum_5'))
local n_dum_5 = e(N)

*=============================================================
* CGSS 2008 (county-level treatment) — party only
*=============================================================
use serial countyid a1 a2 a6 a10 a14a a14d using "${proj}/data/raw/cgss2008_14.dta", clear
gen str6 countyid_curr6 = string(countyid, "%06.0f")
merge m:1 countyid_curr6 using `county_treat', keep(match) nogen

gen birth_i = floor(a2)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940
gen female = (a1 == 2) if inlist(a1, 1, 2)
gen minority = (a6 != 1) if inrange(a6, 1, 56)
gen rural_hk = (a14a == 6) if inrange(a14a, 1, 6)
egen county_num = group(countyid_curr6)

* Party membership: a10 = 4 (党员) → 1 ; others → 0
tab a10, missing nolabel
gen is_party = (a10 == 4) if inrange(a10, 1, 4)

reghdfejl is_party c.ihs_rate##ib0.post female minority rural_hk, absorb(county_num birth_i) vce(cluster county_num)
local b_ihs_3 = _b[1.post#c.ihs_rate]
local se_ihs_3 = _se[1.post#c.ihs_rate]
local p_ihs_3 = 2*ttail(e(df_r), abs(`b_ihs_3'/`se_ihs_3'))
local n_ihs_3 = e(N)

reghdfejl is_party i.county_high##ib0.post female minority rural_hk, absorb(county_num birth_i) vce(cluster county_num)
local b_dum_3 = _b[1.county_high#1.post]
local se_dum_3 = _se[1.county_high#1.post]
local p_dum_3 = 2*ttail(e(df_r), abs(`b_dum_3'/`se_dum_3'))
local n_dum_3 = e(N)

*=============================================================
* Output 5-column table
*=============================================================
tempname fh
file open `fh' using "${outdir}/additional_party_military_v2.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{5}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{3}{c}{CCP Membership}&\multicolumn{2}{c}{Military Service}\\" _n
file write `fh' "\cmidrule(lr){2-4}\cmidrule(lr){5-6}" _n
file write `fh' "            &(1)&(2)&(3)&(4)&(5)\\" _n
file write `fh' "            &CGSS 2003&CGSS 2006&CGSS 2008&CGSS 2003&CGSS 2006\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{6}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n

forvalues j = 1/5 {
    _stars `p_ihs_`j''
    local s_`j' "`r(star)'"
    local fb_`j' : di %9.4f `b_ihs_`j''
    local fse_`j' : di %7.4f `se_ihs_`j''
    local fn_ihs_`j' : di %12.0fc `n_ihs_`j''
}
file write `fh' "Post \$\times\$ IHS(rate)&`fb_1'\sym{`s_1'}&`fb_2'\sym{`s_2'}&`fb_3'\sym{`s_3'}&`fb_4'\sym{`s_4'}&`fb_5'\sym{`s_5'}\\" _n
file write `fh' "            &(`fse_1')&(`fse_2')&(`fse_3')&(`fse_4')&(`fse_5')\\[0.5em]" _n

file write `fh' "\multicolumn{6}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
forvalues j = 1/5 {
    _stars `p_dum_`j''
    local s_`j' "`r(star)'"
    local fb_`j' : di %9.4f `b_dum_`j''
    local fse_`j' : di %7.4f `se_dum_`j''
    local fn_dum_`j' : di %12.0fc `n_dum_`j''
}
file write `fh' "Post \$\times\$ High&`fb_1'\sym{`s_1'}&`fb_2'\sym{`s_2'}&`fb_3'\sym{`s_3'}&`fb_4'\sym{`s_4'}&`fb_5'\sym{`s_5'}\\" _n
file write `fh' "            &(`fse_1')&(`fse_2')&(`fse_3')&(`fse_4')&(`fse_5')\\" _n
file write `fh' "\midrule" _n
file write `fh' "Individual controls&\multicolumn{5}{c}{Yes}\\" _n
file write `fh' "Region FE&Prov.&Prov.&County&Prov.&Prov.\\" _n
file write `fh' "Cohort FE&\multicolumn{5}{c}{Yes}\\" _n
file write `fh' "Observations&`fn_ihs_1'&`fn_ihs_2'&`fn_ihs_3'&`fn_ihs_4'&`fn_ihs_5'\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

di "=== Additional analysis party/military v2 table written ==="
exit, clear
