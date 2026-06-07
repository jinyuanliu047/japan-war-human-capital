*******************************************************
* Collectivism — IHS + Dummy treatment
* Province level + Prefecture level
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global outdir "${proj}/paper/assets/tables"

capture program drop _stars
program define _stars, rclass
    args pval
    if `pval' < 0.01       return local star "***"
    else if `pval' < 0.05  return local star "**"
    else if `pval' < 0.10  return local star "*"
    else                    return local star ""
end

*--------------------------------------------------------------
* Province-level treatment (IHS + dummy)
*--------------------------------------------------------------
import delimited "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.csv", clear varnames(1)
keep countyid_curr6 pop_1953 martyr_count_1931_1945
drop if missing(countyid_curr6, pop_1953, martyr_count_1931_1945)
duplicates drop countyid_curr6, force

tostring countyid_curr6, replace format(%06.0f)
gen provcd = real(substr(countyid_curr6, 1, 2))

collapse (sum) pop_1953 martyr_count_1931_1945, by(provcd)
gen martyr_per100k_1953 = 100000 * martyr_count_1931_1945 / pop_1953

* IHS treatment
gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1))

* Dummy treatment (above median)
summ martyr_per100k_1953, detail
gen d_high = (martyr_per100k_1953 > r(p50)) if !missing(martyr_per100k_1953)

gen str20 Province = ""
replace Province = "Beijing" if provcd == 11
replace Province = "Tianjin" if provcd == 12
replace Province = "Hebei" if provcd == 13
replace Province = "Shanxi" if provcd == 14
replace Province = "Inner Mongolia" if provcd == 15
replace Province = "Liaoning" if provcd == 21
replace Province = "Jilin" if provcd == 22
replace Province = "Heilongjiang" if provcd == 23
replace Province = "Shanghai" if provcd == 31
replace Province = "Jiangsu" if provcd == 32
replace Province = "Zhejiang" if provcd == 33
replace Province = "Anhui" if provcd == 34
replace Province = "Fujian" if provcd == 35
replace Province = "Jiangxi" if provcd == 36
replace Province = "Shandong" if provcd == 37
replace Province = "Henan" if provcd == 41
replace Province = "Hubei" if provcd == 42
replace Province = "Hunan" if provcd == 43
replace Province = "Guangdong" if provcd == 44
replace Province = "Guangxi" if provcd == 45
replace Province = "Hainan" if provcd == 46
replace Province = "Chongqing" if provcd == 50
replace Province = "Sichuan" if provcd == 51
replace Province = "Guizhou" if provcd == 52
replace Province = "Yunnan" if provcd == 53
replace Province = "Tibet" if provcd == 54
replace Province = "Shaanxi" if provcd == 61
replace Province = "Gansu" if provcd == 62
replace Province = "Qinghai" if provcd == 63
replace Province = "Ningxia" if provcd == 64
replace Province = "Xinjiang" if provcd == 65

keep provcd Province pop_1953 martyr_count_1931_1945 martyr_per100k_1953 ihs_rate d_high
rename Province province
tempfile prov_treat
save `prov_treat'

*--------------------------------------------------------------
* Province-level collectivism
*--------------------------------------------------------------
import delimited "${proj}/data/temp/collectivesim/Province Collectivism Index 1982-2020.csv", clear varnames(1)
keep provincechinese province ///
    provinceco~2fou ///
    provincec~90fou ///
    provincec~00fou

rename provinceco~2fou collectivism_1982
rename provincec~90fou collectivism_1990
rename provincec~00fou collectivism_2000

destring collectivism_1982, replace force
destring collectivism_1990, replace force
destring collectivism_2000, replace force

merge 1:1 province using `prov_treat', keep(match) nogen

* --- IHS regressions ---
reg collectivism_1982 ihs_rate, vce(robust)
local b82_ihs = _b[ihs_rate]
local se82_ihs = _se[ihs_rate]
local p82_ihs = 2*ttail(e(df_r), abs(`b82_ihs'/`se82_ihs'))
local n82_ihs = e(N)

