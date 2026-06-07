# War and Human Capital Accumulation: Evidence from the Second Sino-Japanese War

Replication code for the solo-authored working paper *"War and Human Capital
Accumulation: Evidence from the Second Sino-Japanese War"* (Jinyuan LIU).

The project studies the long-run effect of wartime loss on education. It exploits
county-level variation in the intensity of recognized Anti-Japanese War martyrs
(1931–1945), built from an original dataset of digitized individual martyr records,
and estimates a cohort difference-in-differences on pooled microdata from the 1982,
1990, and 2000 Chinese population censuses.

This repository is curated to the scripts that build the data and produce the
tables and figures in the paper. It contains **code only**; raw census microdata
and the scraped registry are not redistributed (see *Data*).

---

## Empirical design in one paragraph

County-level treatment is per-capita martyr intensity (IHS-transformed), using the
1953 county population as the denominator. The main specification is a cohort
difference-in-differences that compares pre- and post-war birth cohorts across
counties of different wartime-loss intensity:

```
Y_icw = β (Post_i × X_c) + γ Z_i + λ_c + δ_b + μ_w + ε_icw
```

with county (`λ_c`), birth-year (`δ_b`), and census-wave (`μ_w`) fixed effects and
standard errors clustered at the county level. The post-war cutoff is 1940 (primary)
or 1946 (stricter). The sample covers roughly 9.1 million individuals across 2,296
counties. Main estimator: `reghdfe` / `reghdfejl`; functional-form check: `ppmlhdfe`.

---

## Pipeline

The repository runs top to bottom. Python builds the datasets; Stata estimates and
exports the tables and figures.

### 1. Data collection
- `code/python/scrape_chinamartyrs.py` — multithreaded scraper for the national
  martyr registry (paginated JSON API, retries with backoff, incremental
  checkpointing).

### 2. Treatment construction (martyr counts → county intensity)
- `code/python/build_place_counts_1931_1945.py`
- `code/python/build_place_counts_1931_1945_clean.py` — geocodes free-text Chinese
  place strings to modern county codes with a tiered fallback rule.
- `code/python/build_place_counts_1931_1945_merge_ready.py`

### 3. Census microdata panels
- `code/python/prepare_did_1982_martyrs_v2.py`
- `code/python/prepare_did_1990_2000_longrun_v1.py`
- `code/python/prepare_panels_pop1953_unweighted_v2.py`
- `code/stata_do/build_census_main_subsets_v1.do`
- `code/stata_do/prepare_panels_pop1953_unwt_v2.do`

### 4. Historical and mechanism controls
- `code/python/build_county_extended_controls_v1.py` — county controls and the
  clan / earthquake control set.
- `code/python/build_revolutionary_proxy_controls_v1.py`
- `code/python/build_county_y_panels_v3.py` — county fiscal-education year panel.
- `code/python/build_chip1995_edu_pooled_pref_micro_v1.py` — CHIP 1995 micro inputs.

### 5. Assemble the estimation dataset
- `code/stata_do/create_master_pooled_data.do` — merges the census panels,
  treatment, and controls into the pooled master file used by all regressions.

### 6. Main results
| Script | Paper output |
| --- | --- |
| `check_summary_stats_pooled_v2.do` | Table 1 — summary statistics |
| `check_pooled_figures_v1.do` | Table 2 — suggestive 2×2 evidence |
| `check_pooled_main_paper_v1.do` | Tables 3–4 — baseline DID (1940 / 1946) |
| `check_pooled_hist_lmk_expanded_v1.do` | Tables 5–6 — historical controls, Long March / Korea placebo |
| `check_pooled_all_remaining_v1.do` | Tables 7–8 — heterogeneity by gender and pre-war education |
| `check_pooled_het_clan_treatyport_v1.do` | Heterogeneity by ancestral clan and treaty-port status |
| `check_pooled_mechanism_ihs_dummy_v1.do` | Mechanism — career choice, CGSS, CHIP |
| `check_collectivism_ihs_dummy_v1.do` | Mechanism — collectivism (province) |
| `check_collectivesim_province_prefecture_v1.do` (+ `.py`) | Mechanism — collectivism (prefecture) |
| `check_mechanism_county_panel_v3.do` | Mechanism — local fiscal education spending |
| `check_additional_party_military_v2.do` | Party membership and military service |

### 7. Robustness appendix
| Script | Paper output |
| --- | --- |
| `did_martyrs_eduy_pooled_sacrifice_v2.do` | Appendix C — sacrifice-place robustness (all tables) |
| `pooled_ppml_vs_ols_v1.do` | Appendix D — OLS vs PPML |
| `check_pooled_nonmigrant_v1.do` | Appendix E — non-mover subsample |
| `check_enrollment_pooled_v2.do` | Appendix F — schooling-margin decomposition (1940 / 1946) |
| `check_enrollment_robustness_v1.do` | Appendix F — schooling margins by sex and with historical controls |
| `pooled_sumstats_figures_v1.do` | Appendix B — county treatment distribution table and figures |

### 8. Figures
- `check_pooled_eventstudy_v1.do` — event study, IHS treatment.
- `check_pooled_eventstudy_dummy_v1.do` — event study, above-median treatment.
- `check_pooled_residualized_fig_v1.do` — cohort profiles of schooling and gaps.
- `code/python/plot_china_map_from_shp.py` — martyr-intensity maps.

---

## Software

- **Python 3** with `pandas`, `numpy`, `requests`, `matplotlib`, `geopandas`.
- **Stata** with `reghdfe`, `reghdfejl`, `ppmlhdfe`, and `estout` (`esttab`).
  Do-files install missing packages automatically via `ssc install`.

Each script sets an absolute project path near the top; update it to your local
tree before running.

## Data

The paper combines three sources, none of which is redistributed here:

- **Chinese Martyrs Website** (national martyr registry, Ministry of Veterans
  Affairs of the PRC) — collected with `scrape_chinamartyrs.py`.
- **Chinese population census microdata** (1982 / 1990 / 2000), accessed under the
  relevant data agreements.
- **Historical county controls, CGSS, and CHIP**, from their respective providers.

## Contact

Jinyuan LIU · jinyuanliu@email.cufe.edu.cn
China Academy of Public Finance and Public Policy, Central University of Finance
and Economics, Beijing.
