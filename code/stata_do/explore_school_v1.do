clear all
set more off
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

use "${proj}/data/raw/rural_school_expansion.dta", clear
describe
summarize
list in 1/10

use "${proj}/data/raw/county_year_data.dta", clear
describe
tab year
summ fiscal_edu school_primary school_secondary if !missing(fiscal_edu)

forvalues y = 1949/2000 {
    quietly count if year == `y' & !missing(fiscal_edu)
    if r(N) > 0 {
        di "Year `y': fiscal_edu N = " r(N)
    }
}
forvalues y = 1949/2000 {
    quietly count if year == `y' & !missing(school_primary)
    if r(N) > 0 {
        di "Year `y': school_primary N = " r(N)
    }
}

exit, clear
