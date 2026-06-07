clear all
set more off
local proj "/tmp/jwrepo"
use workst in 1/10 using "`proj'/data/raw/census/census2000.dta", clear
label list r17_lab
