clear all
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
di "=== RAW 1990 ==="
describe using "${proj}/data/raw/census/census1990.dta"
di "=== RAW 2000 ==="
describe using "${proj}/data/raw/census/census2000.dta"
exit, clear
