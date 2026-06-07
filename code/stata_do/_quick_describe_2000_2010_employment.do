clear all
set more off

local proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture noisily use uid birthyr eduyr race using "`proj'/data/raw/census/census2000.dta", clear
capture noisily describe
capture noisily describe uid birthyr eduyr race

capture noisily use "`proj'/data/raw/census/census2010.dta", clear
capture noisily describe
