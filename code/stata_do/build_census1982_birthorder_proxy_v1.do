*******************************************************
* Build 1982 census co-resident birth-order proxy
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

use "${proj}/data/raw/census/census1982(1).dta", clear
keep serial pernum momloc poploc age sex county edattain

gen birthyr = 1982 - age
keep if inrange(birthyr, 1920, 1960)

* Older sibling counts among co-resident children linked to the same mother/father.
sort serial momloc age pernum
by serial momloc (age pernum): gen older_m = _N - _n if momloc > 0

sort serial poploc age pernum
by serial poploc (age pernum): gen older_p = _N - _n if poploc > 0

gen parent_present = (momloc > 0 | poploc > 0)
gen older_m_any = older_m > 0 if momloc > 0
gen older_p_any = older_p > 0 if poploc > 0
egen any_older_sib_proxy = rowmax(older_m_any older_p_any)
replace any_older_sib_proxy = . if !parent_present

gen firstborn_proxy = (any_older_sib_proxy == 0) if !missing(any_older_sib_proxy)

gen countyid_old6 = county
replace countyid_old6 = . if countyid_old6 <= 0

tempfile proxy
save `proxy', replace

tempname fh
postfile `fh' str40 metric value using "${proj}/data/temp/census1982_birthorder_proxy_audit_v1.dta", replace
quietly count
post `fh' ("adult_obs_1920_1960") (r(N))
quietly count if parent_present == 1
post `fh' ("with_parent_present") (r(N))
quietly count if !missing(any_older_sib_proxy)
post `fh' ("proxy_identifiable") (r(N))
quietly count if any_older_sib_proxy == 1
post `fh' ("any_older_sib_proxy") (r(N))
quietly count if firstborn_proxy == 1
post `fh' ("firstborn_proxy") (r(N))
quietly summarize parent_present
post `fh' ("share_parent_present") (r(mean))
quietly summarize any_older_sib_proxy
post `fh' ("share_any_older_sib_proxy") (r(mean))
quietly summarize firstborn_proxy
post `fh' ("share_firstborn_proxy") (r(mean))
postclose `fh'

use "${proj}/data/temp/census1982_birthorder_proxy_audit_v1.dta", clear
export delimited using "${proj}/result/table/census1982_birthorder_proxy_audit_v1.csv", replace

use `proxy', clear
keep if parent_present == 1
compress
save "${proj}/data/temp/census1982_birthorder_proxy_v1.dta", replace

exit, clear
