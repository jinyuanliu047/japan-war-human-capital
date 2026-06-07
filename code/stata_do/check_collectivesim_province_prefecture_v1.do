*******************************************************
* Collectivism archive: province-level and 2000 prefecture-level
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/temp/county_controls_full_v1.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

capture which esttab
if _rc != 0 ssc install estout, replace

local prov_csv "/tmp/jw_collectivesim/Province_Collectivism_Index_1982_2020.csv"
local pref_csv "/tmp/jw_collectivesim/Prefecture_Collectivism_Index_2000_2020.csv"
capture confirm file "`prov_csv'"
if _rc != 0 {
    di as error "Missing province collectivism csv: `prov_csv'"
    exit 601
}
capture confirm file "`pref_csv'"
if _rc != 0 {
    di as error "Missing prefecture collectivism csv: `pref_csv'"
    exit 601
}

tempfile county_prov_map prov_treat prov_panel pref_treat pref_panel

*******************************************************
* Province-level treatment
*******************************************************
import delimited "${proj}/data/scrape/chinamartyrs_outputs/chinamartyrs_county_counts.csv", clear varnames(1)
keep county_id province_name city_name
gen countyid_curr6 = real(substr(county_id, 1, 6))
drop if missing(countyid_curr6)
duplicates drop countyid_curr6, force
tempfile county_prov_map
save `county_prov_map', replace

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep if countyid_curr6 != 0
merge m:1 countyid_curr6 using `county_prov_map', keep(match) nogen

gen province_short = ""
replace province_short = "北京" if province_name == "北京市"
replace province_short = "天津" if province_name == "天津市"
replace province_short = "上海" if province_name == "上海市"
replace province_short = "重庆" if province_name == "重庆市"
replace province_short = "河北" if province_name == "河北省"
replace province_short = "山西" if province_name == "山西省"
replace province_short = "辽宁" if province_name == "辽宁省"
replace province_short = "吉林" if province_name == "吉林省"
replace province_short = "黑龙江" if province_name == "黑龙江省"
replace province_short = "江苏" if province_name == "江苏省"
replace province_short = "浙江" if province_name == "浙江省"
replace province_short = "安徽" if province_name == "安徽省"
replace province_short = "福建" if province_name == "福建省"
replace province_short = "江西" if province_name == "江西省"
replace province_short = "山东" if province_name == "山东省"
replace province_short = "河南" if province_name == "河南省"
replace province_short = "湖北" if province_name == "湖北省"
replace province_short = "湖南" if province_name == "湖南省"
replace province_short = "广东" if province_name == "广东省"
replace province_short = "海南" if province_name == "海南省"
replace province_short = "四川" if province_name == "四川省"
replace province_short = "贵州" if province_name == "贵州省"
replace province_short = "云南" if province_name == "云南省"
replace province_short = "陕西" if province_name == "陕西省"
replace province_short = "甘肃" if province_name == "甘肃省"
replace province_short = "青海" if province_name == "青海省"
replace province_short = "内蒙古" if province_name == "内蒙古自治区"
replace province_short = "广西" if province_name == "广西壮族自治区"
replace province_short = "西藏" if province_name == "西藏自治区"
replace province_short = "宁夏" if province_name == "宁夏回族自治区"
replace province_short = "新疆" if province_name == "新疆维吾尔自治区"
replace province_short = "新疆" if province_name == "新疆生产建设兵团"

count if missing(province_short)
if r(N) > 0 {
    di as error "Unmapped province names in county martyr treatment:"
    list province_name if missing(province_short), noobs sepby(province_name)
    exit 459
}

collapse (sum) martyr_count_1931_1945 pop_1953, by(province_short)
gen ln_martyr_per100k_1953 = ln(1 + martyr_count_1931_1945 / pop_1953 * 100000)

