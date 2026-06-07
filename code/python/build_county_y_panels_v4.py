#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat

PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
RAW = PROJ / "data/raw"
TEMP = PROJ / "data/temp"
TREAT = TEMP / "martyr_pop1953_treatment_county_v2.dta"
CW1982 = TEMP / "countyid_1982_to_current_crosswalk_v2.csv"


OUTCOMES = {
    "primary_comp": 6,
    "junior_comp": 9,
    "college_comp": 15,
}


def code6(x) -> str:
    if pd.isna(x):
        return ""
    s = str(x).replace(".0", "").strip()
    if s == "" or s.lower() == "nan":
        return ""
    digits = "".join(ch for ch in s if ch.isdigit())
    return digits.zfill(6)[-6:] if digits else ""


def read_treat() -> pd.DataFrame:
    treat = pd.read_stata(TREAT, convert_categoricals=False)
    treat["countyid_curr6"] = treat["countyid_curr6"].map(code6)
    keep = [
        "countyid_curr6",
        "pop_1953",
        "martyr_count_1931_1945",
        "martyr_per100k_1953",
        "ln_martyr_raw",
        "ln_martyr_per100k_1953",
    ]
    return treat[keep].drop_duplicates("countyid_curr6")


def read_cw1982() -> pd.DataFrame:
    cw = pd.read_csv(CW1982, dtype=str)
    cw = cw.rename(columns={"countyid_old6": "old6", "countyid_curr6_final": "countyid_curr6"})
    cw["old6"] = cw["old6"].map(code6)
    cw["countyid_curr6"] = cw["countyid_curr6"].map(code6)
    cw = cw[(cw["old6"] != "") & (cw["countyid_curr6"] != "")].copy()
    return cw[["old6", "countyid_curr6"]].drop_duplicates("old6")


def finalize_panel(df: pd.DataFrame, wave: int, treat: pd.DataFrame) -> pd.DataFrame:
    grouped = (
        df.groupby(["countyid_curr6", "birth_i"], as_index=False)
        .agg(
            n_obs=("eduy", "size"),
            eduy_mean=("eduy", "mean"),
            primary_comp=("primary_comp", "mean"),
            junior_comp=("junior_comp", "mean"),
            college_comp=("college_comp", "mean"),
        )
    )
    grouped["pri_comp"] = grouped["primary_comp"]
    grouped["mid_comp"] = grouped["junior_comp"]
    grouped["col_comp"] = grouped["college_comp"]
    grouped["wave"] = wave
    grouped = grouped.merge(treat, on="countyid_curr6", how="left")
    return grouped


def add_completion_vars(df: pd.DataFrame) -> pd.DataFrame:
    for name, threshold in OUTCOMES.items():
        df[name] = np.where(df["eduy"].notna(), (df["eduy"] >= threshold).astype(float), np.nan)
    return df


def build_1982(treat: pd.DataFrame, cw: pd.DataFrame) -> pd.DataFrame:
    src = Path("/tmp/census_1982_clean.dta") if Path("/tmp/census_1982_clean.dta").exists() else RAW / "census_1982_clean.dta"
    df, _ = pyreadstat.read_dta(str(src), usecols=["region1982", "year_birth", "yedu"])
    df["old6"] = df["region1982"].map(code6)
    df = df.merge(cw, on="old6", how="left")
    df["birth_i"] = pd.to_numeric(df["year_birth"], errors="coerce")
    df["eduy"] = pd.to_numeric(df["yedu"], errors="coerce")
    df = df[(df["countyid_curr6"].notna()) & (df["countyid_curr6"] != "")].copy()
    df = df[df["birth_i"].between(1920, 1960) & (df["birth_i"] != 1939)].copy()
    df = df[df["eduy"].between(0, 25)].copy()
    df = add_completion_vars(df)
    return finalize_panel(df, 1982, treat)


def build_1990(treat: pd.DataFrame) -> pd.DataFrame:
    src = Path("/tmp/census_1990_clean.dta") if Path("/tmp/census_1990_clean.dta").exists() else RAW / "census_1990_clean.dta"
    df, _ = pyreadstat.read_dta(str(src), usecols=["region1990", "year_birth", "yedu"])
    df["countyid_curr6"] = df["region1990"].map(code6)
    df["birth_i"] = pd.to_numeric(df["year_birth"], errors="coerce")
    df["eduy"] = pd.to_numeric(df["yedu"], errors="coerce")
    df = df[(df["countyid_curr6"] != "") & (df["countyid_curr6"] != "000000")].copy()
    df = df[df["birth_i"].between(1920, 1968) & (df["birth_i"] != 1939)].copy()
    df = df[df["eduy"].between(0, 25)].copy()
    df = add_completion_vars(df)
    return finalize_panel(df, 1990, treat)


def build_2000(treat: pd.DataFrame) -> pd.DataFrame:
    src = Path("/tmp/census_2000_clean.dta") if Path("/tmp/census_2000_clean.dta").exists() else RAW / "census_2000_clean.dta"
    df, _ = pyreadstat.read_dta(str(src), usecols=["region2000", "year_birth", "yedu"])
    df["countyid_curr6"] = df["region2000"].map(code6)
    df["birth_i"] = pd.to_numeric(df["year_birth"], errors="coerce")
    df["eduy"] = pd.to_numeric(df["yedu"], errors="coerce")
    df = df[(df["countyid_curr6"] != "") & (df["countyid_curr6"] != "000000")].copy()
    df = df[df["birth_i"].between(1920, 1978) & (df["birth_i"] != 1939)].copy()
    df = df[df["eduy"].between(0, 25)].copy()
    df = add_completion_vars(df)
    return finalize_panel(df, 2000, treat)


def save_panel(df: pd.DataFrame, wave: int) -> None:
    out_dta = TEMP / f"county_y_panel_{wave}_v4.dta"
    out_csv = TEMP / f"county_y_panel_{wave}_v4.csv"
    df.to_stata(out_dta, write_index=False, version=118)
    df.to_csv(out_csv, index=False, encoding="utf-8-sig")


def main() -> None:
    treat = read_treat()
    cw = read_cw1982()
    save_panel(build_1982(treat, cw), 1982)
    save_panel(build_1990(treat), 1990)
    save_panel(build_2000(treat), 2000)


if __name__ == "__main__":
    main()
