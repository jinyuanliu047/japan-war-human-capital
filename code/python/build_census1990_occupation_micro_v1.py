#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
SRC = PROJ / "data/raw/census_1990_clean.dta"
TREAT = PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta"
OUT_DTA = PROJ / "data/temp/census1990_occupation_micro_v1.dta"
OUT_CSV = PROJ / "data/temp/census1990_occupation_micro_v1.csv"

WHITE_COLLAR = {
    "legislators, senior officials and managers",
    "professionals",
    "technicians and associate professionals",
    "clerks",
    "service workers and shop and market sales",
}

PROFESSIONAL = {
    "legislators, senior officials and managers",
    "professionals",
    "technicians and associate professionals",
}

MANUAL = {
    "crafts and related trades workers",
    "plant and machine operators and assemblers",
    "elementary occupations",
    "skilled agricultural and fishery workers",
}


def main() -> None:
    treat = pd.read_stata(TREAT, convert_categoricals=False)
    treat["countyid_curr6"] = pd.to_numeric(treat["countyid_curr6"], errors="coerce").astype("Int64")
    treat = treat.dropna(subset=["countyid_curr6", "ln_martyr_per100k_1953"]).copy()
    treat["countyid_curr6"] = treat["countyid_curr6"].astype(int).map(lambda x: f"{x:06d}")
    treat = treat[["countyid_curr6", "ln_martyr_per100k_1953"]].drop_duplicates("countyid_curr6")
    tmap = dict(zip(treat["countyid_curr6"], treat["ln_martyr_per100k_1953"]))

    pieces: list[pd.DataFrame] = []
    usecols = [
        "region1990",
        "year_birth",
        "male",
        "han_ethn",
        "rural",
        "occisco",
        "teacher",
        "laborforce",
    ]
    for chunk in pd.read_stata(SRC, convert_categoricals=True, columns=usecols, chunksize=500_000):
        chunk["countyid_curr6"] = pd.to_numeric(chunk["region1990"], errors="coerce").astype("Int64")
        chunk["countyid_curr6"] = chunk["countyid_curr6"].astype("string").str.replace("<NA>", "", regex=False).str.zfill(6)
        chunk["birth_i"] = pd.to_numeric(chunk["year_birth"], errors="coerce")
        chunk = chunk[chunk["birth_i"].between(1920, 1968) & (chunk["birth_i"] != 1939)].copy()
        chunk["ln_martyr_per100k_1953"] = chunk["countyid_curr6"].map(tmap)
        chunk = chunk[chunk["ln_martyr_per100k_1953"].notna()].copy()

        chunk["post"] = (chunk["birth_i"] >= 1940).astype(float)
        chunk["minority"] = np.where(chunk["han_ethn"].notna(), (pd.to_numeric(chunk["han_ethn"], errors="coerce") != 1).astype(float), np.nan)
        chunk["male"] = pd.to_numeric(chunk["male"], errors="coerce")
        chunk["rural"] = pd.to_numeric(chunk["rural"], errors="coerce")
        chunk["lf_participate"] = np.where(chunk["laborforce"].notna(), (pd.to_numeric(chunk["laborforce"], errors="coerce") == 1).astype(float), np.nan)
        lf = chunk["lf_participate"] == 1
        occ = chunk["occisco"].astype(str)
        chunk["teacher_job"] = np.where(lf & chunk["teacher"].notna(), (pd.to_numeric(chunk["teacher"], errors="coerce") == 1).astype(float), np.nan)
        chunk["white_collar"] = np.where(lf, occ.isin(WHITE_COLLAR).astype(float), np.nan)
        chunk["professional"] = np.where(lf, occ.isin(PROFESSIONAL).astype(float), np.nan)
        chunk["manual"] = np.where(lf, occ.isin(MANUAL).astype(float), np.nan)

        keep = [
            "countyid_curr6",
            "birth_i",
            "post",
            "male",
            "minority",
            "rural",
            "ln_martyr_per100k_1953",
            "lf_participate",
            "teacher_job",
            "white_collar",
            "professional",
            "manual",
        ]
        pieces.append(chunk[keep].copy())

    out = pd.concat(pieces, ignore_index=True)
    out["birth_i"] = out["birth_i"].astype(int)
    OUT_DTA.parent.mkdir(parents=True, exist_ok=True)
    out.to_stata(OUT_DTA, write_index=False, version=118)
    out.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")


if __name__ == "__main__":
    main()
