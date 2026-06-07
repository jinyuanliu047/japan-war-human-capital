cd "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data"

// firm cross-sectional info
import excel using "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data/firm_cross_sectional.xlsx", clear firstrow

destring scode, replace
destring countyid, replace 
destring prefectureid, replace
destring provid, replace

gen isincentive = 0
replace isincentive = 1 if 是否有股权激励计划 == "是"

//poverty county
gen ispoverty = 0
replace ispoverty = 1 if 是否属于贫困县地址类型注册地址 == "是"

// drop finance
rename 所属国民经济行业名称2017交易日期最新行业类别 industry
drop if industry == "金融业"
drop if missing(scode)
drop if provid == 810000
save firm_cross_sectional.dta, replace

// heritage data
import excel using "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data/heritatge.xlsx", clear firstrow
save heritage_info.dta, replace
gen flag = 1
collapse (sum) flag, by(countyid)
gen heritage = 1 if flag >= 1
drop flag
save heritage_county.dta, replace

// merge data
use firm_cross_sectional.dta, clear
merge m:n countyid using heritage_county.dta
drop if _merge == 2
replace heritage = 0 if _merge == 1
drop _merge


reg isincentive heritage, vce(r)
reghdfe isincentive heritage, absorb(prefectureid) vce(r)
logit isincentive heritage, vce(robust)
probit isincentive heritage, vce(robust)
