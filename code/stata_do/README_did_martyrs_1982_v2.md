# DID setup (1982 census x 抗战烈士籍贯强度)

## Data inputs
- `data/temp/census_1982_cleaned.dta`
- `data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts_merge_ready.csv`
- `data/raw/China_Map/County0010.xlsx`

## Main generated files
- `data/temp/countyid_1982_to_current_crosswalk_v2.csv`
- `data/temp/countyid_1982_to_current_unmatched_strict_v2.csv`
- `data/temp/did_1982_county_birthyr_martyr_native_v2.csv`
- `data/temp/did_1982_county_birthyr_martyr_native_v2.dta`
- `data/temp/did_1982_county_code_harmonization_summary_v2.csv`

## Key construction
- Treatment intensity (county-level):  
  `ln_martyr_native_count = ln(1 + martyr_native_count_1931_1945)`
- Outcome:  
  `eduy_wmean` (cell-weighted mean of `eduy`, weight = `perwt`)
- Panel unit:  
  `countyid_curr6 x birthyr`

## County harmonization logic
- `strict` mapping: code/name exact + conservative fuzzy + known successor rules
- `final` mapping: strict first; unresolved rows use deterministic fallback routes
- mapping quality variable in panel: `strict_share_wt`

## Cohort definitions
- `schoolage_war = 1[1925 <= birthyr <= 1939]` (school-entry age during 1931-1945)
- `wartime_birth = 1[1931 <= birthyr <= 1945]`
- `postwar_birth = 1[1946 <= birthyr <= 1955]`

## Regression skeleton
`eduy_wmean_{cb} = beta * ln_martyr_c * exposed_b + county FE + birth-year FE + e_{cb}`

Implemented in:
- `code/stata_do/did_martyrs_eduy_1982_v2.do`
