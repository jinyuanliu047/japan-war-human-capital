cd "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data"

//file1
use "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data/figure/TMT_FIGUREINFO.dta", clear
gen year = substr(Reptdt, 1, 4)
destring year, replace
rename Stkcd scode
destring scode, replace
keep if year >= 2010
gen overseaedu = 0
replace overseaedu = 1 if strpos(OveseaBack, "1") > 0
replace overseaedu = 1 if strpos(OveseaBack, "2") > 0
collapse (sum) overseaedu, by(year scode)
save oversea_figure.dta, replace

//file2
use "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data/figure/TMT_FIGUREINFO1.dta", clear
gen year = substr(Reptdt, 1, 4)
destring year, replace
rename Stkcd scode
destring scode, replace
keep if year >= 2010
gen overseaedu = 0
replace overseaedu = 1 if strpos(OveseaBack, "1") > 0
replace overseaedu = 1 if strpos(OveseaBack, "2") > 0
collapse (sum) overseaedu, by(year scode)
append using oversea_figure.dta
sort scode year

merge m:n scode year using firm_info_edited.dta
keep if _merge == 3
drop _merge
save oversea_full.dta, replace


gen did = treat * post
gen ihs_overseaedu = asinh(overseaedu)

ppmlhdfe ihs_overseaedu did, absorb(countyid year) cluster(countyid)

