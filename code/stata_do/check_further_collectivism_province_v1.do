clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
cap mkdir "${proj}/result/table"

* Province-level wartime exposure aggregated from county treatment inputs.
import delimited "${proj}/data/temp/did_1990_county_birthyr_pop1953_unwt_v2.csv", clear varnames(1)
keep countyid_curr6 pop_1953 martyr_count_1931_1945
drop if missing(countyid_curr6, pop_1953, martyr_count_1931_1945)
duplicates drop countyid_curr6, force

tostring countyid_curr6, replace format(%06.0f)
gen provcd = real(substr(countyid_curr6, 1, 2))

collapse (sum) pop_1953 martyr_count_1931_1945, by(provcd)
gen martyr_per100k_1953 = 100000 * martyr_count_1931_1945 / pop_1953
gen ln_martyr_per100k_1953 = ln(1 + martyr_per100k_1953)

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

keep provcd Province pop_1953 martyr_count_1931_1945 martyr_per100k_1953 ln_martyr_per100k_1953
rename Province province
tempfile prov_treat
save `prov_treat'

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

reg collectivism_1982 ln_martyr_per100k_1953, vce(robust)
estimates store model1
estadd local Wave "1982"

reg collectivism_1990 ln_martyr_per100k_1953, vce(robust)
estimates store model2
estadd local Wave "1990"

reg collectivism_2000 ln_martyr_per100k_1953, vce(robust)
estimates store model3
estadd local Wave "2000"

esttab model1 model2 model3 using "${proj}/result/table/further_collectivism_province_v1.rtf", ///
    replace booktabs nonotes ///
    keep(ln_martyr_per100k_1953) ///
    coeflabels(ln_martyr_per100k_1953 "War exposure") ///
    mtitles("1982" "1990" "2000") ///
    stats(N r2 r2_a, fmt(%9.0f %9.3f %9.3f) labels("Observations" "R-squared" "Adj. R-squared")) ///
    b(%9.4f) se(%9.4f) star(* 0.1 ** 0.05 *** 0.01)

esttab model1 model2 model3 using "${proj}/result/table/further_collectivism_province_v1.tex", ///
    replace booktabs nonotes ///
    keep(ln_martyr_per100k_1953) ///
    coeflabels(ln_martyr_per100k_1953 "War exposure") ///
    mtitles("1982" "1990" "2000") ///
    stats(N r2 r2_a, fmt(%9.0f %9.3f %9.3f) labels("Observations" "R-squared" "Adj. R-squared")) ///
    b(%9.4f) se(%9.4f) star(* 0.1 ** 0.05 *** 0.01)

tempname memhold
postfile `memhold' str4 wave double b se p N r2 ar2 using "${proj}/result/table/further_collectivism_province_v1_tmp.dta", replace
est restore model1
post `memhold' ("1982") (_b[ln_martyr_per100k_1953]) (_se[ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[ln_martyr_per100k_1953]/_se[ln_martyr_per100k_1953]))) (e(N)) (e(r2)) (e(r2_a))
est restore model2
post `memhold' ("1990") (_b[ln_martyr_per100k_1953]) (_se[ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[ln_martyr_per100k_1953]/_se[ln_martyr_per100k_1953]))) (e(N)) (e(r2)) (e(r2_a))
est restore model3
post `memhold' ("2000") (_b[ln_martyr_per100k_1953]) (_se[ln_martyr_per100k_1953]) (2*ttail(e(df_r), abs(_b[ln_martyr_per100k_1953]/_se[ln_martyr_per100k_1953]))) (e(N)) (e(r2)) (e(r2_a))
postclose `memhold'

use "${proj}/result/table/further_collectivism_province_v1_tmp.dta", clear
export delimited using "${proj}/result/table/further_collectivism_province_v1.csv", replace
erase "${proj}/result/table/further_collectivism_province_v1_tmp.dta"
