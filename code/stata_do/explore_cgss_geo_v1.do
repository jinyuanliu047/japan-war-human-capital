/* Check geographic identifiers in CGSS 2003/2005/2006 */
clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

di "========================================"
di "  CGSS 2003 — Geographic Variables"
di "========================================"
use "${proj}/data/raw/2003/原始数据（stata14.0版本）/cgss2003_14.dta", clear
describe, short

* Search for geographic/location/county/province variables
foreach v of varlist * {
    local lab : variable label `v'
    if strpos("`lab'", "省") > 0 | strpos("`lab'", "县") > 0 | strpos("`lab'", "市") > 0 | strpos("`lab'", "地区") > 0 | strpos("`lab'", "区县") > 0 | strpos("`lab'", "城市") > 0 | strpos("`lab'", "居住") > 0 | strpos("`lab'", "地址") > 0 | strpos("`lab'", "户口") > 0 | strpos("`lab'", "出生") > 0 | strpos("`lab'", "籍贯") > 0 {
        di "  `v' : `lab'"
    }
}

* Also check for numeric geo IDs (countyid, province, etc)
capture confirm variable countyid
if _rc == 0 {
    di "countyid exists!"
    summ countyid
}
else {
    di "No countyid variable"
}

* Check s01-s10 type survey info vars
foreach v in s01 s02 s03 s04 s05 s06 s07 s08 s09 s10 ///
    prov city county district area village ///
    province cityid countyid siteid ///
    a01a a01b a02 a03 a04 birth birthyr ///
    id serial {
    capture confirm variable `v'
    if _rc == 0 {
        local lab : variable label `v'
        di "  Found: `v' — `lab'"
        capture summ `v', detail
        capture tab `v' if _n <= 20
    }
}

* List first few obs of likely geo vars
di "--- First 10 obs of select vars ---"
capture list s01 s02 s03 prov city county in 1/10
capture list province cityid countyid siteid in 1/10

di ""
di "========================================"
di "  CGSS 2005 — Geographic Variables"
di "========================================"
use "${proj}/data/raw/2005/原始数据（stata14.0版本）/cgss2005_14.dta", clear
describe, short

foreach v of varlist * {
    local lab : variable label `v'
    if strpos("`lab'", "省") > 0 | strpos("`lab'", "县") > 0 | strpos("`lab'", "市") > 0 | strpos("`lab'", "地区") > 0 | strpos("`lab'", "区县") > 0 | strpos("`lab'", "城市") > 0 | strpos("`lab'", "居住") > 0 | strpos("`lab'", "地址") > 0 | strpos("`lab'", "户口") > 0 | strpos("`lab'", "出生") > 0 | strpos("`lab'", "籍贯") > 0 {
        di "  `v' : `lab'"
    }
}

foreach v in s01 s02 s03 s04 s05 prov city county district ///
    province cityid countyid siteid ///
    qa01 qa02 qa03 qa04 qa05 ///
    id serial {
    capture confirm variable `v'
    if _rc == 0 {
        local lab : variable label `v'
        di "  Found: `v' — `lab'"
        capture summ `v', detail
    }
}

capture list s01 s02 s03 s04 s05 in 1/10
capture list countyid in 1/10

di ""
di "========================================"
di "  CGSS 2006 — Geographic Variables"
di "========================================"
use "${proj}/data/raw/2006/城市卷+农村卷原始数据（Stata14.0 版本）/cgss2006_14.dta", clear
describe, short

foreach v of varlist * {
    local lab : variable label `v'
    if strpos("`lab'", "省") > 0 | strpos("`lab'", "县") > 0 | strpos("`lab'", "市") > 0 | strpos("`lab'", "地区") > 0 | strpos("`lab'", "区县") > 0 | strpos("`lab'", "城市") > 0 | strpos("`lab'", "居住") > 0 | strpos("`lab'", "地址") > 0 | strpos("`lab'", "户口") > 0 | strpos("`lab'", "出生") > 0 | strpos("`lab'", "籍贯") > 0 {
        di "  `v' : `lab'"
    }
}

foreach v in s01 s02 s03 s04 s05 prov city county district ///
    province cityid countyid siteid ///
    qa01 qa02 qa03 serial ///
    id {
    capture confirm variable `v'
    if _rc == 0 {
        local lab : variable label `v'
        di "  Found: `v' — `lab'"
        capture summ `v', detail
    }
}

capture list s01 s02 s03 s04 s05 in 1/10
capture list countyid in 1/10

exit, clear
