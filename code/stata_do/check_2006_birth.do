global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
use qa01 qa02 qa03a qa04 qa05a qa05d serial using "${proj}/data/raw/2006/城市卷+农村卷原始数据（Stata14.0 版本）/cgss2006_14.dta", clear
describe qa02
summ qa02, detail
tab qa02 if _n <= 100
* Check if it's encoded
capture decode qa02, gen(qa02_str)
list qa02 qa02_str in 1/20 if !missing(qa02_str)
* Check age variable
foreach v of varlist * {
    local lab : variable label `v'
    if strpos("`lab'", "年龄") > 0 | strpos("`lab'", "age") > 0 | strpos("`lab'", "岁") > 0 {
        di "`v' : `lab'"
    }
}
* Maybe qa02 has year in a different coding
di "qa02 type: "
codebook qa02
exit, clear
