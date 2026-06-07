# Table Format Guide

## Core rule
Every regression table should follow the same structure:
- keep the model numbering row `(1) (2) (3) ...`
- add a second header row with meaningful column titles
- a readable coefficient label
- readable footer labels
- the same order of footer rows

## Standard column naming
Use one of these patterns:

### Pattern A: baseline + one-by-one robustness
- `Baseline`
- `+ SDY density × Post`
- `+ Famine × Post`
- `+ Victims × Post`
- `+ Grain output × Post`
- `+ Urbanization × Post`

### Pattern B: cross-wave comparison
- `1982 baseline`
- `1982 + all five`
- `1990 baseline`
- `1990 + all five`
- `2000 baseline`
- `2000 + all five`

### Pattern C: subgroup heterogeneity
- `Male`
- `Female`
- `Urban`
- `Rural`
- `Low base education`
- `Middle base education`
- `High base education`

## Standard coefficient label
Use:
- `Post × War exposure`

Avoid raw Stata interaction names in final paper tables.

## Standard footer labels
Always use this order when applicable:
- `Individual controls`
- `County history control`
- `County FE`
- `Cohort FE`
- `Treatment start`
- `Observations`
- `R-squared`
- `Adj. R-squared`

## esttab template
```stata
esttab model1 model2 model3 using "...tex", ///
    replace ///
    keep(1.post#c.ln_martyr_per100k_1953) ///
    coeflabels(1.post#c.ln_martyr_per100k_1953 "Post × War exposure") ///
    mtitles("Baseline" "+ SDY density × Post" "+ Famine × Post") ///
    stats(Controls Hist_Control County_FE Cohort_FE Cutoff N r2 ar2, ///
        labels("Individual controls" "County history control" "County FE" "Cohort FE" "Treatment start" "Observations" "R-squared" "Adj. R-squared")) ///
    se ///
    star(* 0.1 ** 0.05 *** 0.01)
```