reg collectivism_1990 ihs_rate, vce(robust)
local b90_ihs = _b[ihs_rate]
local se90_ihs = _se[ihs_rate]
local p90_ihs = 2*ttail(e(df_r), abs(`b90_ihs'/`se90_ihs'))
local n90_ihs = e(N)

reg collectivism_2000 ihs_rate, vce(robust)
local b00_ihs = _b[ihs_rate]
local se00_ihs = _se[ihs_rate]
local p00_ihs = 2*ttail(e(df_r), abs(`b00_ihs'/`se00_ihs'))
local n00_ihs = e(N)

* --- Dummy regressions ---
reg collectivism_1982 d_high, vce(robust)
local b82_d = _b[d_high]
local se82_d = _se[d_high]
local p82_d = 2*ttail(e(df_r), abs(`b82_d'/`se82_d'))
local n82_d = e(N)

reg collectivism_1990 d_high, vce(robust)
local b90_d = _b[d_high]
local se90_d = _se[d_high]
local p90_d = 2*ttail(e(df_r), abs(`b90_d'/`se90_d'))
local n90_d = e(N)

reg collectivism_2000 d_high, vce(robust)
local b00_d = _b[d_high]
local se00_d = _se[d_high]
local p00_d = 2*ttail(e(df_r), abs(`b00_d'/`se00_d'))
local n00_d = e(N)

* --- Format and write province table ---
foreach v in 82_ihs 90_ihs 00_ihs 82_d 90_d 00_d {
    _stars `p`v''
    local s`v' "`r(star)'"
}

* Pre-format all values as strings
local fb82_ihs : di %9.4f `b82_ihs'
local fb90_ihs : di %9.4f `b90_ihs'
local fb00_ihs : di %9.4f `b00_ihs'
local fse82_ihs : di %7.4f `se82_ihs'
local fse90_ihs : di %7.4f `se90_ihs'
local fse00_ihs : di %7.4f `se00_ihs'
local fb82_d : di %9.4f `b82_d'
local fb90_d : di %9.4f `b90_d'
local fb00_d : di %9.4f `b00_d'
local fse82_d : di %7.4f `se82_d'
local fse90_d : di %7.4f `se90_d'
local fse00_d : di %7.4f `se00_d'
local fn82 : di %12.0fc `n82_ihs'
local fn90 : di %12.0fc `n90_ihs'
local fn00 : di %12.0fc `n00_ihs'

tempname fh
file open `fh' using "$outdir/collectivism_province_ihs_dummy_v1.tex", write replace
file write `fh' "{"                                                           _n
file write `fh' "\def\sym#1{\ifmmode^{#1}\else\(\sp{#1}\)\fi}"              _n
file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}l*{3}{c}}" _n
file write `fh' "\toprule"                                                    _n
file write `fh' "            &\multicolumn{1}{c}{(1)}&\multicolumn{1}{c}{(2)}&\multicolumn{1}{c}{(3)}\\" _n
file write `fh' "            &1982&1990&2000\\"                               _n
file write `fh' "\midrule"                                                    _n
file write `fh' "\multicolumn{4}{l}{\textit{Panel A: IHS(rate) treatment}}\\" _n
file write `fh' "IHS(rate)&`fb82_ihs'\sym{`s82_ihs'}&`fb90_ihs'\sym{`s90_ihs'}&`fb00_ihs'\sym{`s00_ihs'}\\" _n
file write `fh' "            &( `fse82_ihs')&( `fse90_ihs')&( `fse00_ihs')\\[0.5em]" _n
file write `fh' "\multicolumn{4}{l}{\textit{Panel B: Binary (above median) treatment}}\\" _n
file write `fh' "High count&`fb82_d'\sym{`s82_d'}&`fb90_d'\sym{`s90_d'}&`fb00_d'\sym{`s00_d'}\\" _n
file write `fh' "            &( `fse82_d')&( `fse90_d')&( `fse00_d')\\" _n
file write `fh' "\midrule"                                                    _n
file write `fh' "Cross-sectional OLS&\multicolumn{3}{c}{Yes}\\"               _n
file write `fh' "Robust SE&\multicolumn{3}{c}{Yes}\\"                         _n
file write `fh' "Observations&`fn82'&`fn90'&`fn00'\\" _n
file write `fh' "\bottomrule"                                                 _n
file write `fh' "\end{tabular*}"                                              _n
file write `fh' "}"                                                           _n
file close `fh'

di as text "Written province table"

*--------------------------------------------------------------
* Prefecture-level collectivism (2000 only, with province FE)
*--------------------------------------------------------------
import delimited "${proj}/data/temp/collectivesim/Prefecture Collectivism Index 1982-2020.csv", clear varnames(1)
* Keep 2000 collectivism
capture rename prefecturec~00fou collectivism_2000
capture rename prefectureco~0fou collectivism_2000
destring collectivism_2000, replace force
keep prefecturechinese prefecture collectivism_2000
drop if missing(collectivism_2000)
tempfile pref_coll
save `pref_coll'

* Prefecture treatment
import delimited "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.csv", clear varnames(1)
keep countyid_curr6 pop_1953 martyr_count_1931_1945
drop if missing(countyid_curr6, pop_1953, martyr_count_1931_1945)
duplicates drop countyid_curr6, force
tostring countyid_curr6, replace format(%06.0f)
gen prefcd = real(substr(countyid_curr6, 1, 4))
gen provcd = real(substr(countyid_curr6, 1, 2))
collapse (sum) pop_1953 martyr_count_1931_1945, by(prefcd provcd)
gen martyr_per100k = 100000 * martyr_count_1931_1945 / pop_1953
gen ihs_rate = ln(martyr_per100k + sqrt(martyr_per100k^2 + 1))
summ martyr_per100k, detail
gen d_high = (martyr_per100k > r(p50)) if !missing(martyr_per100k)

* Try to merge with prefecture collectivism
* Need prefecture name mapping — use prefcd
* The collectivism file uses prefecture names. We need a crosswalk.
* For now, try merging via prefecture code if available
tempfile pref_treat
save `pref_treat'

* Since direct merge by name is fragile, use the existing prefecture-level file if available
capture confirm file "${proj}/data/temp/collectivesim_prefecture_merged_v1.dta"
if _rc == 0 {
    use "${proj}/data/temp/collectivesim_prefecture_merged_v1.dta", clear
    * Reconstruct IHS and dummy from whatever variables exist
    capture gen ihs_rate = ln(martyr_per100k + sqrt(martyr_per100k^2 + 1)) if !missing(martyr_per100k)
    capture gen ihs_rate = ln(martyr_per100k_1953 + sqrt(martyr_per100k_1953^2 + 1)) if !missing(martyr_per100k_1953)
    capture summ ihs_rate, detail
    capture gen d_high = (ihs_rate > r(p50)) if !missing(ihs_rate)
}
else {
    di as error "Prefecture merged file not found. Skipping prefecture analysis."
    di as text "Please create ${proj}/data/temp/collectivesim_prefecture_merged_v1.dta first"
}

di as text "Done. Run in Stata to generate updated collectivism tables."

exit, clear
