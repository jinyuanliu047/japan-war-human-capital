*******************************************************
* Build stripped census files for repeated main tables
* Keep only variables used in education / completion runs
*******************************************************

clear all
set more off

local proj_cloud "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
capture confirm file "/tmp/japan_war_local/data/raw/census/census1990.dta"
if _rc == 0 global proj "/tmp/japan_war_local"
else global proj "`proj_cloud'"

use countyid birthyr eduy ethniccn using "${proj}/data/temp/census_1982_cleaned.dta", clear
compress
save "${proj}/data/temp/census_1982_mainvars_v1.dta", replace

use county age_c age educ race using "${proj}/data/raw/census/census1990.dta", clear
compress
save "${proj}/data/temp/census_1990_mainvars_v1.dta", replace

use uid birthyr eduyr race using "${proj}/data/raw/census/census2000.dta", clear
compress
save "${proj}/data/temp/census_2000_mainvars_v1.dta", replace

exit, clear
