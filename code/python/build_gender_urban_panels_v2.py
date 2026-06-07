#!/usr/bin/env python3
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
OUT_DIR = PROJ / "data/temp/gender_urban_groups_v2"


def code6(x: object) -> str:
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return ""
    s = str(x).strip().replace(".0", "")
    d = "".join(ch for ch in s if ch.isdigit())
    if not d:
        return ""
    return d[:6].zfill(6)


def treat_map() -> dict[str, float]:
    d = pd.read_stata(PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
    d["countyid_curr6"] = d["countyid_curr6"].map(code6)
    d = d[["countyid_curr6", "ln_martyr_per100k_1953"]].drop_duplicates("countyid_curr6")
    return dict(zip(d["countyid_curr6"], d["ln_martyr_per100k_1953"]))


def aggregate_groups(df: pd.DataFrame, groups: list[str]) -> dict[str, pd.DataFrame]:
    keys = ["countyid_curr6", "birth_i", "ln_martyr_per100k_1953"]
    out: dict[str, pd.DataFrame] = {}
    for g in groups:
        if g == "male":
            sub = df[df["male"] == 1].copy()
        elif g == "female":
            sub = df[df["male"] == 0].copy()
        elif g == "urban":
            sub = df[df["urban_tag"] == 1].copy()
        elif g == "rural":
            sub = df[df["rural_tag"] == 1].copy()
        else:
            raise ValueError(g)
        if sub.empty:
            out[g] = pd.DataFrame(columns=keys + ["eduy_mean", "minority_share", "n"])
            continue
        agg = (
            sub.groupby(keys, as_index=False)
            .agg(
                eduy_mean=("eduy", "mean"),
                minority_share=("minority", "mean"),
                n=("eduy", "size"),
            )
        )
        out[g] = agg
    return out


def save_group_panels(wave: int, panels: dict[str, pd.DataFrame]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for g, panel in panels.items():
        panel.to_csv(OUT_DIR / f"panel_{wave}_{g}.csv", index=False, encoding="utf-8-sig")
        panel.to_stata(OUT_DIR / f"panel_{wave}_{g}.dta", write_index=False, version=118)


def prep_1982(tm: dict[str, float]) -> None:
    d = pd.read_stata(PROJ / "data/raw/census_1982_clean.dta", convert_categoricals=False)
    d = d[["region1982", "year_birth", "male", "han_ethn", "yedu"]].copy()
    d["countyid_curr6"] = d["region1982"].map(code6)
    d["birth_i"] = d["year_birth"].astype(int)
    d["eduy"] = d["yedu"]
    d["minority"] = np.where(d["han_ethn"].notna(), (d["han_ethn"] == 0).astype(float), np.nan)
    d["urban_tag"] = np.nan
    d["rural_tag"] = np.nan
    d = d[(d["countyid_curr6"] != "") & d["birth_i"].between(1920, 1960) & (d["birth_i"] != 1939)].copy()
    d = d[d["eduy"].between(0, 25)].copy()
    d["ln_martyr_per100k_1953"] = d["countyid_curr6"].map(tm)
    d = d[d["ln_martyr_per100k_1953"].notna()].copy()
    save_group_panels(1982, aggregate_groups(d, ["male", "female"]))


def prep_1990(tm: dict[str, float]) -> None:
    d = pd.read_stata(PROJ / "data/raw/census_1990_clean.dta", convert_categoricals=False)
    d = d[["region1990", "year_birth", "male", "han_ethn", "rural", "yedu"]].copy()
    d["countyid_curr6"] = d["region1990"].map(code6)
    d["birth_i"] = d["year_birth"].astype(int)
    d["eduy"] = d["yedu"]
    d["minority"] = np.where(d["han_ethn"].notna(), (d["han_ethn"] == 0).astype(float), np.nan)
    d["rural_tag"] = np.where(d["rural"].notna(), (d["rural"] == 1).astype(float), np.nan)
    d["urban_tag"] = np.where(d["rural"].notna(), (d["rural"] == 0).astype(float), np.nan)
    d = d[(d["countyid_curr6"] != "") & d["birth_i"].between(1920, 1968) & (d["birth_i"] != 1939)].copy()
    d = d[d["eduy"].between(0, 25)].copy()
    d["ln_martyr_per100k_1953"] = d["countyid_curr6"].map(tm)
    d = d[d["ln_martyr_per100k_1953"].notna()].copy()
    save_group_panels(1990, aggregate_groups(d, ["male", "female", "urban", "rural"]))


def prep_2000(tm: dict[str, float]) -> None:
    cw = pd.read_csv(PROJ / "data/temp/countyid_2000_to_current_routes_v1.csv", dtype=str)
    cw["old6"] = cw["county_old6"].map(code6)
    cw["countyid_curr6"] = cw["county_curr6"].map(code6)
    cw = cw[(cw["old6"] != "") & (cw["countyid_curr6"] != "")][["old6", "countyid_curr6"]].drop_duplicates("old6")
    cw_map = dict(zip(cw["old6"], cw["countyid_curr6"]))

    keys = ["countyid_curr6", "birth_i", "ln_martyr_per100k_1953"]
    pieces: dict[str, list[pd.DataFrame]] = {g: [] for g in ["male", "female", "urban", "rural"]}
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(PROJ / "data/raw/census/census2000.dta"),
        chunksize=800000,
        usecols=["uid", "birthyr", "eduyr", "sex", "race", "urban", "rural"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        chunk["old6"] = chunk["uid"].map(code6)
        chunk["countyid_curr6"] = chunk["old6"].map(cw_map)
        chunk["birth_i"] = np.floor(chunk["birthyr"]).astype("Int64")
        chunk["eduy"] = chunk["eduyr"]
        chunk["male"] = np.where(chunk["sex"].notna(), (chunk["sex"] == 1).astype(float), np.nan)
        chunk["minority"] = np.where(chunk["race"].notna(), (chunk["race"] != 1).astype(float), np.nan)
        chunk["urban_tag"] = np.where(chunk["urban"].notna(), (chunk["urban"] == 1).astype(float), np.nan)
        chunk["rural_tag"] = np.where(chunk["rural"].notna(), (chunk["rural"] == 1).astype(float), np.nan)
        chunk = chunk[
            (chunk["countyid_curr6"].notna())
            & (chunk["countyid_curr6"] != "")
            & chunk["birth_i"].between(1920, 1978)
            & (chunk["birth_i"] != 1939)
            & chunk["eduy"].between(0, 25)
        ].copy()
        chunk["ln_martyr_per100k_1953"] = chunk["countyid_curr6"].map(tm)
        chunk = chunk[chunk["ln_martyr_per100k_1953"].notna()].copy()
        if chunk.empty:
            continue

        cond = {
            "male": chunk["male"] == 1,
            "female": chunk["male"] == 0,
            "urban": chunk["urban_tag"] == 1,
            "rural": chunk["rural_tag"] == 1,
        }
        for g in ["male", "female", "urban", "rural"]:
            sub = chunk.loc[cond[g], keys + ["eduy", "minority"]]
            if sub.empty:
                continue
            agg = sub.groupby(keys, as_index=False).agg(
                sum_eduy=("eduy", "sum"),
                sum_minority=("minority", "sum"),
                n=("eduy", "size"),
            )
            pieces[g].append(agg)
        if i % 2 == 0:
            print(f"2000 chunk {i} done")

    panels: dict[str, pd.DataFrame] = {}
    for g in ["male", "female", "urban", "rural"]:
        if not pieces[g]:
            panels[g] = pd.DataFrame(columns=keys + ["eduy_mean", "minority_share", "n"])
            continue
        d = pd.concat(pieces[g], ignore_index=True)
        d = d.groupby(keys, as_index=False).agg(
            sum_eduy=("sum_eduy", "sum"),
            sum_minority=("sum_minority", "sum"),
            n=("n", "sum"),
        )
        d["eduy_mean"] = d["sum_eduy"] / d["n"]
        d["minority_share"] = d["sum_minority"] / d["n"]
        panels[g] = d[keys + ["eduy_mean", "minority_share", "n"]]
    save_group_panels(2000, panels)


def main() -> None:
    tm = treat_map()
    prep_1982(tm)
    print("1982 done")
    prep_1990(tm)
    print("1990 done")
    prep_2000(tm)
    print("2000 done")


if __name__ == "__main__":
    main()
