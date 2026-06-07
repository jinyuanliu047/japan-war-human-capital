/* ================================================================
   Appendix: Party membership and military service
   Pulls CGSS 2003 (party + military) and CGSS 2006 (party + military)
   Province-level treatment (IHS rate and above-median dummy).

   Outputs a single appendix table with 4 columns:
     (1) CGSS 2003: CCP member
     (2) CGSS 2003: Military service
     (3) CGSS 2006: CCP member
     (4) CGSS 2006: Military service
   Two panels (IHS, Dummy).
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

*--- province-level treatment
tempfile prov_treat prov_map
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_raw
gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
gen str2 prov_code = substr(countyid_curr6, 1, 2)
collapse (mean) prov_ihs_rate=ihs_rate prov_martyr_rate=martyr_per100k_1953, by(prov_code)
summ prov_martyr_rate, detail
gen prov_high = (prov_martyr_rate > r(p50)) if !missing(prov_martyr_rate)
save `prov_treat'

*--- province-name to code map
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
* CGSS 2003
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

capture confirm numeric variable sex
if _rc == 0 gen female = (sex == 2) if inlist(sex, 1, 2)
else gen female = 0
capture confirm numeric variable race
if _rc == 0 gen minority = (race != 1) if inrange(race, 1, 56)
else gen minority = 0
capture confirm numeric variable hktype
if _rc == 0 gen rural_hk = (hktype == 1) if inrange(hktype, 1, 4)
else gen rural_hk = 0

destring prov_code, gen(prov_num)
di "--- CGSS 2003 party/army raw codes ---"
tab party, missing nolabel
tab army, missing nolabel
gen is_party = (party == 1) if inlist(party, 1, 2)
gen military = (army == 1) if inlist(army, 0, 1)

* 2003 party IHS
reghdfejl is_party c.prov_ihs_rate##ib0.post female minority rural_hk, ///
    absorb(prov_num birth_i) vce(cluster prov_num)
local b_ihs_1 = _b[1.post#c.prov_ihs_rate]
local se_ihs_1 = _se[1.post#c.prov_ihs_rate]
local p_ihs_1 = 2*ttail(e(df_r), abs(`b_ihs_1'/`se_ihs_1'))
local n_ihs_1 = e(N)

* 2003 party dummy
reghdfejl is_party i.prov_high##ib0.post female minority rural_hk, ///
    absorb(prov_num birth_i) vce(cluster prov_num)
local b_dum_1 = _b[1.prov_high#1.post]
local se_dum_1 = _se[1.prov_high#1.post]
local p_dum_1 = 2*ttail(e(df_r), abs(`b_dum_1'/`se_dum_1'))
local n_dum_1 = e(N)

* 2003 military IHS
reghdfejl military c.prov_ihs_rate##ib0.post female minority rural_hk, ///
    absorb(prov_num birth_i) vce(cluster prov_num)
local b_ihs_2 = _b[1.post#c.prov_ihs_rate]
local se_ihs_2 = _se[1.post#c.prov_ihs_rate]
local p_ihs_2 = 2*ttail(e(df_r), abs(`b_ihs_2'/`se_ihs_2'))
local n_ihs_2 = e(N)

* 2003 military dummy
reghdfejl military i.prov_high##ib0.post female minority rural_hk, ///
    absorb(prov_num birth_i) vce(cluster prov_num)
local b_dum_2 = _b[1.prov_high#1.post]
local se_dum_2 = _se[1.prov_high#1.post]
local p_dum_2 = 2*ttail(e(df_r), abs(`b_dum_2'/`se_dum_2'))
local n_dum_2 = e(N)

*=============================================================
* CGSS 2006
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

reghdfejl is_party c.prov_ihs_rate##ib0.post female minority rural_hk, ///
    absorb(prov_num birth_i) vce(cluster prov_num)
local b_ihs_3 = _b[1.post#c.prov_ihs_rate]
local se_ihs_3 = _se[1.post#c.prov_ihs_rate]
local p_ihs_3 = 2*ttail(e(df_r), abs(`b_ihs_3'/`se_ihs_3'))
local n_ihs_3 = e(N)

reghdfejl is_party i.prov_high##ib0.post female minority rural_hk, ///
    absorb(prov_num birth_i) vce(cluster prov_num)
local b_dum_3 = _b[1.prov_high#1.post]
local se_dum_3 = _se[1.prov_high#1.post]
local p_dum_3 = 2*ttail(e(df_r), abs(`b_dum_3'/`se_dum_3'))
local n_dum_3 = e(N)

reghdfejl military c.prov_ihs_rate##ib0.post female minority rural_hk, ///
    absorb(prov_num birth_i) vce(cluster prov_num)
local b_ihs_4 = _b[1.post#c.prov_ihs_rate]
local se_ihs_4 = _se[1.post#c.prov_ihs_rate]
local p_ihs_4 = 2*ttail(e(df_r), abs(`b_ihs_4'/`se_ihs_4'))
local n_ihs_4 = e(N)

reghdfejl military i.prov_high##ib0.post female minority rural_hk, ///
    absorb(prov_num birth_i) vce(cluster prov_num)
local b_dum_4 = _b[1.prov_high#1.post]
local se_dum_4 = _se[1.prov_high#1.post]
local p_dum_4 = 2*ttail(e(df_r), abs(`b_dum_4'/`se_dum_4'))
local n_dum_4 = e(N)

*=============================================================
* Output table
*=============================================================
tempname fh
file open `fh' using "${outdir}/appendix_party_military_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{4}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{2}{c}{CGSS 2003}&\multicolumn{2}{c}{CGSS 2006}\\" _n
file write `fh' "\cmidrule(lr){2-3}\cmidrule(lr){4-5}" _n
file write `fh' "            &(1) CCP member&(2) Military&(3) CCP member&(4) Military\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{5}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n

forvalues j = 1/4 {
    _stars `p_ihs_`j''
    local s_`j' "`r(star)'"
    local fb_`j' : di %9.4f `b_ihs_`j''
    local fse_`j' : di %7.4f `se_ihs_`j''
    local fn_`j' : di %12.0fc `n_ihs_`j''
}
file write `fh' "Post $\times$ IHS(rate)&`fb_1'\sym{`s_1'}&`fb_2'\sym{`s_2'}&`fb_3'\sym{`s_3'}&`fb_4'\sym{`s_4'}\\" _n
file write `fh' "            &(`fse_1')&(`fse_2')&(`fse_3')&(`fse_4')\\[0.5em]" _n

file write `fh' "\multicolumn{5}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
forvalues j = 1/4 {
    _stars `p_dum_`j''
    local s_`j' "`r(star)'"
    local fb_`j' : di %9.4f `b_dum_`j''
    local fse_`j' : di %7.4f `se_dum_`j''
    local fn_`j' : di %12.0fc `n_dum_`j''
}
file write `fh' "Post $\times$ High&`fb_1'\sym{`s_1'}&`fb_2'\sym{`s_2'}&`fb_3'\sym{`s_3'}&`fb_4'\sym{`s_4'}\\" _n
file write `fh' "            &(`fse_1')&(`fse_2')&(`fse_3')&(`fse_4')\\" _n
file write `fh' "\midrule" _n
file write `fh' "Individual controls&\multicolumn{4}{c}{Yes}\\" _n
file write `fh' "Province FE&\multicolumn{4}{c}{Yes}\\" _n
file write `fh' "Cohort FE&\multicolumn{4}{c}{Yes}\\" _n
file write `fh' "Observations&`fn_1'&`fn_2'&`fn_3'&`fn_4'\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'

di "=== Party/Military appendix table written ==="
exit, clear
