# Robustness and Heterogeneity Review Guide

This note summarizes which robustness and heterogeneity blocks are worth keeping in the paper draft and which Stata scripts currently generate them.

## Keep in main text

### 1. 1990 individual-level baseline with historical characteristics added one by one

- Script:
  - `check_main_micro_eduy_1990_onebyone_controls_v1.do`
- Purpose:
  - preferred main analysis
  - outcome: `eduy`
  - wave: `1990`
  - treatment timing: `post = 1[birth_i >= 1946]`, with `1945` dropped
  - historical county characteristics are added one at a time as `Z#post`
- Output:
  - `main_micro_eduy_1990_onebyone_controls_v1.csv`
  - `main_micro_eduy_1990_onebyone_controls_v1.rtf`
  - `main_micro_eduy_1990_onebyone_controls_v1.tex`

### 2. Base-education heterogeneity

- Script:
  - `check_main_heterogeneity_pack_reghdfejl_v1.do`
- Relevant block:
  - `baseedu_tercile`
- Reason to keep:
  - low-base group is consistently strongest
  - high-base group is weak or close to zero

### 3. Gender heterogeneity

- Script:
  - `check_main_gender_urban_reghdfejl_v4.do`
- Relevant output:
  - `main_individual_heterogeneity_gender_reghdfejl_summary_v4.csv`
- Reason to keep:
  - male effect is stronger in every wave
  - female effect becomes positive in later waves

## Keep in appendix

### 4. Cross-wave baseline table

- Script:
  - `check_main_micro_eduy_cutoff1946_mainstyle_v1.do`
- Purpose:
  - same individual-level specification across `1982`, `1990`, and `2000`
- Note:
  - use this as wave-by-wave robustness, not as the lead table

### 5. IHS and PPML

- Script:
  - `check_main_ihs_ppml_reghdfejl_v1.do`
- Reason:
  - useful functional-form robustness
  - current script is still loop-heavy
  - no need to review this before reviewing the main specification

### 6. Long March / Korea-war proxies

- Script:
  - `check_main_longmarch_korea_robustness_reghdfejl_v1.do`
- Reason:
  - coefficient remains positive in all waves after these additional controls
  - conceptually useful appendix robustness
  - current script is still loop-heavy

### 7. Urban-rural heterogeneity

- Script:
  - `check_main_gender_urban_reghdfejl_v4.do`
- Relevant output:
  - `main_individual_heterogeneity_urbanrural_reghdfejl_summary_v4.csv`
- Reason to demote:
  - sign flips across waves
  - not a stable structural margin

## Do not prioritize for cleanup

### 8. Memorial heterogeneity
- Reason:
  - unstable and hard to interpret

### 9. Massacre heterogeneity
- Reason:
  - not clean enough for the main text

### 10. Treatment-tercile heterogeneity
- Reason:
  - high-intensity group can turn negative
  - not the shape the paper wants to emphasize

## Preferred treatment measurement for heterogeneity

- Main text:
  - `ln_martyr_per100k_1953`
- Appendix alternatives:
  - `ihs_per100k`
  - `ln_raw`
- Do not lead with:
  - `raw_count`
  - `share_winsor`
  - `ihs_share`

## Code review priority

If reviewing code in order, the most useful sequence is:

1. `check_main_micro_eduy_1990_onebyone_controls_v1.do`
2. `check_main_micro_eduy_cutoff1946_mainstyle_v1.do`
3. `check_main_gender_urban_reghdfejl_v4.do`
4. `check_main_ihs_ppml_reghdfejl_v1.do`
5. `check_main_longmarch_korea_robustness_reghdfejl_v1.do`

This order matches the current paper structure and avoids spending review time first on weak appendix-only blocks.
