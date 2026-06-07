*******************************************************
* Formal heterogeneity summary for paper tables
* Outputs one long CSV, later rendered into wave x cutoff tables
*******************************************************

clear all
set more off

global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"

capture which reghdfe
if _rc != 0 ssc install reghdfe, replace

use "${proj}/data/temp/antijap_base_broad_indicator_v1.dta", clear
keep countyid_curr6 base_broad_any
replace countyid_curr6 = substr("000000" + countyid_curr6, strlen("000000" + countyid_curr6)-5, 6)
duplicates drop countyid_curr6, force
tempfile basebroad
save `basebroad'
global HET_BASEBROAD "`basebroad'"

tempname memhold
postfile `memhold' int cutoff int wave str12 panel str20 subgroup double b se p n_cells n_counties using "${proj}/result/table/formal_heterogeneity_summary_v1_tmp.dta", replace
global HET_MEMHOLD "`memhold'"

capture program drop _post_result
program define _post_result
    syntax , CUTOFF(integer) WAVE(integer) PANEL(string) SUBGROUP(string)
    local b = _b[1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    quietly count
    local n_cells = r(N)
    egen __tag = tag(countyid_curr6)
    quietly count if __tag
    local n_counties = r(N)
    drop __tag
    post $HET_MEMHOLD (`cutoff') (`wave') ("`panel'") ("`subgroup'") (`b') (`se') (`p') (`n_cells') (`n_counties')
end

capture program drop _run_gender_panel
program define _run_gender_panel
    syntax , PANELFILE(string) CUTOFF(integer) WAVE(integer) SUBGROUP(string) DROPYEAR(integer)
    import delimited "`panelfile'", clear varnames(1) stringcols(1)
    drop if birth_i == `dropyear'
    gen post = birth_i >= `cutoff'
    egen county_num = group(countyid_curr6)
    reghdfe eduy_mean c.ln_martyr_per100k_1953##i.post minority_share [aw=n], absorb(county_num birth_i) vce(cluster county_num)
    _post_result, cutoff(`cutoff') wave(`wave') panel("gender") subgroup("`subgroup'")
end

capture program drop _run_urban_panel
program define _run_urban_panel
    syntax , PANELFILE(string) CUTOFF(integer) WAVE(integer) SUBGROUP(string) DROPYEAR(integer)
    import delimited "`panelfile'", clear varnames(1) stringcols(1)
    drop if birth_i == `dropyear'
    gen post = birth_i >= `cutoff'
    egen county_num = group(countyid_curr6)
    reghdfe eduy_mean c.ln_martyr_per100k_1953##i.post minority_share [aw=n], absorb(county_num birth_i) vce(cluster county_num)
    _post_result, cutoff(`cutoff') wave(`wave') panel("urban") subgroup("`subgroup'")
end

capture program drop _run_gender_diff
program define _run_gender_diff
    syntax , FEMALEFILE(string) MALEFILE(string) CUTOFF(integer) WAVE(integer) DROPYEAR(integer)
    import delimited "`femalefile'", clear varnames(1) stringcols(1)
    gen female_group = 1
    tempfile female
    save `female'
    import delimited "`malefile'", clear varnames(1) stringcols(1)
    gen female_group = 0
    append using `female'
    drop if birth_i == `dropyear'
    gen post = birth_i >= `cutoff'
    egen county_num = group(countyid_curr6)
    reghdfe eduy_mean c.ln_martyr_per100k_1953##i.post##ib0.female_group minority_share [aw=n], absorb(county_num birth_i female_group) vce(cluster county_num)
    local b = _b[1.female_group#1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.female_group#1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    quietly count
    local n_cells = r(N)
    egen __tag = tag(countyid_curr6)
    quietly count if __tag
    local n_counties = r(N)
    drop __tag
    post $HET_MEMHOLD (`cutoff') (`wave') ("gender") ("group_diff") (`b') (`se') (`p') (`n_cells') (`n_counties')
end

capture program drop _run_urban_diff
program define _run_urban_diff
    syntax , URBANFILE(string) RURALFILE(string) CUTOFF(integer) WAVE(integer) DROPYEAR(integer)
    import delimited "`urbanfile'", clear varnames(1) stringcols(1)
    gen urban_group = 1
    tempfile urban
    save `urban'
    import delimited "`ruralfile'", clear varnames(1) stringcols(1)
    gen urban_group = 0
    append using `urban'
    drop if birth_i == `dropyear'
    gen post = birth_i >= `cutoff'
    egen county_num = group(countyid_curr6)
    reghdfe eduy_mean c.ln_martyr_per100k_1953##i.post##ib0.urban_group minority_share [aw=n], absorb(county_num birth_i urban_group) vce(cluster county_num)
    local b = _b[1.urban_group#1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.urban_group#1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    quietly count
    local n_cells = r(N)
    egen __tag = tag(countyid_curr6)
    quietly count if __tag
    local n_counties = r(N)
    drop __tag
    post $HET_MEMHOLD (`cutoff') (`wave') ("urban") ("group_diff") (`b') (`se') (`p') (`n_cells') (`n_counties')
end

capture program drop _run_county_panels
program define _run_county_panels
    syntax , WAVE(integer) CUTOFF(integer) DROPYEAR(integer) HI(integer)
    use "${proj}/data/temp/did_`wave'_county_birthyr_pop1953_unwt_v2.dta", clear
    tostring countyid_curr6, replace force format(%06.0f)
    gen birth_i = floor(birthyr)
    keep if inrange(birth_i, 1920, `hi')
    drop if birth_i == `dropyear'
    keep if !missing(eduy_mean, ln_martyr_per100k_1953, n_obs)
    merge m:1 countyid_curr6 using "$HET_BASEBROAD", keep(master match) nogen
    replace base_broad_any = 0 if missing(base_broad_any)
    gen post = birth_i >= `cutoff'
    egen county_num = group(countyid_curr6)
    egen __tag = tag(county_num)
    egen __base = mean(eduy_mean) if inrange(birth_i, 1920, 1938), by(county_num)
    sort county_num birth_i
    by county_num: egen __base_fill = max(__base)
    replace __base = __base_fill if missing(__base)
    quietly summarize __base
    replace __base = r(mean) if missing(__base)
    xtile __be_ter = __base if __tag==1, nq(3)
    by county_num: egen baseedu_tercile = max(__be_ter)
    drop __tag __base __base_fill __be_ter

    foreach g in 1 2 3 {
        preserve
        keep if baseedu_tercile == `g'
        reghdfe eduy_mean c.ln_martyr_per100k_1953##i.post [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
        local subgroup = cond(`g'==1,"B1",cond(`g'==2,"B2","B3"))
        _post_result, cutoff(`cutoff') wave(`wave') panel("baseedu") subgroup("`subgroup'")
        restore
    }

    reghdfe eduy_mean c.ln_martyr_per100k_1953##i.post##ib3.baseedu_tercile [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.baseedu_tercile#1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.baseedu_tercile#1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    quietly count
    local n_cells = r(N)
    egen __tag = tag(countyid_curr6)
    quietly count if __tag
    local n_counties = r(N)
    drop __tag
    post $HET_MEMHOLD (`cutoff') (`wave') ("baseedu") ("low_high_diff") (`b') (`se') (`p') (`n_cells') (`n_counties')

    local b = _b[2.baseedu_tercile#1.post#c.ln_martyr_per100k_1953]
    local se = _se[2.baseedu_tercile#1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    post $HET_MEMHOLD (`cutoff') (`wave') ("baseedu") ("mid_high_diff") (`b') (`se') (`p') (`n_cells') (`n_counties')

    foreach g in 0 1 {
        preserve
        keep if base_broad_any == `g'
        reghdfe eduy_mean c.ln_martyr_per100k_1953##i.post [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
        local subgroup = cond(`g'==0,"base0","base1")
        _post_result, cutoff(`cutoff') wave(`wave') panel("antijap") subgroup("`subgroup'")
        restore
    }

    reghdfe eduy_mean c.ln_martyr_per100k_1953##i.post##ib0.base_broad_any [aw=n_obs], absorb(county_num birth_i) vce(cluster county_num)
    local b = _b[1.base_broad_any#1.post#c.ln_martyr_per100k_1953]
    local se = _se[1.base_broad_any#1.post#c.ln_martyr_per100k_1953]
    local p = 2*ttail(e(df_r), abs(`b'/`se'))
    quietly count
    local n_cells = r(N)
    egen __tag = tag(countyid_curr6)
    quietly count if __tag
    local n_counties = r(N)
    drop __tag
    post $HET_MEMHOLD (`cutoff') (`wave') ("antijap") ("group_diff") (`b') (`se') (`p') (`n_cells') (`n_counties')
end

foreach cutoff in 1940 1946 {
    local dropyear = cond(`cutoff'==1940, 1939, 1945)

    foreach wave in 1982 1990 2000 {
        local femalefile = "${proj}/data/temp/heterogeneity_groups_v4/panel_`wave'_female.csv"
        local malefile = "${proj}/data/temp/heterogeneity_groups_v4/panel_`wave'_male.csv"
        quietly capture confirm file "`femalefile'"
        if !_rc {
            _run_gender_panel, panelfile("`femalefile'") cutoff(`cutoff') wave(`wave') subgroup("female") dropyear(`dropyear')
        }
        quietly capture confirm file "`malefile'"
        if !_rc {
            _run_gender_panel, panelfile("`malefile'") cutoff(`cutoff') wave(`wave') subgroup("male") dropyear(`dropyear')
        }
        quietly capture confirm file "`femalefile'"
        if !_rc {
            quietly capture confirm file "`malefile'"
            if !_rc {
                _run_gender_diff, femalefile("`femalefile'") malefile("`malefile'") cutoff(`cutoff') wave(`wave') dropyear(`dropyear')
            }
        }
    }

    foreach wave in 1990 2000 {
        local urbanfile = "${proj}/data/temp/heterogeneity_groups_v4/panel_`wave'_urban.csv"
        local ruralfile = "${proj}/data/temp/heterogeneity_groups_v4/panel_`wave'_rural.csv"
        _run_urban_panel, panelfile("`urbanfile'") cutoff(`cutoff') wave(`wave') subgroup("urban") dropyear(`dropyear')
        _run_urban_panel, panelfile("`ruralfile'") cutoff(`cutoff') wave(`wave') subgroup("rural") dropyear(`dropyear')
        _run_urban_diff, urbanfile("`urbanfile'") ruralfile("`ruralfile'") cutoff(`cutoff') wave(`wave') dropyear(`dropyear')
    }

    _run_county_panels, wave(1982) cutoff(`cutoff') dropyear(`dropyear') hi(1960)
    _run_county_panels, wave(1990) cutoff(`cutoff') dropyear(`dropyear') hi(1968)
    _run_county_panels, wave(2000) cutoff(`cutoff') dropyear(`dropyear') hi(1978)
}

postclose $HET_MEMHOLD
use "${proj}/result/table/formal_heterogeneity_summary_v1_tmp.dta", clear
sort cutoff wave panel subgroup
export delimited using "${proj}/result/table/formal_heterogeneity_summary_v1.csv", replace
erase "${proj}/result/table/formal_heterogeneity_summary_v1_tmp.dta"

exit, clear
