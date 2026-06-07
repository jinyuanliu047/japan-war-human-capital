#!/usr/bin/env python3
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import pandas as pd


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
OUT_DIR = PROJ / "data/temp/heterogeneity_groups_v1"


def code6(x: object) -> str:
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return ""
    s = str(x).strip().replace(".0", "")
    d = "".join(ch for ch in s if ch.isdigit())
    return d[:6].zfill(6) if d else ""


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    treat = pd.read_stata(PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
    treat["countyid_curr6"] = treat["countyid_curr6"].map(code6)
    treat = treat[["countyid_curr6", "ln_martyr_per100k_1953"]].drop_duplicates("countyid_curr6")

    d = pd.read_stata(PROJ / "data/raw/census_2000_clean.dta", convert_categoricals=False)
    d = d[["region2000", "year_birth", "male", "han_ethn", "yedu"]].copy()
    d["countyid_curr6"] = d["region2000"].map(code6)
    d["birth_i"] = d["year_birth"].astype(int)
    d["eduy"] = d["yedu"]
    d["minority_share"] = np.where(d["han_ethn"].notna(), (d["han_ethn"] == 0).astype(float), np.nan)
    d = d[(d["countyid_curr6"] != "") & d["birth_i"].between(1920, 1978) & (d["birth_i"] != 1939)]
    d = d[d["eduy"].between(0, 25)].copy()
    d = d.merge(treat, on="countyid_curr6", how="inner")

    for label, val in [("male", 1), ("female", 0)]:
        sub = d[d["male"] == val].copy()
        agg = (
            sub.groupby(["countyid_curr6", "birth_i", "ln_martyr_per100k_1953"], as_index=False)
            .agg(eduy_mean=("eduy", "mean"), minority_share=("minority_share", "mean"), n=("eduy", "size"))
        )
        agg.to_csv(OUT_DIR / f"panel_2000_{label}.csv", index=False, encoding="utf-8-sig")
        agg.to_stata(OUT_DIR / f"panel_2000_{label}.dta", write_index=False, version=118)
        print(label, len(agg))


if __name__ == "__main__":
    main()
