#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
SRC = PROJ / "data/raw/census/census2000.dta"
TREAT = PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta"
CW2000 = PROJ / "data/temp/countyid_2000_to_current_routes_v1.csv"
OUT_DTA = PROJ / "data/temp/census2000_family_micro_v1.dta"
OUT_CSV = PROJ / "data/temp/census2000_family_micro_v1.csv"


def main() -> None:
    cw = pd.read_csv(CW2000, dtype=str)
    cw["county_old6"] = pd.to_numeric(cw["county_old6"], errors="coerce").astype("Int64")
    cw["county_curr6"] = pd.to_numeric(cw["county_curr6"], errors="coerce").astype("Int64")
    cw = cw.dropna(subset=["county_old6", "county_curr6"]).copy()
    cw["county_old6"] = cw["county_old6"].astype(int).map(lambda x: f"{x:06d}")
    cw["county_curr6"] = cw["county_curr6"].astype(int).map(lambda x: f"{x:06d}")
    cw = cw[["county_old6", "county_curr6"]].drop_duplicates("county_old6")
    cw_map = dict(zip(cw["county_old6"], cw["county_curr6"]))

    treat = pd.read_stata(TREAT, convert_categoricals=False)
    treat["countyid_curr6"] = pd.to_numeric(treat["countyid_curr6"], errors="coerce").astype("Int64")
    treat = treat.dropna(subset=["countyid_curr6", "ln_martyr_per100k_1953"]).copy()
    treat["countyid_curr6"] = treat["countyid_curr6"].astype(int).map(lambda x: f"{x:06d}")
    treat = treat[["countyid_curr6", "ln_martyr_per100k_1953"]].drop_duplicates("countyid_curr6")
    tmap = dict(zip(treat["countyid_curr6"], treat["ln_martyr_per100k_1953"]))

    pieces: list[pd.DataFrame] = []
    usecols = ["uid", "birthyr", "sex", "race", "urban", "rural", "children", "h031", "h032"]
    for chunk in pd.read_stata(SRC, convert_categoricals=False, columns=usecols, chunksize=500_000):
        uid = pd.to_numeric(chunk["uid"], errors="coerce").astype("Int64")
        old6 = uid.astype("string").str.replace("<NA>", "", regex=False).str.zfill(6)
        chunk["countyid_curr6"] = old6.map(cw_map)
        chunk["birth_i"] = pd.to_numeric(chunk["birthyr"], errors="coerce")
        chunk = chunk[chunk["birth_i"].between(1920, 1970) & (chunk["birth_i"] != 1939)].copy()
        chunk["ln_martyr_per100k_1953"] = chunk["countyid_curr6"].map(tmap)
        chunk = chunk[chunk["countyid_curr6"].notna() & chunk["ln_martyr_per100k_1953"].notna()].copy()

        chunk["post"] = (chunk["birth_i"] >= 1940).astype(float)
        sex = pd.to_numeric(chunk["sex"], errors="coerce")
        race = pd.to_numeric(chunk["race"], errors="coerce")
        chunk["male"] = sex
        chunk["minority"] = np.where(race.notna(), (race != 1).astype(float), np.nan)
        chunk["rural"] = pd.to_numeric(chunk["rural"], errors="coerce")

        children = pd.to_numeric(chunk["children"], errors="coerce")
        hhsize = pd.to_numeric(chunk["h031"], errors="coerce") + pd.to_numeric(chunk["h032"], errors="coerce")
        chunk["children_n"] = children
        chunk["any_child"] = np.where(children.notna(), (children > 0).astype(float), np.nan)
        chunk["two_plus_child"] = np.where(children.notna(), (children >= 2).astype(float), np.nan)
        chunk["hhsize"] = hhsize
        chunk["large_hh"] = np.where(hhsize.notna(), (hhsize >= 5).astype(float), np.nan)

        keep = [
            "countyid_curr6",
            "birth_i",
            "post",
            "male",
            "minority",
            "rural",
            "ln_martyr_per100k_1953",
            "children_n",
            "any_child",
            "two_plus_child",
            "hhsize",
            "large_hh",
        ]
        pieces.append(chunk[keep].copy())

    out = pd.concat(pieces, ignore_index=True)
    out["birth_i"] = out["birth_i"].astype(int)
    OUT_DTA.parent.mkdir(parents=True, exist_ok=True)
    out.to_stata(OUT_DTA, write_index=False, version=118)
    out.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")


if __name__ == "__main__":
    main()
