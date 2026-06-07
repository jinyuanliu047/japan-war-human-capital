*******************************************************
* Manual refresh entry for cleaned paper tables
* No loops, no wrappers, just sequential do + copy
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

*******************************************************
* Step 1. Run cleaned Stata scripts
*******************************************************

do "${proj}/code/stata_do/check_main_gender_urban_reghdfejl_v4.do"
do "${proj}/code/stata_do/check_main_antijap_base_broad_heterogeneity_reghdfejl_v1.do"
do "${proj}/code/stata_do/check_main_heterogeneity_pack_reghdfejl_v1.do"
do "${proj}/code/stata_do/check_mechanism_census1990_ipums_employment_reghdfe_v1.do"
do "${proj}/code/stata_do/check_mechanism_census1990_ipums_industry_reghdfe_v1.do"

*******************************************************
* Step 2. Copy refreshed tex tables into paper assets
*******************************************************

copy "${proj}/result/table/main_individual_heterogeneity_gender_reghdfe_v4.tex" "${proj}/paper/assets/tables/main_individual_heterogeneity_gender_reghdfejl_v4.tex", replace
copy "${proj}/result/table/main_individual_heterogeneity_urbanrural_reghdfe_v4.tex" "${proj}/paper/assets/tables/main_individual_heterogeneity_urbanrural_reghdfejl_v4.tex", replace
copy "${proj}/result/table/main_antijap_base_broad_heterogeneity_reghdfe_v1.tex" "${proj}/paper/assets/tables/main_antijap_base_broad_heterogeneity_reghdfejl_v1.tex", replace
copy "${proj}/result/table/main_heterogeneity_pack_reghdfe_v1.tex" "${proj}/paper/assets/tables/main_heterogeneity_pack_reghdfe_v1.tex", replace
copy "${proj}/result/table/main_heterogeneity_pack_1982_reghdfe_v1.tex" "${proj}/paper/assets/tables/main_heterogeneity_pack_1982_reghdfe_v1.tex", replace
copy "${proj}/result/table/main_heterogeneity_pack_1990_reghdfe_v1.tex" "${proj}/paper/assets/tables/main_heterogeneity_pack_1990_reghdfe_v1.tex", replace
copy "${proj}/result/table/main_heterogeneity_pack_2000_reghdfe_v1.tex" "${proj}/paper/assets/tables/main_heterogeneity_pack_2000_reghdfe_v1.tex", replace
copy "${proj}/result/table/mechanism_census1990_ipums_employment_reghdfe_v1.tex" "${proj}/paper/assets/tables/mechanism_census1990_ipums_employment_reghdfe_v1.tex", replace
copy "${proj}/result/table/mechanism_census1990_ipums_industry_reghdfe_v1.tex" "${proj}/paper/assets/tables/mechanism_census1990_ipums_industry_reghdfe_v1.tex", replace

exit, clear
