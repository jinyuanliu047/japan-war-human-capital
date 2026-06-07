*******************************************************
* Heterogeneity screening (reghdfejl)
* County-level pre-determined environment variables
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which reghdfejl
if _rc != 0 {
    di as error "reghdfejl not found"
    exit 198
}

use "${proj}/data/temp/county_controls_full_heritage_v2.dta", clear
keep countyid_curr6 urbanratio64 ln_clan qk_maxmag_pre1940 ins_famine sdy_density ///
    junior_graduate heritage_any
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
foreach v in urbanratio64 ln_clan qk_maxmag_pre1940 ins_famine sdy_density junior_graduate heritage_any {
    replace `v' = 0 if missing(`v')
}
duplicates drop countyid_curr6, force
tempfile ctrl
save `ctrl'
global ctrl_tmp "`ctrl'"

capture program drop _prep_wave
program define _prep_wave
    syntax , WAVE(integer) HI(integer)
    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    keep if inrange(birthyr,1920,`hi')
    drop if floor(birthyr)==1939
    keep if !missing(eduy_mean) & !missing(ln_martyr_per100k_1953)
    drop if countyid_curr6=="" | countyid_curr6=="000000"
    merge m:1 countyid_curr6 using "$ctrl_tmp", keep(master match) nogen
    foreach v in urbanratio64 ln_clan qk_maxmag_pre1940 ins_famine sdy_density junior_graduate heritage_any {
        replace `v' = 0 if missing(`v')
    }
    gen birth_i = floor(birthyr)
    gen post = birth_i >= 1940
    egen county_num = group(countyid_curr6)
end

capture program drop _make_group
program define _make_group
    syntax , VAR(name) MODE(string)
    egen __tag = tag(county_num)
    if "`mode'"=="median" {
        quietly summarize `var' if __tag==1, detail
        local med = r(p50)
        gen grp = (`var' > `med')
    }
    else if "`mode'"=="binary" {
        gen grp = (`var' > 0)
    }
    else {
        di as error "unknown mode"
        exit 198
    }
    replace grp = 0 if missing(grp)
    drop __tag
end

tempname posth
tempfile out
postfile `posth' str18 dim int wave str4 grp double b se p long n_cells using "`out'", replace
global POSTH "`posth'"

local dims "urbanratio64 median ln_clan median qk_maxmag_pre1940 median ins_famine median sdy_density median junior_graduate median heritage_any binary"

foreach w in 1982 1990 2000 {
    local hi = 1960
    if "`w'"=="1990" local hi = 1968
    if "`w'"=="2000" local hi = 1978

    quietly _prep_wave, wave(`w') hi(`hi')
    tempfile panel
    save `panel', replace

    tokenize `dims'
    while "`1'"!="" {
        local dim "`1'"
        local mode "`2'"
        macro shift 2

        use `panel', clear
        quietly _make_group, var(`dim') mode("`mode'")

        forvalues g = 0/1 {
            quietly count if grp==`g'
            local n = r(N)
            quietly reghdfejl eduy_mean c.ln_martyr_per100k_1953##ib0.post if grp==`g', ///
                absorb(county_num birth_i) vce(cluster county_num)
            local b = _b[1.post#c.ln_martyr_per100k_1953]
            local se = _se[1.post#c.ln_martyr_per100k_1953]
            local p = 2*ttail(e(df_r), abs(`b'/`se'))
            post $POSTH ("`dim'") (`w') ("G`g'") (`b') (`se') (`p') (`n')
        }
    }
}

postclose `posth'
use "`out'", clear
gen t_abs = abs(b/se)
sort dim wave grp
export delimited using "${proj}/result/table/heterogeneity_screen_reghdfejl_summary_v1.csv", replace
save "${proj}/result/table/heterogeneity_screen_reghdfejl_summary_v1.dta", replace

exit, clear
