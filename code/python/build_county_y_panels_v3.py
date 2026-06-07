#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
TEMP = PROJ / "data/temp"
RAW = PROJ / "data/raw"


def code6(x) -> str:
    if pd.isna(x):
        return ""
    s = str(x).replace(".0", "").strip()
    if s == "" or s.lower() == "nan":
        return ""
    digits = "".join(ch for ch in s if ch.isdigit())
    return digits.zfill(6)[-6:] if digits else ""


def load_treat() -> pd.DataFrame:
    t = pd.read_stata(TEMP / "martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
    t["countyid_curr6"] = t["countyid_curr6"].map(code6)
    keep = ["countyid_curr6", "pop_1953", "martyr_count_1931_1945", "martyr_per100k_1953", "ln_martyr_raw", "ln_martyr_per100k_1953"]
    return t[keep].drop_duplicates("countyid_curr6")


def load_maps():
    cw82 = pd.read_csv(TEMP / "countyid_1982_to_current_crosswalk_v2.csv", dtype=str)
    cw82["old6"] = cw82["countyid_old6"].map(code6)
    cw82["countyid_curr6"] = cw82["countyid_curr6_final"].map(code6)
    map82 = dict(zip(cw82["old6"], cw82["countyid_curr6"]))

    cd = pd.read_stata(RAW / "county_data.dta", convert_categoricals=False)
    cd["curr6"] = cd["region2010"].map(code6)
    cd["old90"] = cd["region1990"].map(code6)
    map90 = dict(zip(cd.loc[cd["old90"] != "", "old90"], cd.loc[cd["old90"] != "", "curr6"]))

    cw00 = pd.read_csv(TEMP / "countyid_2000_to_current_routes_v1.csv", dtype=str)
    cw00["old6"] = cw00["county_old6"].map(code6)
    cw00["countyid_curr6"] = cw00["county_curr6"].map(code6)
    map00 = dict(zip(cw00["old6"], cw00["countyid_curr6"]))
    return map82, map90, map00


def finalize_panel(agg: pd.DataFrame, wave: int, treat: pd.DataFrame) -> pd.DataFrame:
    agg["eduy_mean"] = agg["sum_eduy"] / agg["n_obs"]
    agg["pri_comp"] = agg["sum_pri"] / agg["n_obs"]
    agg["mid_comp"] = agg["sum_mid"] / agg["n_obs"]
    out = agg[["countyid_curr6", "birth_i", "n_obs", "eduy_mean", "pri_comp", "mid_comp"]].copy()
    out["wave"] = wave
    out = out.merge(treat, on="countyid_curr6", how="left")
    return out


def build_1982(treat: pd.DataFrame, map82: dict[str, str]) -> pd.DataFrame:
    df, _ = pyreadstat.read_dta(str(TEMP / "census_1982_cleaned.dta"), usecols=["countyid", "birthyr", "eduy"])
    df["old6"] = df["countyid"].map(code6)
    df["countyid_curr6"] = df["old6"].map(map82)
    df["birth_i"] = pd.to_numeric(df["birthyr"], errors="coerce").astype("Int64")
    df["eduy"] = pd.to_numeric(df["eduy"], errors="coerce")
    df = df[df["countyid_curr6"].notna()].copy()
    df = df[df["birth_i"].between(1920, 1960) & (df["birth_i"] != 1939)].copy()
    df = df[df["eduy"].between(0, 25)].copy()
    df["pri"] = (df["eduy"] >= 6).astype(float)
    df["mid"] = (df["eduy"] >= 9).astype(float)
    agg = df.groupby(["countyid_curr6", "birth_i"], as_index=False).agg(
        n_obs=("eduy", "size"), sum_eduy=("eduy", "sum"), sum_pri=("pri", "sum"), sum_mid=("mid", "sum")
    )
    return finalize_panel(agg, 1982, treat)


def build_1990(treat: pd.DataFrame, map90: dict[str, str]) -> pd.DataFrame:
    pieces = []
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(RAW / "census/census1990.dta"),
        chunksize=800000,
        usecols=["county", "age_c", "age", "educ"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        chunk["old6"] = chunk["county"].map(code6)
        chunk["countyid_curr6"] = chunk["old6"].map(map90)
        chunk = chunk[chunk["countyid_curr6"].notna()].copy()
        chunk["birth_i"] = pd.to_numeric(chunk["age_c"], errors="coerce") * 1000 + pd.to_numeric(chunk["age"], errors="coerce")
        chunk["educ"] = pd.to_numeric(chunk["educ"], errors="coerce")
        chunk = chunk[chunk["birth_i"].between(1920, 1968) & (chunk["birth_i"] != 1939)].copy()
        chunk = chunk[chunk["educ"].between(1, 7)].copy()
        chunk["eduy"] = np.nan
        chunk.loc[chunk["educ"] == 1, "eduy"] = 0
        chunk.loc[chunk["educ"] == 2, "eduy"] = 6
        chunk.loc[chunk["educ"] == 3, "eduy"] = 9
        chunk.loc[chunk["educ"].isin([4, 5]), "eduy"] = 12
        chunk.loc[chunk["educ"] == 6, "eduy"] = 15
        chunk.loc[chunk["educ"] == 7, "eduy"] = 16
        chunk["pri"] = (chunk["eduy"] >= 6).astype(float)
        chunk["mid"] = (chunk["eduy"] >= 9).astype(float)
        agg = chunk.groupby(["countyid_curr6", "birth_i"], as_index=False).agg(
            n_obs=("eduy", "size"), sum_eduy=("eduy", "sum"), sum_pri=("pri", "sum"), sum_mid=("mid", "sum")
        )
        pieces.append(agg)
        if i % 2 == 0:
            print(f"1990 chunk {i} done")
    out = pd.concat(pieces, ignore_index=True).groupby(["countyid_curr6", "birth_i"], as_index=False).sum()
    return finalize_panel(out, 1990, treat)


def build_2000(treat: pd.DataFrame, map00: dict[str, str]) -> pd.DataFrame:
    pieces = []
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(RAW / "census/census2000.dta"),
        chunksize=800000,
        usecols=["uid", "birthyr", "eduyr"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        chunk["old6"] = chunk["uid"].map(code6)
        chunk["countyid_curr6"] = chunk["old6"].map(map00)
        chunk = chunk[chunk["countyid_curr6"].notna()].copy()
        chunk["birth_i"] = pd.to_numeric(chunk["birthyr"], errors="coerce").astype("Int64")
        chunk["eduy"] = pd.to_numeric(chunk["eduyr"], errors="coerce")
        chunk = chunk[chunk["birth_i"].between(1920, 1978) & (chunk["birth_i"] != 1939)].copy()
        chunk = chunk[chunk["eduy"].between(0, 25)].copy()
        chunk["pri"] = (chunk["eduy"] >= 6).astype(float)
        chunk["mid"] = (chunk["eduy"] >= 9).astype(float)
        agg = chunk.groupby(["countyid_curr6", "birth_i"], as_index=False).agg(
            n_obs=("eduy", "size"), sum_eduy=("eduy", "sum"), sum_pri=("pri", "sum"), sum_mid=("mid", "sum")
        )
        pieces.append(agg)
        if i % 2 == 0:
            print(f"2000 chunk {i} done")
    out = pd.concat(pieces, ignore_index=True).groupby(["countyid_curr6", "birth_i"], as_index=False).sum()
    return finalize_panel(out, 2000, treat)


def save_panel(df: pd.DataFrame, wave: int) -> None:
    df.to_stata(TEMP / f"county_y_panel_{wave}_v1.dta", write_index=False, version=118)
    df.to_csv(TEMP / f"county_y_panel_{wave}_v1.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    treat = load_treat()
    map82, map90, map00 = load_maps()
    save_panel(build_1982(treat, map82), 1982)
    save_panel(build_1990(treat, map90), 1990)
    save_panel(build_2000(treat, map00), 2000)


if __name__ == "__main__":
    main()
