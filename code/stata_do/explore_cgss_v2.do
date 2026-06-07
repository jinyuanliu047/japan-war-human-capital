clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

di "=== LOADING CGSS 2003 ==="
use "${proj}/data/raw/2003/原始数据（stata14.0版本）/cgss2003_14.dta", clear
describe, short

foreach v of varlist * {
    local lab : variable label `v'
    if strpos("`lab'", "教育") > 0 | strpos("`lab'", "党") > 0 | strpos("`lab'", "政治") > 0 | strpos("`lab'", "军") > 0 | strpos("`lab'", "社会") > 0 | strpos("`lab'", "参加") > 0 | strpos("`lab'", "信任") > 0 | strpos("`lab'", "成功") > 0 | strpos("`lab'", "努力") > 0 | strpos("`lab'", "组织") > 0 | strpos("`lab'", "态度") > 0 | strpos("`lab'", "宗教") > 0 | strpos("`lab'", "选举") > 0 | strpos("`lab'", "投票") > 0 {
        di "  2003: `v' — `lab'"
    }
}

di ""
di "=== LOADING CGSS 2005 ==="
use "${proj}/data/raw/2005/原始数据（stata14.0版本）/cgss2005_14.dta", clear
describe, short

foreach v of varlist * {
    local lab : variable label `v'
    if strpos("`lab'", "教育") > 0 | strpos("`lab'", "党") > 0 | strpos("`lab'", "政治") > 0 | strpos("`lab'", "军") > 0 | strpos("`lab'", "社会") > 0 | strpos("`lab'", "参加") > 0 | strpos("`lab'", "信任") > 0 | strpos("`lab'", "成功") > 0 | strpos("`lab'", "努力") > 0 | strpos("`lab'", "组织") > 0 | strpos("`lab'", "态度") > 0 | strpos("`lab'", "宗教") > 0 | strpos("`lab'", "选举") > 0 | strpos("`lab'", "投票") > 0 {
        di "  2005: `v' — `lab'"
    }
}

di ""
di "=== LOADING CGSS 2006 ==="
use "${proj}/data/raw/2006/城市卷+农村卷原始数据（Stata14.0 版本）/cgss2006_14.dta", clear
describe, short

foreach v of varlist * {
    local lab : variable label `v'
    if strpos("`lab'", "教育") > 0 | strpos("`lab'", "党") > 0 | strpos("`lab'", "政治") > 0 | strpos("`lab'", "军") > 0 | strpos("`lab'", "社会") > 0 | strpos("`lab'", "参加") > 0 | strpos("`lab'", "信任") > 0 | strpos("`lab'", "成功") > 0 | strpos("`lab'", "努力") > 0 | strpos("`lab'", "组织") > 0 | strpos("`lab'", "态度") > 0 | strpos("`lab'", "宗教") > 0 | strpos("`lab'", "选举") > 0 | strpos("`lab'", "投票") > 0 {
        di "  2006: `v' — `lab'"
    }
}

exit, clear
