/* Quick replot — reads coefficients from log, no data reload needed */
clear all
set more off

global outdir "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war/paper/assets/figures"

input int(year) double(beta se)
1920  .0211219  .0131251
1921  .0170894  .0114661
1922  .0214985  .0116536
1923  .0098336  .0119693
1924  .012247   .0115483
1925  .0054151  .0108172
1926 -.0050015  .0102978
1927 -.0066268  .010705
1928 -.0042366  .0101673
1929 -.0109257  .0097121
1930 -.0137657  .0096326
1931 -.0221875  .0092168
1932 -.0140998  .0086938
1933 -.0129091  .008413
1934 -.0015313  .0076203
1935 -.0074556  .0069419
1936 -.0125587  .0064283
1937 -.0077535  .005912
1938 -.0095844  .005515
1939  0         0
1940  .0091297  .0056474
1941  .0062091  .0066001
1942  .03133    .0070851
1943  .0210288  .0070339
1944  .0318855  .0073198
1945  .0394236  .0071442
1946  .0351162  .0070565
1947  .0369618  .0078249
1948  .0253941  .007799
1949  .0366949  .0078
1950  .029191   .0083432
1951  .0339783  .0086953
1952  .0300617  .0096864
1953  .0321628  .0096353
1954  .0241355  .0094464
1955  .034381   .0093141
1956  .0336036  .0092808
end

gen ci_lo = beta - 1.96*se
gen ci_hi = beta + 1.96*se

twoway (rarea ci_lo ci_hi year, color(gs14) lwidth(none)) ///
       (connected beta year, mcolor(navy) lcolor(navy) msize(vsmall) lwidth(medthin) msymbol(circle)) ///
       (scatteri 0 1939, mcolor(cranberry) msize(medlarge) msymbol(diamond)), ///
    xline(1940, lcolor(cranberry) lpattern(dash) lwidth(medthin)) ///
    xline(1946, lcolor(dkorange) lpattern(dash) lwidth(medthin)) ///
    yline(0, lcolor(gs10) lpattern(solid) lwidth(thin)) ///
    xlabel(1920(5)1955, labsize(small)) ///
    ylabel(-0.04(0.02)0.06, labsize(small) format(%5.2f) angle(horizontal)) ///
    xtitle("Birth cohort", size(medsmall)) ///
    ytitle("Coefficient on IHS(martyrs per 100k) x cohort", size(medsmall)) ///
    title("") ///
    note("Base year: 1939 (diamond). Shaded area: 95% CI, SE clustered at county level." ///
         "County, birth-year, and wave FE absorbed. Dashed lines: 1940 and 1946 cutoffs.", size(vsmall)) ///
    legend(off) ///
    graphregion(color(white)) plotregion(margin(small)) ///
    scheme(s2color)
graph export "${outdir}/eventstudy_pooled_ihs_v1.pdf", replace
graph export "${outdir}/eventstudy_pooled_ihs_v1.png", replace width(2400)

di "=== Replot done ==="
exit, clear
