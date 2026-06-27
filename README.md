# War and Human Capital Accumulation: Evidence from the Second Sino-Japanese War

Replication code for the working paper *"War and Human Capital Accumulation:
Evidence from the Second Sino-Japanese War"* by **Jinyuan Liu** and **Yizheng Wang**
(Renmin University of China; the authors contributed equally and are listed
alphabetically by surname).

The paper studies why some societies rebuild after catastrophic war while others
stagnate. It exploits county-level variation in the intensity of state-recognized
Anti-Japanese War martyrs (1931–1945), built from an original dataset of digitized
individual martyr records, and estimates a cohort difference-in-differences on
pooled microdata from the 1982, 1990, and 2000 Chinese population censuses.

This repository contains **code only**. The census microdata and the other
licensed inputs are not redistributed (see *Data*).

---

## Empirical design in one paragraph

County-level treatment is per-capita martyr intensity (inverse-hyperbolic-sine
transformed), using the 1953 county population as the denominator; a binary
above-median count is the alternative. The main specification is a cohort
difference-in-differences comparing pre- and post-war birth cohorts across counties
of different wartime-loss intensity:

```
Y_icw = β (Post_i × X_c) + γ Z_i + λ_c + δ_b + μ_w + ε_icw
```

with county (`λ_c`), birth-year (`δ_b`), and census-wave (`μ_w`) fixed effects and
standard errors clustered at the county level. The post-war cutoff is 1940 (primary)
or 1946 (stricter); birth cohorts run 1920–1956. The estimation sample covers about
9.2 million individuals across 2,193 counties (the martyr registry yields counts for
2,296 counties, of which 2,193 merge to the harmonized census geography). Main
estimator: `reghdfe` / `reghdfejl`; functional-form check: `ppmlhdfe`.

---

## Pipeline

The repository runs top to bottom. Python builds the datasets; Stata estimates and
exports the tables and figures. Each script sets an absolute project path near the
top; update it to your local tree before running.

### 1. Data collection
- `code/python/scrape_chinamartyrs.py` — multithreaded scraper for the national
  martyr registry (paginated JSON API, retries with backoff, incremental
  checkpointing).

### 2. Treatment construction (martyr records → county intensity)
- `code/python/build_place_counts_1931_1945.py`
- `code/python/build_place_counts_1931_1945_clean.py` — geocodes free-text Chinese
  place strings to modern county codes with a tiered fallback rule. Builds both the
  native-place (*jiguan*, baseline) and place-of-sacrifice measures.
- `code/python/build_place_counts_1931_1945_merge_ready.py`

### 3. Census microdata (IPUMS-International) and geography harmonization
The census panels use the IPUMS-International harmonized 1982/1990/2000 extracts.
- `code/python/extract_ipums_slim_v1.awk` — slim the raw IPUMS fixed-width extract.
- `code/stata_do/ipums_read_dict_v1.dct` — Stata dictionary for the slim extract.
- `code/python/build_ipums_geo3_to_curr6_crosswalk_v2.py` — map IPUMS
  consistent-boundary county codes (`GEO3_CN1982/1990/2000`) to current GB six-digit
  county codes, one wave at a time (pinyin / stripped-name matching, division-change
  history, city fallback).
- `code/python/audit_ipums_geo3_crosswalk_v1.py` — crosswalk match-rate audit.
- `code/stata_do/build_ipums_pooled_master_v1.do` — assemble the pooled master file
  (`master_pooled_ipums_v1.dta`) from the census panels, the martyr treatment, and
  the county controls. **All regressions read this master.**
- `code/stata_do/check_ipums_baseline_v1.do` — reproduces the baseline on the master.

### 4. Historical and mechanism controls
- `code/python/build_county_extended_controls_v1.py` — county controls and the
  clan / earthquake control set (clan presence from the *General Catalogue of
  Chinese Genealogies*).
- `code/python/build_revolutionary_proxy_controls_v1.py`
- `code/python/build_county_y_panels_v3.py` — county fiscal-education year panel.
- `code/python/build_chip1995_edu_pooled_pref_micro_v1.py` — CHIP 1995 micro inputs.

