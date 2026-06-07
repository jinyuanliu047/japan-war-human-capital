clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global raw "${proj}/data/raw"

capture program drop search_labels
program define search_labels
    args keyword
    quietly describe, replace clear
    quietly ds
    local allvars `r(varlist)'
    foreach v of local allvars {
        local lab : variable label `v'
        if regexm("`lab'", "`keyword'") {
            di "`v' : `lab'"
        }
    }
end

* ================================================================
* CGSS 2003
* ================================================================
di "============================================"
di "=== CGSS 2003 ==="
di "============================================"
capture {
    use "${raw}/2003/原始数据（stata14.0版本）/cgss2003_14.dta", clear
    describe, short
    di "--- Searching: 教育 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "教育") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 党/入党/政治 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "党") > 0 | strpos("`lab'", "政治") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 军/参军/部队 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "军") > 0 | strpos("`lab'", "部队") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 社会/参加/组织/信任 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "社会") > 0 | strpos("`lab'", "参加") > 0 | strpos("`lab'", "组织") > 0 | strpos("`lab'", "信任") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 成功/努力/态度 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "成功") > 0 | strpos("`lab'", "努力") > 0 | strpos("`lab'", "态度") > 0 {
            di "  `v' : `lab'"
        }
    }
}

* ================================================================
* CGSS 2005
* ================================================================
di ""
di "============================================"
di "=== CGSS 2005 ==="
di "============================================"
capture {
    use "${raw}/2005/原始数据（stata14.0版本）/cgss2005_14.dta", clear
    describe, short
    di "--- Searching: 教育 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "教育") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 党/入党/政治 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "党") > 0 | strpos("`lab'", "政治") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 军/参军/部队 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "军") > 0 | strpos("`lab'", "部队") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 社会/参加/组织/信任 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "社会") > 0 | strpos("`lab'", "参加") > 0 | strpos("`lab'", "组织") > 0 | strpos("`lab'", "信任") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 成功/努力/态度 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "成功") > 0 | strpos("`lab'", "努力") > 0 | strpos("`lab'", "态度") > 0 {
            di "  `v' : `lab'"
        }
    }
}

* ================================================================
* CGSS 2006
* ================================================================
di ""
di "============================================"
di "=== CGSS 2006 ==="
di "============================================"
capture {
    use "${raw}/2006/原始数据（stata14.0版本）/cgss2006_14.dta", clear
    describe, short
    di "--- Searching: 教育 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "教育") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 党/入党/政治 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "党") > 0 | strpos("`lab'", "政治") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 军/参军/部队 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "军") > 0 | strpos("`lab'", "部队") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 社会/参加/组织/信任 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "社会") > 0 | strpos("`lab'", "参加") > 0 | strpos("`lab'", "组织") > 0 | strpos("`lab'", "信任") > 0 {
            di "  `v' : `lab'"
        }
    }
    di "--- Searching: 成功/努力/态度 ---"
    foreach v of varlist * {
        local lab : variable label `v'
        if strpos("`lab'", "成功") > 0 | strpos("`lab'", "努力") > 0 | strpos("`lab'", "态度") > 0 {
            di "  `v' : `lab'"
        }
    }
}

* ================================================================
* CGSS 2003+2013 merged
* ================================================================
di ""
di "============================================"
di "=== CGSS 2003+2013 merged ==="
di "============================================"
capture {
    local mpath "${raw}/2003、2013合并数据"
    local files : dir "`mpath'" files "*.dta"
    foreach f of local files {
        di "File: `f'"
        use "`mpath'/`f'", clear
        describe, short
    }
}

exit, clear
