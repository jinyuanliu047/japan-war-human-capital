global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
use "${proj}/data/temp/martyr_pop1953_treatment_county_v2.dta", clear
summarize martyr_count martyr_per100k_1953 ln_martyr_per100k_1953 ln_martyr_raw pop_1953, detail
exit, clear
