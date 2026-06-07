# War and Human Capital Accumulation: Evidence from the Second Sino-Japanese War

Replication and analysis code for the solo-authored working paper *"War and Human
Capital Accumulation: Evidence from the Second Sino-Japanese War"* (Jinyuan LIU).

The project studies the long-run effect of wartime loss on education. It exploits
county-level variation in the intensity of recognized Anti-Japanese War martyrs
(1931–1945), built from an original dataset of digitized individual martyr records,
and estimates a cohort difference-in-differences on pooled microdata from the 1982,
1990, and 2000 Chinese population censuses.

This repository contains **code only**. Raw census microdata and the scraped
registry are not included because of data-licensing restrictions (see *Data* below).

---

## Empirical design in one paragraph

County-level treatment is per-capita martyr intensity (IHS-transformed), using the
1953 county population as the denominator. The main specification is a Duflo-style
cohort difference-in-differences that compares pre- and post-war birth cohorts
across counties with different wartime-loss intensity:

```
Y_icw = β (Post_i × X_c) + γ Z_i + λ_c + δ_b + μ_w + ε_icw
```

with county (`λ_c`), birth-year (`δ_b`), and census-wave (`μ_w`) fixed effects, and
standard errors clustered at the county level. The post-war cutoff is 1940 (primary)
or 1946 (stricter). The estimation sample covers roughly 9.1 million individuals
across 2,296 counties.

---

## Repository structure

```
code/
├── python/      # Data collection, cleaning, panel construction, and figures
└── stata_do/    # Regression do-files (reghdfe / reghdfejl / ppmlhdfe)
```

### Pipeline overview

The analysis runs in four stages. A few representative scripts for each stage:

1. **Data collection**
   - `python/scrape_chinamartyrs.py` — multithreaded scraper for the national
     martyr registry (paginated JSON API, retries with backoff, incremental
     checkpointing).

2. **Cleaning and dataset construction**
   - `python/build_place_counts_1931_1945_clean.py` — parses free-text Chinese
     place strings, geocodes them to modern county codes with a tiered fallback
     rule, and aggregates to county-level treatment.
   - `python/prepare_did_1982_martyrs_v2.py`,
     `python/prepare_did_1990_2000_longrun_v1.py` — build the analysis-ready
     county-cohort-wave panels from census microdata.
   - `python/build_county_extended_controls_v1.py`,
     `python/build_heritage_controls_v2.py` — assemble historical county controls.

3. **Estimation (Stata)**
   - `stata_do/check_main_eduy_mean_cutoff1940_mainstyle_v1.do` — main pooled DID.
   - `stata_do/check_pooled_main_paper_v1.do`,
     `stata_do/check_pooled_1946_all_v1.do` — robustness across cutoffs.
   - `stata_do/check_main_individual_ihs_ppml_v2.do` — Poisson (PPML)
     functional-form check.
   - Heterogeneity, mechanism, and placebo cuts are in the remaining
     `check_*` and `cgss_*` / `chip_*` do-files.

4. **Figures**
   - `python/plot_eventstudy_postwar_main_v4.py` — event-study figure.
   - `python/build_core_result_figures_v1.py` — main cohort-profile figures.

---

## Software

- **Python 3** with `pandas`, `numpy`, `requests`, `matplotlib`, `geopandas`.
- **Stata** with `reghdfe`, `reghdfejl`, `ppmlhdfe`, and `estout` (`esttab`).
  Do-files install missing packages automatically via `ssc install`.

Most scripts reference an absolute project path at the top; update it to your local
tree before running.

## Data

The paper combines three sources, none of which is redistributed here:

- **Chinese Martyrs Website** (national martyr registry, Ministry of Veterans
  Affairs of the PRC) — scraped with `scrape_chinamartyrs.py`.
- **Chinese population census microdata** (1982 / 1990 / 2000), accessed under the
  relevant data agreements.
- **Historical county controls** from published statistical and historical sources.

## Contact

Jinyuan LIU · jinyuanliu@email.cufe.edu.cn
China Academy of Public Finance and Public Policy, Central University of Finance
and Economics, Beijing.
