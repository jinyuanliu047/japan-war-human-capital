/*  ================================================================
    POOLED SUMMARY STATISTICS: figures + county-level descriptives.
    Outputs live in paper/assets/figures and paper/assets/tables.
    Uses the pooled 1982+1990+2000 individual microdata.
    ================================================================ */
clear all
global proj "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
global figdir "${proj}/paper/assets/figures"
global tabdir "${proj}/paper/assets/tables"
set maxvar 10000
set scheme s2color

use "${proj}/data/temp/master_pooled_ppml_v1.dta", clear

/* ===== FIGURE 1: distribution of county martyr count =====
   County-level unique rows using max of martyr_count within county.       */
preserve
    keep county_num martyr_count
    duplicates drop
    su martyr_count, d
    local med = r(p50)
    local p99 = r(p99)
    gen martyr_w = min(martyr_count, `p99')
    twoway (hist martyr_w, width(100) fcolor("66 109 148%65") ///
            lcolor("66 109 148") lwidth(thin)), ///
           xline(`med', lpattern(dash) lcolor(cranberry)) ///
           text(.006 `=`med'+50' "median = `=string(`med',"%9.0fc")'", ///
                color(cranberry) place(e)) ///
           xtitle("County martyr count (winsorised at p99)") ///
           ytitle("Density") ///
           graphregion(color(white)) plotregion(color(white))
    graph export "${figdir}/pooled_treatment_distribution_v1.pdf", replace
    graph export "${figdir}/pooled_treatment_distribution_v1.png", replace width(1800)
restore

/* ===== FIGURE 2: cohort size by treatment, pooled =====
   one row = one individual in pooled 1982+1990+2000                       */
preserve
    gen treat = (d_count_high == 1)
    collapse (count) n_indiv = eduy, by(birth_i treat)
    replace n_indiv = n_indiv / 1000
    reshape wide n_indiv, i(birth_i) j(treat)
    label var n_indiv0 "Control (count {&le} 12)"
    label var n_indiv1 "Treatment (count > 12)"
    twoway (bar n_indiv1 birth_i, color("220 115 140%75") lcolor("220 115 140")) ///
           (bar n_indiv0 birth_i, color("90 120 150%60") lcolor("90 120 150")), ///
           xline(1940 1946, lpattern(dash) lcolor(gs8)) ///
           xtitle("Birth year") ///
           ytitle("Number of individuals (thousands), pooled") ///
           legend(order(1 "Treatment (count > 12)" 2 "Control (count {&le} 12)") ///
                  rows(1) position(6) region(lcolor(white))) ///
           graphregion(color(white)) plotregion(color(white))
    graph export "${figdir}/pooled_cohort_size_by_treatment_v1.pdf", replace
    graph export "${figdir}/pooled_cohort_size_by_treatment_v1.png", replace width(1800)
restore

/* ===== TABLE: county-level descriptives =====                             */
preserve
    keep county_num martyr_count ihs_rate d_count_high
    duplicates drop
    count
    local Ncty = r(N)
    su martyr_count, d
    local mc_mean = r(mean)
    local mc_sd   = r(sd)
    local mc_p25  = r(p25)
    local mc_p50  = r(p50)
    local mc_p75  = r(p75)
    local mc_p99  = r(p99)
    su ihs_rate, d
    local ih_mean = r(mean)
    local ih_sd   = r(sd)
    local ih_p25  = r(p25)
    local ih_p50  = r(p50)
    local ih_p75  = r(p75)
    su d_count_high
    local dh_mean = r(mean)

    tempname fh
    file open `fh' using "${tabdir}/pooled_county_treatment_sumstats_v1.tex", write replace
    file write `fh' "{" _n
    file write `fh' "\begin{tabular*}{\linewidth}{@{\extracolsep{\fill}}lcccccc}" _n
    file write `fh' "\toprule" _n
    file write `fh' "            & Mean & SD & p25 & p50 & p75 & p99\\" _n
    file write `fh' "\midrule" _n
    file write `fh' "Martyr count"
    file write `fh' "&" %9.1fc (`mc_mean') "&" %9.1fc (`mc_sd')
    file write `fh' "&" %9.0fc (`mc_p25') "&" %9.0fc (`mc_p50')
    file write `fh' "&" %9.0fc (`mc_p75') "&" %9.0fc (`mc_p99') "\\" _n
    file write `fh' "IHS(martyrs per 100k)"
    file write `fh' "&" %7.3f (`ih_mean') "&" %7.3f (`ih_sd')
    file write `fh' "&" %7.3f (`ih_p25') "&" %7.3f (`ih_p50')
    file write `fh' "&" %7.3f (`ih_p75') "& \\" _n
    file write `fh' "Above-median dummy"
    file write `fh' "&" %7.3f (`dh_mean') "& & & & & \\" _n
    file write `fh' "\midrule" _n
    file write `fh' "Counties&\multicolumn{6}{c}{" %9.0fc (`Ncty') "}\\" _n
    file write `fh' "\bottomrule" _n
    file write `fh' "\end{tabular*}" _n
    file write `fh' "}" _n
    file close `fh'
restore

di "=== POOLED SUMMARY STATS FIGURES & TABLE COMPLETE ==="
