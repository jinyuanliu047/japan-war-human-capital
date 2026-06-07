cd "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data"

import delimited using "/Users/jinyuanliu/Desktop/Projects/ongoing/heritage/data/nationalism_score_2001_2023_20241117.csv", clear
rename symbol scode

save nationalism_score.dta, replace

merge m:n scode year using firm_info_edited.dta
keep if _merge == 3
drop _merge

gen post2015 = 0
replace post2015 = 1 if year >= 2015




reghdfe antiforeign i.treat##i.post2015, a(year scode countyid) vce(cluster scode)



