/* ================================================================
   CGSS 2003/2005/2006 Mechanism Regressions
   Province-level treatment (CGSS 03/05/06 lack county identifiers)

   Mechanism 2: Spiritual Inheritance
   - Party membership
   - Military service (2003, 2006 only)
   - Social participation / organization membership
   - Education attitudes / equal opportunity beliefs
   - Government trust (2006)
   - Voting / political participation
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

* ================================================================
* Step 1: Build province-level treatment
* ================================================================
di "Building province-level treatment..."
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 martyr_per100k_1953 ln_martyr_raw

gen martyr_count = round(exp(ln_martyr_raw) - 1) if ln_martyr_raw > 0
replace martyr_count = 0 if missing(martyr_count)
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)

* Get province code from first 2 digits
gen str2 prov_code = substr(countyid_curr6, 1, 2)

* Aggregate to province level
collapse (mean) prov_ihs_rate=ihs_rate prov_martyr_rate=martyr_per100k_1953, by(prov_code)

* Create province-level dummy
summ prov_martyr_rate, detail
gen prov_high = (prov_martyr_rate > r(p50)) if !missing(prov_martyr_rate)

di "Province-level treatment:"
list prov_code prov_ihs_rate prov_martyr_rate prov_high, noobs

save "${proj}/data/temp/_prov_treat_tmp.dta", replace
global prov_treat_file "${proj}/data/temp/_prov_treat_tmp.dta"

* ================================================================
* Create province code mapping for CGSS string names
* ================================================================
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
save "${proj}/data/temp/_prov_map_tmp.dta", replace
global prov_map_file "${proj}/data/temp/_prov_map_tmp.dta"

* ================================================================
*  CGSS 2003
* ================================================================
di ""
di "========================================"
di "  CGSS 2003 MECHANISM"
di "========================================"

use "${proj}/data/raw/2003/原始数据（stata14.0版本）/cgss2003_14.dta", clear

* Map province to code — province may be encoded numeric, decode first
capture decode province, gen(prov_name)
if _rc != 0 {
    * Already string
    gen prov_name = province
}
merge m:1 prov_name using "$prov_map_file", keep(match) nogen

* Merge treatment
merge m:1 prov_code using "$prov_treat_file", keep(match) nogen

* Demographics
gen birth_i = floor(birth)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940

* 2003 has sex, race, hktype as numeric
capture confirm numeric variable sex
if _rc == 0 {
    gen female = (sex == 2) if inlist(sex, 1, 2)
}
else {
    gen female = 0
}
capture confirm numeric variable race
if _rc == 0 {
    gen minority = (race != 1) if inrange(race, 1, 56)
}
else {
    gen minority = 0
}
capture confirm numeric variable hktype
if _rc == 0 {
    gen rural_hk = (hktype == 1) if inrange(hktype, 1, 4)
}
else {
    gen rural_hk = 0
}

destring prov_code, gen(prov_num)

* ---- Outcome variables ----

* 1. Party membership
gen is_party = (party == 1) if inlist(party, 0, 1)
label var is_party "CCP member"

* 2. Military service
gen military = (army == 1) if inlist(army, 0, 1)
label var military "Military service"

* 3. Trust in strangers
gen trust_stranger = truststr if inrange(truststr, 1, 5)
label var trust_stranger "Trust strangers (1-5)"

* 4. Election participation
gen voted = (ncelect == 1) if inlist(ncelect, 0, 1)
label var voted "Voted in election"

* 5. Equal education opportunity (升学机会平等)
gen edu_equal = sopport if inrange(sopport, 1, 5)
* Recode so higher = more agreement
replace edu_equal = 6 - edu_equal
label var edu_equal "Equal edu opportunity (1-5)"

* 6. Social mobility belief
gen mobility = srich if inrange(srich, 1, 5)
replace mobility = 6 - mobility
label var mobility "Mobility belief (1-5)"

* 7. Education important for life
gen edu_important = ordedu if inrange(ordedu, 1, 5)
replace edu_important = 6 - edu_important
label var edu_important "Education importance (1-5)"

local outcomes_03 "is_party military trust_stranger voted edu_equal mobility edu_important"
local titles_03 `" "Party" "Military" "Trust" "Voted" "Edu equal" "Mobility" "Edu import" "'

local m = 0
foreach yvar of local outcomes_03 {
    local m = `m' + 1
    di "=== 2003 IHS: `yvar' ==="
    capture {
        reghdfejl `yvar' c.prov_ihs_rate##ib0.post female minority rural_hk, ///
            absorb(prov_num birth_i) vce(cluster prov_num)
        local b_ihs_03_`m' = _b[1.post#c.prov_ihs_rate]
        local se_ihs_03_`m' = _se[1.post#c.prov_ihs_rate]
        local p_ihs_03_`m' = 2*ttail(e(df_r), abs(`b_ihs_03_`m''/`se_ihs_03_`m''))
        local n_ihs_03_`m' = e(N)
    }
    if _rc != 0 {
        local b_ihs_03_`m' = .
        local se_ihs_03_`m' = .
        local p_ihs_03_`m' = 1
        local n_ihs_03_`m' = 0
    }

    di "=== 2003 Dummy: `yvar' ==="
    capture {
        reghdfejl `yvar' i.prov_high##ib0.post female minority rural_hk, ///
            absorb(prov_num birth_i) vce(cluster prov_num)
        local b_dum_03_`m' = _b[1.prov_high#1.post]
        local se_dum_03_`m' = _se[1.prov_high#1.post]
        local p_dum_03_`m' = 2*ttail(e(df_r), abs(`b_dum_03_`m''/`se_dum_03_`m''))
        local n_dum_03_`m' = e(N)
    }
    if _rc != 0 {
        local b_dum_03_`m' = .
        local se_dum_03_`m' = .
        local p_dum_03_`m' = 1
        local n_dum_03_`m' = 0
    }
}

* ================================================================
*  CGSS 2005
* ================================================================
di ""
di "========================================"
di "  CGSS 2005 MECHANISM"
di "========================================"

use "${proj}/data/raw/2005/原始数据（stata14.0版本）/cgss2005_14.dta", clear

capture decode qs2a, gen(prov_name)
if _rc != 0 gen prov_name = qs2a
merge m:1 prov_name using "$prov_map_file", keep(match) nogen
merge m:1 prov_code using "$prov_treat_file", keep(match) nogen

gen birth_i = floor(qa3_01)
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940

* 2005: qa1 is sex (might be named qa1_01 or qa01)
capture gen female = (qa1 == 2) if inlist(qa1, 1, 2)
if _rc != 0 {
    capture gen female = (qa01 == 2) if inlist(qa01, 1, 2)
    if _rc != 0 gen female = 0
}
capture gen rural_hk = (qa5_01 == 1) if inrange(qa5_01, 1, 4)
if _rc != 0 gen rural_hk = 0
gen minority = 0  /* 2005 doesn't have clear ethnic var */

