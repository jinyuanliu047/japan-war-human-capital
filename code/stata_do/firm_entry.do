cd "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data"

// Apply winsorization before log transformation
use "/Users/jinyuanliu/Desktop/Projects/completed/平台经济&农村/data_2022/各区县各行业-新注册企业数据(2000-2023年).dta", clear

rename 年份 year
rename 行政区划代码 countyid
rename 新注册企业数目 firm
rename 所属行业 industry
rename 区县名称 county
label variable firm "number of newly entered firms"
label variable industry industry

drop if missing(countyid)
keep year countyid county firm industry



save firm_entry.dta, replace

// Calculate total number of newly entered firms
use firm_entry.dta, clear



collapse (sum) firm, by(countyid county year)
keep if year >=2010
keep if year <=2022

rename firm tot_firm

// Take the log of the winsorized total


save tot_firm.dta, replace



use firm_entry.dta, clear

keep if industry == "文化、体育和娱乐业"
collapse (sum) firm, by(countyid county year)
keep if year >=2010
keep if year <=2022



// Take the log of the winsorized total


save cultural_firm.dta, replace



use cultural_firm.dta, clear

* 初始化变量
gen treat = 0
gen post = 0
gen policyyear = .

* 替换 treat = 1 的处理组
replace treat = 1 if inlist(countyid, ///
110106, 110229, 120113, 120225, 130104, 130722, 130204, 130622, 130634, 130402, ///
140926, 140302, 140623, 140902, 140423, 150125, 150702, 150723, 210602, 210204, ///
210403, 210521, 220103, 220602, 230103, 230108, 231123, 231024, 230229, 310109, ///
310113, 320104, 320102, 320106, 320921, 320803, 320904, 330102, 330803, 330802, ///
340103, 341822, 360403, 360322, 370686, 370682, 371083, 371302, 371321, 370681, ///
370682, 370481, 411722, 411623, 420115, 421182, 430702, 430722, 430403, 430412, ///
431025, 440106, 441322, 441481, 460105, 500103, 500101, 510502, 522424, 533323, ///
530524, 610103, 610602, 610623, 610629)

* 指定政策年份
replace policyyear = 2014 if treat == 1




replace treat = 1 if inlist(countyid, ///
110106, 110108, 110111, 110113, 110228, ///
130683, 130202, 130229, 130825, 130628, ///
140428, 140423, 140422, 140621, 140927, ///
150124, 150123, 150400, 150401, 150281, ///
210202, 210204, 210214, 210304, 210405, ///
220503, 222407, 222401, 220502, 220581, 220582, 220701, 220801, 220802, ///
230109, 230110, 230111, 231003, ///
310116, 310115, ///
320381, 320925, 320704, 320583, 321012, 321081, ///
341003, 341124, 341122, ///
350981, ///
360482, 360427, ///
370505, 370583, 370782, 371003, 371081, 371323, 371428, 371421, 371502, 371203, ///
411722, 411623, ///
420104, 420502, ///
430702, 430703, 430902, 431127, ///
440511, 440608, 440781, 440882, ///
450302, ///
460105, ///
500103, 500101, ///
511502, ///
522424, 533323, 530523, ///
610103, 610602, 610623, 610628 ///
)


replace policyyear = 2015 if treat == 1 & policyyear == . 





replace treat = 1 if inlist(countyid, ///
110109,110118,110101,110111,110228,110112,110113,130182,130600,130181,130606,130682,130402,130828,130382,130902,140321,150104,150105,150121,150122,150123,150124,210211,210202,210204,210302,220181,220721,220302,220502,310113,320282,320925,320281,320904,321183,341023,341008,341003,350424,360981,361003,370683,370681,370703,370921,371321,140321,411682,421003,430903,420404,430127,430703,440304,440982,440306,450202,450322,460105,500101,500103,510703,512501,522424,533323,530625,610103,610623,610581,610303)

replace policyyear = 2020 if treat == 1 & policyyear == . 

replace post = 1 if year >= policyyear
gen did = treat * post

winsor2 firm, cut(1,99)

gen lnfirm = ln(firm + 1)

reghdfe lnfirm did, absorb(countyid year) vce(cluster countyid)
