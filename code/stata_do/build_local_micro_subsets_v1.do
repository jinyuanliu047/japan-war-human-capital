clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

use countyid birthyr eduy ethniccn using "${proj}/data/temp/census_1982_cleaned.dta", clear
save "/tmp/census_1982_cleaned_small.dta", replace

use county age_c age educ race using "${proj}/data/raw/census/census1990.dta", clear
save "/tmp/census1990_raw_small.dta", replace

use uid birthyr eduyr race using "${proj}/data/raw/census/census2000.dta", clear
save "/tmp/census2000_raw_small.dta", replace

exit, clear