destring prov_code, gen(prov_num)

* ---- Outcome variables ----

* 1. Party membership
gen is_party = (qb04a == 1) if inlist(qb04a, 1, 2)
label var is_party "CCP member"

* 2. Social org participation (any of qe18a-g)
gen social_org = 0
forvalues j = 1/7 {
    local letter : word `j' of a b c d e f g
    capture replace social_org = 1 if qe18`letter' == 1
}
label var social_org "Social org participation"

* 3. Voted in local election (qf03: 人大, qf05: 居委会/村委会)
gen voted_pc = (qf03 == 1) if inlist(qf03, 1, 2, 3)
label var voted_pc "Voted (People's Congress)"
gen voted_local = (qf05 == 1) if inlist(qf05, 1, 2, 3)
label var voted_local "Voted (local committee)"

* 4. Education equal opportunity (qf14c)
gen edu_equal = qf14c if inrange(qf14c, 1, 5)
replace edu_equal = 6 - edu_equal  /* higher = more agreement */
label var edu_equal "Equal edu opportunity"

* 5. Gov should increase edu spending (qf15c)
gen gov_edu_spend = qf15c if inrange(qf15c, 1, 5)
replace gov_edu_spend = 6 - gov_edu_spend  /* higher = more spending */
label var gov_edu_spend "Gov edu spending (should increase)"

