clear all
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
di "=== county_controls_full_v1.dta ==="
capture describe using "${proj}/data/temp/county_controls_full_v1.dta"
if _rc != 0 di "NOT FOUND"
di "=== revolutionary_proxy_controls_v1.dta ==="
capture describe using "${proj}/data/temp/revolutionary_proxy_controls_v1.dta"
if _rc != 0 di "NOT FOUND"
di "=== Listing all dta in data/temp with 'control' ==="
local files : dir "${proj}/data/temp" files "*control*.dta"
foreach f of local files {
    di "  `f'"
    describe using "${proj}/data/temp/`f'", short
}
exit, clear