### 5. Main results
| Script | Paper output |
| --- | --- |
| `check_summary_stats_pooled_v2.do` | Table 1 — summary statistics |
| `check_pooled_figures_v1.do` | Table 2 — suggestive 2×2 evidence |
| `check_pooled_main_paper_v1.do` | Tables 3–4 — baseline DID (1940 / 1946) |
| `check_pooled_hist_lmk_expanded_v1.do` | Tables 5–6 — historical controls; Long March / Korea placebo |
| `robust_wartime_inflation_v1.do` | Table 7 — provincial wartime price-inflation control |
| `check_pooled_all_remaining_v1.do` | Tables 8–9 — heterogeneity by gender and pre-war education |
| `check_pooled_het_clan_treatyport_v1.do` | Heterogeneity by ancestral clan and treaty-port status |
| `career_pooled_v1.do` | Mechanism — occupational sorting (pooled, nine ISCO groups) |
| `check_pooled_mechanism_ihs_dummy_v1.do` | Mechanism — career choice, CGSS, CHIP |
| `check_collectivism_ihs_dummy_v1.do` | Mechanism — collectivism (province) |
| `check_collectivesim_province_prefecture_v1.do` (+ `.py`) | Mechanism — collectivism (prefecture) |
| `check_mechanism_county_panel_v3.do` | Mechanism — local fiscal education spending |
| `check_additional_party_military_v2.do` | Party membership and military service |

### 6. Robustness and the online appendix
| Script | Appendix output |
| --- | --- |
| `pooled_sumstats_figures_v1.do` | Appendix B — county treatment distribution table and figures |
| `did_martyrs_eduy_pooled_sacrifice_v2.do` | Appendix E — sacrifice-place robustness (all tables) |
| `pooled_ppml_vs_ols_v1.do` | Appendix F — OLS vs. PPML |
| `check_pooled_nonmigrant_v1.do` | Appendix G — non-mover subsample |
| `check_enrollment_pooled_v2.do` | Appendix H — schooling-margin decomposition (1940 / 1946) |
| `check_enrollment_robustness_v1.do` | Appendix H — schooling margins by sex and with historical controls |

Appendices A (martyr registry and data construction), C (why the 1940 cutoff), and
D (donut difference-in-differences and additional robustness) are documented in the
paper; the donut, dose-response, permutation, and leave-one-province-out checks run
off the same master and estimation scripts above.

### 7. Figures
- `check_pooled_eventstudy_v1.do` — event study, IHS treatment.
- `check_pooled_eventstudy_dummy_v1.do` — event study, above-median treatment.
- `check_pooled_residualized_fig_v1.do` — cohort profiles of schooling and gaps.
- `code/python/plot_china_map_from_shp.py` — martyr-intensity maps.

---

## Software

- **Python 3** with `pandas`, `numpy`, `requests`, `matplotlib`, `geopandas`.
- **Stata** with `reghdfe`, `reghdfejl`, `ppmlhdfe`, and `estout` (`esttab`).
  Do-files install missing packages automatically via `ssc install`.

---

## Data

The paper combines several sources, none of which is redistributed here:

- **Chinese Martyrs Website** — *Zhonghua Yinglie Wang*, the national martyr registry
  of the Ministry of Veterans Affairs of the PRC; collected with
  `scrape_chinamartyrs.py`.
- **Chinese population census microdata** (1982 / 1990 / 2000), via the harmonized
  **IPUMS-International** extracts (`ipums.org`), accessed under the IPUMS terms of use.
- **General Catalogue of Chinese Genealogies** (*Zhongguo Jiapu Zongmu*, Shanghai
  Library) — county ancestral-clan presence.
- **CGSS** (Chinese General Social Survey) and **CHIP** (China Household Income
  Project) — mechanism analyses, from their respective providers.
- **County historical controls** — NBS series and county statistical yearbooks.
- **Modern China Economic Index Database** (*jjzs.nlcpress.com*, National Library of
  China Press) — provincial wartime price inflation (Table 7).
- **Administrative-division change history** — github.com/lizy14/division-changes.

## Contact

Jinyuan Liu — robert.j.liu047@gmail.com · Yizheng Wang — wangyizheng2024@ruc.edu.cn
School of Labor and Human Resources / School of Applied Economics, Renmin University
of China, Beijing.
