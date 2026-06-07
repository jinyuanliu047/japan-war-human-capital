#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
TEMP = PROJ / "data/temp"


def code6(x) -> str:
    if pd.isna(x):
        return ""
    s = str(x).replace(".0", "").strip()
    if not s or s.lower() == "nan":
        return ""
    digits = "".join(ch for ch in s if ch.isdigit())
    return digits.zfill(6)[-6:] if digits else ""


def main() -> None:
    cw = pd.read_csv(TEMP / "county_to_pref4_crosswalk_v1.csv")
    cw["countyid_curr6"] = cw["countyid_curr6"].map(code6)

    treat = pd.read_stata(TEMP / "martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
    treat["countyid_curr6"] = treat["countyid_curr6"].map(code6)
    pref_treat = (
        treat.merge(cw, on="countyid_curr6", how="left")
        .dropna(subset=["pref4_curr"])
        .groupby("pref4_curr", as_index=False)
        .agg(pop_1953=("pop_1953", "sum"), martyr_count_1931_1945=("martyr_count_1931_1945", "sum"))
    )
    pref_treat["martyr_per100k_1953"] = np.where(pref_treat["pop_1953"] > 0, pref_treat["martyr_count_1931_1945"] / pref_treat["pop_1953"] * 100000.0, np.nan)
    pref_treat["ln_martyr_per100k_1953"] = np.log(pref_treat["martyr_per100k_1953"] + 1.0)

    urban = pd.read_stata(TEMP / "chip1995_urban_edu_spend_micro_v1.dta", convert_categoricals=False)
    urban = urban.rename(columns={"pref4_guess": "pref4_curr", "tuition_fee": "schooling_fee", "adult_training": "training_cost"})
    urban["sample_rural"] = 0
    urban = urban[["pref4_curr", "birth_i", "post", "NHH", "head_female", "head_working", "head_eduy", "edu_total", "schooling_fee", "training_cost", "sample_rural"]]

    rural = pd.read_stata(TEMP / "chip1995_rural_edu_spend_micro_v1.dta", convert_categoricals=False)
    rural["countyid_curr6"] = rural["countyid_curr6"].map(code6)
    rural = rural.merge(cw, on="countyid_curr6", how="left")
    rural["sample_rural"] = 1
    rural = rural[["pref4_curr", "birth_i", "post", "NHH", "head_female", "head_working", "head_eduy", "edu_total", "schooling_fee", "training_cost", "sample_rural"]]

    pooled = pd.concat([urban, rural], ignore_index=True)
    pooled = pooled.merge(pref_treat[["pref4_curr", "ln_martyr_per100k_1953"]], on="pref4_curr", how="left")
    pooled = pooled.dropna(subset=["pref4_curr", "birth_i", "ln_martyr_per100k_1953"]).copy()

    audit = (
        pooled[["pref4_curr", "sample_rural"]]
        .drop_duplicates()
        .assign(sample=lambda d: np.where(d["sample_rural"] == 1, "rural", "urban"))
    )
    audit.to_csv(TEMP / "chip1995_pooled_pref_match_audit_v1.csv", index=False, encoding="utf-8-sig")

    pooled.to_stata(TEMP / "chip1995_edu_pooled_pref_micro_v1.dta", write_index=False, version=118)
    pooled.to_csv(TEMP / "chip1995_edu_pooled_pref_micro_v1.csv", index=False, encoding="utf-8-sig")


if __name__ == "__main__":
    main()
