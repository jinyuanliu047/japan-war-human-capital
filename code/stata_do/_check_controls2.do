clear all
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
di "=== county_controls_full_v1.dta ==="
describe using "${proj}/data/temp/county_controls_full_v1.dta"
di "=== revolutionary_proxy_controls_v1.dta ==="
describe using "${proj}/data/temp/revolutionary_proxy_controls_v1.dta"
exit, clear
