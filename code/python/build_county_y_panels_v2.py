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


def read_treat() -> pd.DataFrame:
    treat = pd.read_stata(TREAT, convert_categoricals=False)
    treat["countyid_curr6"] = pd.to_numeric(treat["countyid_curr6"], errors="coerce").astype("Int64")
    treat = treat.dropna(subset=["countyid_curr6"]).copy()
    treat["countyid_curr6"] = treat["countyid_curr6"].astype(int).map(lambda x: f"{x:06d}")
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
    cw["old6"] = cw["old6"].str.replace(".0", "", regex=False).str.zfill(6)
    cw["countyid_curr6"] = cw["countyid_curr6"].str.replace(".0", "", regex=False).str.zfill(6)
    return cw[["old6", "countyid_curr6"]].dropna().drop_duplicates("old6")


def agg_panel(df: pd.DataFrame, wave: int) -> pd.DataFrame:
    out = (
        df.groupby(["countyid_curr6", "birth_i"], as_index=False)
        .agg(
            n_obs=("birth_i", "size"),
            eduy_mean=("eduy", "mean"),
            pri_comp=("pri_comp", "mean"),
            mid_comp=("mid_comp", "mean"),
        )
    )
    out["wave"] = wave
    return out


def build_1982(treat: pd.DataFrame, cw: pd.DataFrame) -> pd.DataFrame:
    src = RAW / "census_1982_clean.dta"
    df, _ = pyreadstat.read_dta(str(src), usecols=["region1982", "year_birth", "yedu"])
    df["old6"] = pd.to_numeric(df["region1982"], errors="coerce").astype("Int64")
    df = df.dropna(subset=["old6", "year_birth"]).copy()
    df["old6"] = df["old6"].astype(int).map(lambda x: f"{x:06d}")
    df = df.merge(cw, on="old6", how="left")
    df["birth_i"] = pd.to_numeric(df["year_birth"], errors="coerce")
    df["eduy"] = pd.to_numeric(df["yedu"], errors="coerce")
    df = df[df["birth_i"].between(1920, 1960) & (df["birth_i"] != 1939)].copy()
    df["pri_comp"] = np.where(df["eduy"].notna(), (df["eduy"] >= 6).astype(float), np.nan)
    df["mid_comp"] = np.where(df["eduy"].notna(), (df["eduy"] >= 9).astype(float), np.nan)
    out = agg_panel(df.dropna(subset=["countyid_curr6"]), 1982)
    return out.merge(treat, on="countyid_curr6", how="left")


def build_1990(treat: pd.DataFrame) -> pd.DataFrame:
    src = RAW / "census_1990_clean.dta"
    cols = ["region1990", "year_birth", "yedu", "primary_graduate", "junior_graduate"]
    df, _ = pyreadstat.read_dta(str(src), usecols=cols)
    df["countyid_curr6"] = pd.to_numeric(df["region1990"], errors="coerce").astype("Int64")
    df = df.dropna(subset=["countyid_curr6", "year_birth"]).copy()
    df["countyid_curr6"] = df["countyid_curr6"].astype(int).map(lambda x: f"{x:06d}")
    df["birth_i"] = pd.to_numeric(df["year_birth"], errors="coerce")
    df["eduy"] = pd.to_numeric(df["yedu"], errors="coerce")
    df["pri_comp"] = pd.to_numeric(df["primary_graduate"], errors="coerce")
    df["mid_comp"] = pd.to_numeric(df["junior_graduate"], errors="coerce")
    df = df[df["birth_i"].between(1920, 1968) & (df["birth_i"] != 1939)].copy()
    out = agg_panel(df, 1990)
    return out.merge(treat, on="countyid_curr6", how="left")


def build_2000(treat: pd.DataFrame) -> pd.DataFrame:
    src = RAW / "census_2000_clean.dta"
    df, _ = pyreadstat.read_dta(str(src), usecols=["region2000", "year_birth", "yedu"])
    df["countyid_curr6"] = pd.to_numeric(df["region2000"], errors="coerce").astype("Int64")
    df = df.dropna(subset=["countyid_curr6", "year_birth"]).copy()
    df["countyid_curr6"] = df["countyid_curr6"].astype(int).map(lambda x: f"{x:06d}")
    df["birth_i"] = pd.to_numeric(df["year_birth"], errors="coerce")
    df["eduy"] = pd.to_numeric(df["yedu"], errors="coerce")
    df = df[df["birth_i"].between(1920, 1978) & (df["birth_i"] != 1939)].copy()
    df["pri_comp"] = np.where(df["eduy"].notna(), (df["eduy"] >= 6).astype(float), np.nan)
    df["mid_comp"] = np.where(df["eduy"].notna(), (df["eduy"] >= 9).astype(float), np.nan)
    out = agg_panel(df, 2000)
    return out.merge(treat, on="countyid_curr6", how="left")


def save_panel(df: pd.DataFrame, wave: int) -> None:
    out = TEMP / f"county_y_panel_{wave}_v1.dta"
    out_csv = TEMP / f"county_y_panel_{wave}_v1.csv"
    df.to_stata(out, write_index=False, version=118)
    df.to_csv(out_csv, index=False, encoding="utf-8-sig")


def main() -> None:
    treat = read_treat()
    cw = read_cw1982()
    save_panel(build_1982(treat, cw), 1982)
    save_panel(build_1990(treat), 1990)
    save_panel(build_2000(treat), 2000)


if __name__ == "__main__":
    main()
