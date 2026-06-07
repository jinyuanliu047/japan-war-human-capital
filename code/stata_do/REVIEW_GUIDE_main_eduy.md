# Main EdUY Review Guide

This note maps the current `individual eduy` main-analysis scripts to the tables used in the paper draft.

## Main text

- `check_main_micro_eduy_1990_onebyone_controls_v1.do`
  - Purpose: preferred main analysis.
  - Outcome: individual-level `eduy`.
  - Wave: `1990`.
  - Treatment timing: `post = 1[birth_i >= 1946]`, with `1945` dropped.
  - Controls: baseline `minority`; then each county historical characteristic is added one at a time as `Z#post`.
  - Outputs:
    - `result/table/main_micro_eduy_1990_onebyone_controls_v1.csv`
    - `result/table/main_micro_eduy_1990_onebyone_controls_v1.rtf`
    - `result/table/main_micro_eduy_1990_onebyone_controls_v1.tex`

## Appendix baseline across waves

- `check_main_micro_eduy_cutoff1946_mainstyle_v1.do`
  - Purpose: appendix version of the same individual-level specification across `1982`, `1990`, and `2000`.
  - Outcome: individual-level `eduy`.
  - Treatment timing: `post = 1[birth_i >= 1946]`, with `1945` dropped.
  - Controls: baseline `minority`; plus an "all five together" historical-control comparison for each wave.
  - Outputs:
    - `result/table/main_micro_eduy_cutoff1946_mainstyle_v1.csv`
    - `result/table/main_micro_eduy_cutoff1946_mainstyle_v1.rtf`
    - `result/table/main_micro_eduy_cutoff1946_mainstyle_v1.tex`

## How the code is organized

- Each script is written as a straight sequence:
  - county treatment/control preparation
  - county code crosswalk preparation
  - regression sample construction
  - regressions
  - table export
  - summary CSV export
- There are no helper programs and no regression loops in these review-target scripts.
- The only remaining short loops are for replacing missing county controls with zero, which is purely mechanical.
