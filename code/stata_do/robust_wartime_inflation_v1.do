* Robustness: control for province-level WARTIME PRICE INFLATION (economic disruption)
* Source: 近代中国经济指数数据库 (Modern China Economic Index Database), NLC Press.
* Measure: annualized log growth of the provincial wholesale/general price index,
*          1937 base to last available wartime year (<=1945). 9 provinces with a
*          reliable series (drop truncated/short-span Jiangsu, Guangdong, Tibet).
clear all
set more off

* --- province wartime inflation lookup (2-digit GB province code) ---
tempfile pinf
preserve
clear
input str2 prov double ann_infl
"31" 1.018
"35" 0.374
"41" 0.727
"50" 0.793
"51" 0.592
"52" 1.003
"53" 0.884
"61" 0.729
"62" 0.821
end
save `pinf'
restore

use eduy birthyr wave county_num countyid_curr6 minority ihs_rate d_count_high ///
    using "/tmp/japan_war_local/data/temp/master.dta", clear
keep if inrange(birthyr,1920,1956)
gen birth_i = floor(birthyr)
gen post = (birth_i>=1940)
gen byte drop_yr = (birth_i==1939)
gen str2 prov = substr(countyid_curr6,1,2)
merge m:1 prov using `pinf', keep(master match) nogen

local fe "absorb(county_num birth_i) vce(cluster county_num)"
eststo clear
* subsample = provinces with inflation data
eststo c1: reghdfe eduy c.post#c.ihs_rate minority i.wave if !drop_yr & !missing(ann_infl), `fe'
eststo c2: reghdfe eduy c.post#c.ihs_rate c.post#c.ann_infl minority i.wave if !drop_yr & !missing(ann_infl), `fe'
eststo c3: reghdfe eduy c.post#c.d_count_high minority i.wave if !drop_yr & !missing(ann_infl), `fe'
eststo c4: reghdfe eduy c.post#c.d_count_high c.post#c.ann_infl minority i.wave if !drop_yr & !missing(ann_infl), `fe'

esttab c1 c2 c3 c4 using "/tmp/robust_wartime_infl.csv", replace ///
    keep(c.post#c.ihs_rate c.post#c.d_count_high c.post#c.ann_infl) ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) stats(N N_clust r2)
di "DONE infl robustness"
