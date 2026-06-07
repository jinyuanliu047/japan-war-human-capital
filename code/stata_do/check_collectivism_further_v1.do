*******************************************************
* Supplementary further analysis:
* Collectivism index as a long-run social outcome
* Province: 1982 / 1990 / 2000
* Prefecture: 2000
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which esttab
if _rc != 0 ssc install estout, replace

*******************************************************
* County treatment merged with county names
*******************************************************
import delimited "${proj}/data/temp/countyid6_name_crosswalk_v1.csv", clear varnames(1) stringcols(_all)
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6) - 5, 6)
keep countyid_curr6 prov_name city_name
duplicates drop countyid_curr6, force
tempfile countyname
save `countyname'

use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
keep countyid_curr6 pop_1953 martyr_count_1931_1945
capture confirm numeric variable countyid_curr6
if _rc == 0 {
    drop if missing(countyid_curr6) | countyid_curr6==0
    gen str6 countyid_curr6_str = string(countyid_curr6, "%06.0f")
    drop countyid_curr6
    rename countyid_curr6_str countyid_curr6
}
else {
    drop if countyid_curr6=="" | countyid_curr6=="0" | countyid_curr6=="000000"
    replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6) - 5, 6)
}
merge 1:1 countyid_curr6 using `countyname', keep(match) nogen

*******************************************************
* Province treatment
*******************************************************
gen prov_short = prov_name
replace prov_short = subinstr(prov_short, "壮族自治区", "", .)
replace prov_short = subinstr(prov_short, "回族自治区", "", .)
replace prov_short = subinstr(prov_short, "维吾尔自治区", "", .)
replace prov_short = subinstr(prov_short, "自治区", "", .)
replace prov_short = subinstr(prov_short, "特别行政区", "", .)
replace prov_short = subinstr(prov_short, "省", "", .)
replace prov_short = subinstr(prov_short, "市", "", .)
replace prov_short = trim(prov_short)

preserve
    collapse (sum) pop_1953 martyr_count_1931_1945, by(prov_short)
    gen martyr_per100k_1953 = martyr_count_1931_1945 / pop_1953 * 100000
    gen ln_martyr_per100k_1953 = ln(1 + martyr_per100k_1953)
    tempfile prov_treat
    save `prov_treat'
restore

*******************************************************
* Prefecture treatment
*******************************************************
gen pref4 = substr(countyid_curr6, 1, 4)
gen city_short = city_name
replace city_short = subinstr(city_short, "市（辖区）", "", .)
replace city_short = subinstr(city_short, "市辖区", "", .)
replace city_short = subinstr(city_short, "地区", "", .)
replace city_short = subinstr(city_short, "自治州", "", .)
replace city_short = subinstr(city_short, "盟", "", .)
replace city_short = subinstr(city_short, "市", "", .)
replace city_short = trim(city_short)

preserve
    keep pref4 city_short
    duplicates drop pref4, force
    bysort city_short: gen city_dup = _N
    keep if city_dup==1
    drop city_dup
    tempfile pref_name
    save `pref_name'
restore

preserve
    collapse (sum) pop_1953 martyr_count_1931_1945, by(pref4)
    gen martyr_per100k_1953 = martyr_count_1931_1945 / pop_1953 * 100000
    gen ln_martyr_per100k_1953 = ln(1 + martyr_per100k_1953)
    merge 1:1 pref4 using `pref_name', keep(match) nogen
    tempfile pref_treat
    save `pref_treat'
restore

*******************************************************
* Province collectivism outcomes
*******************************************************
import delimited "${proj}/data/temp/collectivesim/Province Collectivism Index 1982-2020.csv", clear varnames(1) stringcols(_all)
keep provincechinese province provinceco~2fou provincec~90fou provincec~00fou
rename provincechinese prov_short
rename province province_en
rename provinceco~2fou coll1982
rename provincec~90fou coll1990
rename provincec~00fou coll2000
destring coll1982, replace force
destring coll1990, replace force
destring coll2000, replace force
merge 1:1 prov_short using `prov_treat', keep(match) nogen

reg coll1982 c.ln_martyr_per100k_1953, vce(robust)
estimates store model1
estadd local Level "Province"
estadd local Year "1982"

reg coll1990 c.ln_martyr_per100k_1953, vce(robust)
estimates store model2
estadd local Level "Province"
estadd local Year "1990"

reg coll2000 c.ln_martyr_per100k_1953, vce(robust)
estimates store model3
estadd local Level "Province"
estadd local Year "2000"

*******************************************************
* Prefecture collectivism outcome, 2000
*******************************************************
import delimited "${proj}/data/temp/collectivesim/Prefecture Collectivism Index 2000-2020.csv", clear varnames(1) stringcols(_all)
keep prefecturechi~e prefecture~2000
gen city_short = prefecturechi~e
replace city_short = subinstr(city_short, "自治州", "", .)
replace city_short = subinstr(city_short, "地区", "", .)
replace city_short = subinstr(city_short, "盟", "", .)
replace city_short = subinstr(city_short, "市", "", .)
replace city_short = trim(city_short)
rename prefecture~2000 coll2000_pref
destring coll2000_pref, replace force
merge 1:1 city_short using `pref_treat', keep(match) nogen

reg coll2000_pref c.ln_martyr_per100k_1953, vce(robust)
estimates store model4
estadd local Level "Prefecture"
estadd local Year "2000"

*******************************************************
* Output
*******************************************************
esttab model1 model2 model3 model4 using "${proj}/result/table/collectivism_further_v1.tex", ///
    replace booktabs nonotes label compress ///
    keep(ln_martyr_per100k_1953) ///
    coeflabels(ln_martyr_per100k_1953 "War exposure") ///
    mtitles("(1)" "(2)" "(3)" "(4)") ///
    mgroups("Province collectivism index" "Prefecture collectivism index", pattern(1 0 0 1) span prefix(\multicolumn{@span}{c}{) suffix(})) ///
    stats(Level Year N r2 ar2, labels("Level" "Year" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 model4 using "${proj}/result/table/collectivism_further_v1.rtf", ///
    replace ///
    keep(ln_martyr_per100k_1953) ///
    coeflabels(ln_martyr_per100k_1953 "War exposure") ///
    mtitles("(1)" "(2)" "(3)" "(4)") ///
    stats(Level Year N r2 ar2, labels("Level" "Year" "Observations" "R-squared" "Adj. R-squared")) ///
    se star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' str12 level str4 year double b se p N using "${proj}/result/table/collectivism_further_summary_v1.dta", replace
est restore model1
post `memhold' ("Province") ("1982") (_b[ln_martyr_per100k_1953]) (_se[ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[ln_martyr_per100k_1953]/_se[ln_martyr_per100k_1953]))) (e(N))
est restore model2
post `memhold' ("Province") ("1990") (_b[ln_martyr_per100k_1953]) (_se[ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[ln_martyr_per100k_1953]/_se[ln_martyr_per100k_1953]))) (e(N))
est restore model3
post `memhold' ("Province") ("2000") (_b[ln_martyr_per100k_1953]) (_se[ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[ln_martyr_per100k_1953]/_se[ln_martyr_per100k_1953]))) (e(N))
est restore model4
post `memhold' ("Prefecture") ("2000") (_b[ln_martyr_per100k_1953]) (_se[ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[ln_martyr_per100k_1953]/_se[ln_martyr_per100k_1953]))) (e(N))
postclose `memhold'

use "${proj}/result/table/collectivism_further_summary_v1.dta", clear
export delimited using "${proj}/result/table/collectivism_further_summary_v1.csv", replace