tempfile prov_treat
save `prov_treat', replace

import delimited "`prov_csv'", clear varnames(1)
keep ProvinceChinese ProvinceCollectivismIndex1982FourItems ProvinceCollectivismIndex1990FourItems ProvinceCollectivismIndex2000FourItems
rename ProvinceChinese province_short
merge 1:1 province_short using `prov_treat', keep(match) nogen

eststo clear
quietly reg ProvinceCollectivismIndex1982FourItems c.ln_martyr_per100k_1953, vce(robust)
eststo prov1982
quietly reg ProvinceCollectivismIndex1990FourItems c.ln_martyr_per100k_1953, vce(robust)
eststo prov1990
quietly reg ProvinceCollectivismIndex2000FourItems c.ln_martyr_per100k_1953, vce(robust)
eststo prov2000

esttab prov1982 prov1990 prov2000 using "${proj}/paper/assets/tables/collectivesim_province_reduced_form_v1.tex", ///
    replace ///
    booktabs nonotes ///
    keep(ln_martyr_per100k_1953) ///
    coeflabels(ln_martyr_per100k_1953 "Log martyr exposure per 100,000") ///
    mtitles("1982" "1990" "2000") ///
    stats(N r2 ar2, labels("Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

*******************************************************
* Prefecture-level 2000/2010/2020 supplement via pref4
*******************************************************
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep if countyid_curr6 != 0
gen pref4_curr = floor(countyid_curr6 / 100)
format pref4_curr %04.0f
merge m:1 countyid_curr6 using `county_prov_map', keep(match) nogen

gen pref_short = city_name
replace pref_short = substr(pref_short, 1, length(pref_short)-1) if substr(pref_short, -1, 1) == "市"
replace pref_short = substr(pref_short, 1, length(pref_short)-1) if substr(pref_short, -1, 1) == "盟"

collapse (sum) martyr_count_1931_1945 pop_1953, by(pref4_curr pref_short)
gen ln_martyr_per100k_1953 = ln(1 + martyr_count_1931_1945 / pop_1953 * 100000)
tempfile pref_treat
save `pref_treat', replace

import delimited "`pref_csv'", clear varnames(1)
keep Province PrefectureChinese ///
    PrefectureCollectivismIndex2000 ///
    PrefectureCollectivismIndex2010 ///
    PrefectureCollectivismIndex2020
rename PrefectureChinese pref_short
destring PrefectureCollectivismIndex2000, replace force
destring PrefectureCollectivismIndex2010, replace force
destring PrefectureCollectivismIndex2020, replace force
merge 1:1 pref_short using `pref_treat', keep(match) nogen

eststo clear
quietly reg PrefectureCollectivismIndex2000 c.ln_martyr_per100k_1953 if !missing(PrefectureCollectivismIndex2000), vce(robust)
eststo pref2000
quietly reg PrefectureCollectivismIndex2010 c.ln_martyr_per100k_1953 if !missing(PrefectureCollectivismIndex2010), vce(robust)
eststo pref2010
quietly reg PrefectureCollectivismIndex2020 c.ln_martyr_per100k_1953 if !missing(PrefectureCollectivismIndex2020), vce(robust)
eststo pref2020

esttab pref2000 using "${proj}/paper/assets/tables/collectivesim_prefecture_2000_v1.tex", ///
    replace ///
    booktabs nonotes ///
    keep(ln_martyr_per100k_1953) ///
    coeflabels(ln_martyr_per100k_1953 "Log martyr exposure per 100,000") ///
    mtitles("2000") ///
    stats(N r2 ar2, labels("Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

esttab pref2000 pref2010 pref2020 using "${proj}/paper/assets/tables/collectivesim_prefecture_panel_v1.tex", ///
    replace ///
    booktabs nonotes ///
    keep(ln_martyr_per100k_1953) ///
    coeflabels(ln_martyr_per100k_1953 "Log martyr exposure per 100,000") ///
    mtitles("2000" "2010" "2020") ///
    stats(N r2 ar2, labels("Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

esttab pref2000 pref2010 pref2020 using "${proj}/paper/assets/tables/collectivesim_prefecture_panel_v1.csv", ///
    replace ///
    keep(ln_martyr_per100k_1953) ///
    se star(* 0.1 ** 0.05 *** 0.01) ///
    stats(N r2 ar2)

exit, clear
