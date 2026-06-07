clear all
set more off
cd "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

* CGSS 2008
di ""
di "=== CGSS 2008 a9 tab ==="
use data/raw/cgss2008_14.dta, clear
tab a9

* CGSS 2003
di ""
di "=== CGSS 2003 ==="
capture use data/raw/2003/原始数据（stata14.0版本）/cgss2003_14.dta, clear
if _rc == 0 {
    lookfor 党
    lookfor 兵
    lookfor 军
    lookfor party
    lookfor army
}

* CGSS 2005
di ""
di "=== CGSS 2005 ==="
capture use data/raw/2005/原始数据（stata14.0版本）/cgss2005_14.dta, clear
if _rc == 0 {
    lookfor 党
    lookfor 兵
    lookfor 军
    lookfor party
    lookfor army
}

* CGSS 2006
di ""
di "=== CGSS 2006 urban/rural ==="
capture use data/raw/2006/城市卷+农村卷原始数据（Stata14.0 版本）/cgss2006_14.dta, clear
if _rc == 0 {
    lookfor 党
    lookfor 兵
    lookfor 军
    lookfor party
}

exit, clear
