clear all
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
di "=== RAW 1990 ==="
capture describe using "${proj}/data/raw/census/census1990.dta"
if _rc != 0 {
    di "File not found, checking alternatives..."
    local files : dir "${proj}/data/raw/census" files "*.dta"
    foreach f of local files {
        di "  `f'"
    }
}
di "=== RAW 2000 ==="
capture describe using "${proj}/data/raw/census/census2000.dta"
di "=== RAW 1982 ==="
capture describe using "${proj}/data/raw/census/census1982.dta"
if _rc != 0 {
    capture describe using "${proj}/data/temp/census_1982_cleaned.dta"
}
exit, clear
