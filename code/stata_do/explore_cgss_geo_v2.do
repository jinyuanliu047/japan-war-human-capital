/* Deep-dive into CGSS geographic identifiers */
clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

* ================================================================
* CGSS 2003
* ================================================================
di "========================================"
di "  CGSS 2003 — county & province detail"
di "========================================"
use "${proj}/data/raw/2003/原始数据（stata14.0版本）/cgss2003_14.dta", clear

di "--- province variable ---"
tab province, mis
di ""
di "--- county variable ---"
summ county, detail
di "distinct counties:"
distinct county
tab county if _n <= 50
list province county in 1/30, noobs

di ""
di "--- prov variable ---"
capture tab prov, mis

* Check if county is a numeric GB code (6-digit)
di "--- Is county a 6-digit GB code? ---"
gen ndig = floor(log10(county)) + 1 if county > 0
tab ndig

di ""
di "========================================"
di "  CGSS 2005 — check for hidden county vars"
di "========================================"
use "${proj}/data/raw/2005/原始数据（stata14.0版本）/cgss2005_14.dta", clear

di "--- qs2a (province name) ---"
tab qs2a, mis

* Check if serial number encodes county
di "--- serial ---"
summ serial, detail
list serial qs2a in 1/20, noobs

* Look for ANY variable that could be county-level
foreach v of varlist * {
    local vname = "`v'"
    if regexm("`vname'", "county|city|prov|area|site|region|loc|place|addr|geo|s0|s1") {
        local lab : variable label `v'
        di "  Candidate: `v' — `lab'"
    }
}

* Check qs2c
di "--- qs2c ---"
tab qs2c, mis

* Maybe check if there's a separate codebook or additional merge file
di "--- Checking for siteid or community-level vars ---"
foreach v of varlist * {
    local lab : variable label `v'
    if strpos("`lab'", "社区") > 0 | strpos("`lab'", "编号") > 0 | strpos("`lab'", "抽样") > 0 | strpos("`lab'", "调查点") > 0 | strpos("`lab'", "code") > 0 | strpos("`lab'", "ID") > 0 {
        di "  `v' : `lab'"
    }
}

di ""
di "========================================"
di "  CGSS 2006 — check for hidden county vars"
di "========================================"
use "${proj}/data/raw/2006/城市卷+农村卷原始数据（Stata14.0 版本）/cgss2006_14.dta", clear

di "--- province ---"
tab province, mis

di "--- prov ---"
capture tab prov, mis

di "--- serial ---"
summ serial, detail
list serial province in 1/20, noobs

* Look for county-level vars
foreach v of varlist * {
    local vname = "`v'"
    if regexm("`vname'", "county|city|prov|area|site|region|loc|geo|s0|s1|s2|s3|s4") {
        local lab : variable label `v'
        di "  Candidate: `v' — `lab'"
    }
}

* Check for siteid/community vars
foreach v of varlist * {
    local lab : variable label `v'
    if strpos("`lab'", "社区") > 0 | strpos("`lab'", "编号") > 0 | strpos("`lab'", "抽样") > 0 | strpos("`lab'", "调查点") > 0 | strpos("`lab'", "code") > 0 | strpos("`lab'", "ID") > 0 {
        di "  `v' : `lab'"
    }
}

* Check if there are supplementary files with county codes
di ""
di "=== Checking for supplementary CGSS files ==="
local cgss2003dir "${proj}/data/raw/2003"
local cgss2005dir "${proj}/data/raw/2005"
local cgss2006dir "${proj}/data/raw/2006"

* Also check the CGSS 2008 to confirm its county format
di ""
di "========================================"
di "  CGSS 2008 — countyid for reference"
di "========================================"
use countyid using "${proj}/data/raw/cgss2008_14.dta", clear
summ countyid, detail
di "distinct counties in 2008:"
distinct countyid
gen ndig = floor(log10(countyid)) + 1 if countyid > 0
tab ndig

exit, clear