* 6. Social mobility (qf14d)
gen mobility = qf14d if inrange(qf14d, 1, 5)
replace mobility = 6 - mobility
label var mobility "Mobility belief"

* 7. Trust in strangers (qe14a = trust in society generally)
gen trust_stranger = qe14a if inrange(qe14a, 1, 4)
label var trust_stranger "Trust strangers"

local outcomes_05 "is_party social_org voted_pc voted_local edu_equal gov_edu_spend mobility"
local titles_05 `" "Party" "Social org" "Voted PC" "Voted local" "Edu equal" "Gov edu" "Mobility" "'

local m = 0
foreach yvar of local outcomes_05 {
    local m = `m' + 1
    di "=== 2005 IHS: `yvar' ==="
    capture {
        reghdfejl `yvar' c.prov_ihs_rate##ib0.post female minority rural_hk, ///
            absorb(prov_num birth_i) vce(cluster prov_num)
        local b_ihs_05_`m' = _b[1.post#c.prov_ihs_rate]
        local se_ihs_05_`m' = _se[1.post#c.prov_ihs_rate]
        local p_ihs_05_`m' = 2*ttail(e(df_r), abs(`b_ihs_05_`m''/`se_ihs_05_`m''))
        local n_ihs_05_`m' = e(N)
    }
    if _rc != 0 {
        local b_ihs_05_`m' = .
        local se_ihs_05_`m' = .
        local p_ihs_05_`m' = 1
        local n_ihs_05_`m' = 0
    }

    di "=== 2005 Dummy: `yvar' ==="
    capture {
        reghdfejl `yvar' i.prov_high##ib0.post female minority rural_hk, ///
            absorb(prov_num birth_i) vce(cluster prov_num)
        local b_dum_05_`m' = _b[1.prov_high#1.post]
        local se_dum_05_`m' = _se[1.prov_high#1.post]
        local p_dum_05_`m' = 2*ttail(e(df_r), abs(`b_dum_05_`m''/`se_dum_05_`m''))
        local n_dum_05_`m' = e(N)
    }
    if _rc != 0 {
        local b_dum_05_`m' = .
        local se_dum_05_`m' = .
        local p_dum_05_`m' = 1
        local n_dum_05_`m' = 0
    }
}

* ================================================================
*  CGSS 2006
* ================================================================
di ""
di "========================================"
di "  CGSS 2006 MECHANISM"
di "========================================"

use "${proj}/data/raw/2006/城市卷+农村卷原始数据（Stata14.0 版本）/cgss2006_14.dta", clear

capture decode province, gen(prov_name)
if _rc != 0 gen prov_name = province
merge m:1 prov_name using "$prov_map_file", keep(match) nogen
merge m:1 prov_code using "$prov_treat_file", keep(match) nogen

* qa02 is a Stata td date (%tdD_m_Y), extract year
gen birth_i = year(qa02)
di "birth_i range: "
summ birth_i
keep if inrange(birth_i, 1920, 1990)
drop if birth_i == 1939
gen post = birth_i >= 1940

gen female = (qa01 == 2) if inlist(qa01, 1, 2)
capture gen rural_hk = (qa03a == 1) if inrange(qa03a, 1, 5)
if _rc != 0 gen rural_hk = 0
capture gen minority = (qa04 != 1) if inrange(qa04, 1, 56)
if _rc != 0 gen minority = 0

destring prov_code, gen(prov_num)

* ---- Outcome variables ----

* 1. Party membership
gen is_party = (qa08a == 1) if inrange(qa08a, 1, 4)
label var is_party "CCP member"

* 2. Military service
gen military = (qa11 == 1) if inlist(qa11, 1, 2)
label var military "Military service"

* 3. Organization membership (qe33)
gen org_member = (qe33 == 1) if inlist(qe33, 1, 2)
label var org_member "Organization member"

* 4. Voted in election (qe451)
gen voted = (qe451 == 1) if inlist(qe451, 0, 1)
label var voted "Voted (People's Congress)"

* 5. Education spending (qd37d - household edu spending)
gen ln_edu_spend = ln(qd37d + 1) if qd37d >= 0 & !missing(qd37d)
label var ln_edu_spend "ln(HH edu spending + 1)"

* 6. Success factor: own education (qe0103)
gen edu_success = qe0103 if inrange(qe0103, 1, 5)
label var edu_success "Edu important for success"

* 7. Success factor: hard work (qe0110)
gen hardwork_success = qe0110 if inrange(qe0110, 1, 5)
label var hardwork_success "Hard work for success"

* 8. Success factor: connections (qe0111) — expect negative
gen connections_success = qe0111 if inrange(qe0111, 1, 5)
label var connections_success "Connections for success"

* 9. Government trust (average of qe3911-qe3918)
egen gov_trust = rowmean(qe3911 qe3912 qe3913 qe3914 qe3915 qe3916 qe3917 qe3918)
label var gov_trust "Government trust index"

* 10. Poverty = lack education (qe4705)
gen poverty_edu = qe4705 if inrange(qe4705, 1, 5)
label var poverty_edu "Poverty due to lack edu"

local outcomes_06 "is_party military org_member voted ln_edu_spend edu_success hardwork_success connections_success gov_trust poverty_edu"
local titles_06 `" "Party" "Military" "Org member" "Voted" "ln(Edu spend)" "Edu success" "Hard work" "Connections" "Gov trust" "Poverty=edu" "'

local m = 0
foreach yvar of local outcomes_06 {
    local m = `m' + 1
    di "=== 2006 IHS: `yvar' ==="
    capture {
        reghdfejl `yvar' c.prov_ihs_rate##ib0.post female minority rural_hk, ///
            absorb(prov_num birth_i) vce(cluster prov_num)
        local b_ihs_06_`m' = _b[1.post#c.prov_ihs_rate]
        local se_ihs_06_`m' = _se[1.post#c.prov_ihs_rate]
        local p_ihs_06_`m' = 2*ttail(e(df_r), abs(`b_ihs_06_`m''/`se_ihs_06_`m''))
        local n_ihs_06_`m' = e(N)
    }
    if _rc != 0 {
        local b_ihs_06_`m' = .
        local se_ihs_06_`m' = .
        local p_ihs_06_`m' = 1
        local n_ihs_06_`m' = 0
    }

    di "=== 2006 Dummy: `yvar' ==="
    capture {
        reghdfejl `yvar' i.prov_high##ib0.post female minority rural_hk, ///
            absorb(prov_num birth_i) vce(cluster prov_num)
        local b_dum_06_`m' = _b[1.prov_high#1.post]
        local se_dum_06_`m' = _se[1.prov_high#1.post]
        local p_dum_06_`m' = 2*ttail(e(df_r), abs(`b_dum_06_`m''/`se_dum_06_`m''))
        local n_dum_06_`m' = e(N)
    }
    if _rc != 0 {
        local b_dum_06_`m' = .
        local se_dum_06_`m' = .
        local p_dum_06_`m' = 1
        local n_dum_06_`m' = 0
    }
}

* ================================================================
* OUTPUT TABLES
* ================================================================

* --- CGSS 2003 Table ---
tempname fh
file open `fh' using "${outdir}/mechanism_cgss2003_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{7}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}\\" _n
file write `fh' "            &Party&Military&Trust&Voted&Edu equal&Mobility&Edu import\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{8}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n

_stars `p_ihs_03_1'
file write `fh' "Post $\times$ IHS(rate)&" %9.4f (`b_ihs_03_1') "\sym{`r(star)'}"
forvalues j = 2/7 {
    _stars `p_ihs_03_`j''
    file write `fh' "&" %9.4f (`b_ihs_03_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_ihs_03_1') ")"
forvalues j = 2/7 {
    file write `fh' "&(" %7.4f (`se_ihs_03_`j'') ")"
}
file write `fh' "\\[0.5em]" _n
file write `fh' "\multicolumn{8}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
_stars `p_dum_03_1'
file write `fh' "Post $\times$ High&" %9.4f (`b_dum_03_1') "\sym{`r(star)'}"
forvalues j = 2/7 {
    _stars `p_dum_03_`j''
    file write `fh' "&" %9.4f (`b_dum_03_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_dum_03_1') ")"
forvalues j = 2/7 {
    file write `fh' "&(" %7.4f (`se_dum_03_`j'') ")"
}
file write `fh' "\\" _n
file write `fh' "\midrule" _n
file write `fh' "Individual controls&\multicolumn{7}{c}{Yes}\\" _n
file write `fh' "Province FE&\multicolumn{7}{c}{Yes}\\" _n
file write `fh' "Cohort FE&\multicolumn{7}{c}{Yes}\\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_ihs_03_1')
forvalues j = 2/7 {
    file write `fh' "&" %12.0fc (`n_ihs_03_`j'')
}
file write `fh' "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== CGSS 2003 table saved ==="

* --- CGSS 2005 Table ---
tempname fh
file open `fh' using "${outdir}/mechanism_cgss2005_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{7}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}&\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}\\" _n
file write `fh' "            &Party&Social org&Voted PC&Voted local&Edu equal&Gov edu&Mobility\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{8}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
_stars `p_ihs_05_1'
file write `fh' "Post $\times$ IHS(rate)&" %9.4f (`b_ihs_05_1') "\sym{`r(star)'}"
forvalues j = 2/7 {
    _stars `p_ihs_05_`j''
    file write `fh' "&" %9.4f (`b_ihs_05_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_ihs_05_1') ")"
forvalues j = 2/7 {
    file write `fh' "&(" %7.4f (`se_ihs_05_`j'') ")"
}
file write `fh' "\\[0.5em]" _n
file write `fh' "\multicolumn{8}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
_stars `p_dum_05_1'
file write `fh' "Post $\times$ High&" %9.4f (`b_dum_05_1') "\sym{`r(star)'}"
forvalues j = 2/7 {
    _stars `p_dum_05_`j''
    file write `fh' "&" %9.4f (`b_dum_05_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_dum_05_1') ")"
forvalues j = 2/7 {
    file write `fh' "&(" %7.4f (`se_dum_05_`j'') ")"
}
file write `fh' "\\" _n
file write `fh' "\midrule" _n
file write `fh' "Individual controls&\multicolumn{7}{c}{Yes}\\" _n
file write `fh' "Province FE&\multicolumn{7}{c}{Yes}\\" _n
file write `fh' "Cohort FE&\multicolumn{7}{c}{Yes}\\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_ihs_05_1')
forvalues j = 2/7 {
    file write `fh' "&" %12.0fc (`n_ihs_05_`j'')
}
file write `fh' "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== CGSS 2005 table saved ==="

* --- CGSS 2006 Table (10 outcomes, split into 2 tables) ---
* Table A: First 5 outcomes
tempname fh
file open `fh' using "${outdir}/mechanism_cgss2006a_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{5}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}&\multicolumn{1}{c}{(4)}&\multicolumn{1}{c}{(5)}\\" _n
file write `fh' "            &Party&Military&Org member&Voted&ln(Edu spend)\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{6}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
_stars `p_ihs_06_1'
file write `fh' "Post $\times$ IHS(rate)&" %9.4f (`b_ihs_06_1') "\sym{`r(star)'}"
forvalues j = 2/5 {
    _stars `p_ihs_06_`j''
    file write `fh' "&" %9.4f (`b_ihs_06_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_ihs_06_1') ")"
forvalues j = 2/5 {
    file write `fh' "&(" %7.4f (`se_ihs_06_`j'') ")"
}
file write `fh' "\\[0.5em]" _n
file write `fh' "\multicolumn{6}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
_stars `p_dum_06_1'
file write `fh' "Post $\times$ High&" %9.4f (`b_dum_06_1') "\sym{`r(star)'}"
forvalues j = 2/5 {
    _stars `p_dum_06_`j''
    file write `fh' "&" %9.4f (`b_dum_06_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_dum_06_1') ")"
forvalues j = 2/5 {
    file write `fh' "&(" %7.4f (`se_dum_06_`j'') ")"
}
file write `fh' "\\" _n
file write `fh' "\midrule" _n
file write `fh' "Individual controls&\multicolumn{5}{c}{Yes}\\" _n
file write `fh' "Province FE&\multicolumn{5}{c}{Yes}\\" _n
file write `fh' "Cohort FE&\multicolumn{5}{c}{Yes}\\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_ihs_06_1')
forvalues j = 2/5 {
    file write `fh' "&" %12.0fc (`n_ihs_06_`j'')
}
file write `fh' "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== CGSS 2006 table A saved ==="

* Table B: Last 5 outcomes
tempname fh
file open `fh' using "${outdir}/mechanism_cgss2006b_v1.tex", write replace
file write `fh' "{" _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}" _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{5}{c}}" _n
file write `fh' "\toprule" _n
file write `fh' "            &\multicolumn{1}{c}{(6)}&\multicolumn{1}{c}{(7)}&\multicolumn{1}{c}{(8)}&\multicolumn{1}{c}{(9)}&\multicolumn{1}{c}{(10)}\\" _n
file write `fh' "            &Edu success&Hard work&Connections&Gov trust&Poverty=edu\\" _n
file write `fh' "\midrule" _n
file write `fh' "\multicolumn{6}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
_stars `p_ihs_06_6'
file write `fh' "Post $\times$ IHS(rate)&" %9.4f (`b_ihs_06_6') "\sym{`r(star)'}"
forvalues j = 7/10 {
    _stars `p_ihs_06_`j''
    file write `fh' "&" %9.4f (`b_ihs_06_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_ihs_06_6') ")"
forvalues j = 7/10 {
    file write `fh' "&(" %7.4f (`se_ihs_06_`j'') ")"
}
file write `fh' "\\[0.5em]" _n
file write `fh' "\multicolumn{6}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
_stars `p_dum_06_6'
file write `fh' "Post $\times$ High&" %9.4f (`b_dum_06_6') "\sym{`r(star)'}"
forvalues j = 7/10 {
    _stars `p_dum_06_`j''
    file write `fh' "&" %9.4f (`b_dum_06_`j'') "\sym{`r(star)'}"
}
file write `fh' "\\" _n
file write `fh' "            &(" %7.4f (`se_dum_06_6') ")"
forvalues j = 7/10 {
    file write `fh' "&(" %7.4f (`se_dum_06_`j'') ")"
}
file write `fh' "\\" _n
file write `fh' "\midrule" _n
file write `fh' "Individual controls&\multicolumn{5}{c}{Yes}\\" _n
file write `fh' "Province FE&\multicolumn{5}{c}{Yes}\\" _n
file write `fh' "Cohort FE&\multicolumn{5}{c}{Yes}\\" _n
file write `fh' "Obs (IHS)&" %12.0fc (`n_ihs_06_6')
forvalues j = 7/10 {
    file write `fh' "&" %12.0fc (`n_ihs_06_`j'')
}
file write `fh' "\\" _n
file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular*}" _n
file write `fh' "}" _n
file close `fh'
di "=== CGSS 2006 table B saved ==="

di ""
di "========================================="
di "  ALL CGSS 2003/2005/2006 MECHANISM REGRESSIONS COMPLETE"
di "========================================="

exit, clear
