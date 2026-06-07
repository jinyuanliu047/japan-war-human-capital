#!/usr/bin/env python3
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat


PROJ = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
)


def code6(x: object) -> str:
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return ""
    s = str(x).strip().replace(".0", "")
    d = "".join(ch for ch in s if ch.isdigit())
    if not d:
        return ""
    return d[:6].zfill(6)


def aggregate_panel(df: pd.DataFrame, group: str) -> pd.DataFrame:
    if group == "male":
        df = df[df["female"] == 0].copy()
    elif group == "female":
        df = df[df["female"] == 1].copy()
    elif group == "urban":
        df = df[df["urban_tag"] == 1].copy()
    elif group == "rural":
        df = df[df["rural_tag"] == 1].copy()
    elif group == "reloc0":
        df = df[df["reloc_any"] == 0].copy()
    elif group == "reloc1":
        df = df[df["reloc_any"] == 1].copy()
    else:
        raise ValueError(group)
    if df.empty:
        return pd.DataFrame(columns=["countyid_curr6", "birth_i", "ln_martyr_per100k_1953", "eduy_mean"])
    g = (
        df.groupby(["countyid_curr6", "birth_i", "ln_martyr_per100k_1953"], as_index=False)
        .agg(eduy_mean=("eduy", "mean"))
    )
    return g


def base_merge_controls(df: pd.DataFrame, wave: int) -> pd.DataFrame:
    treat = pd.read_stata(PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
    treat["countyid_curr6"] = treat["countyid_curr6"].map(code6)
    treat = treat[["countyid_curr6", "ln_martyr_per100k_1953"]].drop_duplicates("countyid_curr6")

    reloc = pd.read_stata(PROJ / "data/temp/county_university_relocation_any_v1.dta", convert_categoricals=False)
    reloc["countyid_curr6"] = reloc["countyid_curr6"].map(code6)
    reloc["reloc_any"] = reloc["reloc_any"].fillna(0).astype(int)
    reloc = reloc[["countyid_curr6", "reloc_any"]].drop_duplicates("countyid_curr6")

    hi = 1960 if wave == 1982 else (1968 if wave == 1990 else 1978)
    df = df[(df["birthyr"] >= 1920) & (df["birthyr"] <= hi)].copy()
    df["birth_i"] = np.floor(df["birthyr"]).astype(int)
    df = df[df["birth_i"] != 1939].copy()
    df = df[(df["eduy"] >= 0) & (df["eduy"] <= 25)].copy()
    df = df.merge(treat, on="countyid_curr6", how="inner")
    df = df.merge(reloc, on="countyid_curr6", how="left")
    df["reloc_any"] = df["reloc_any"].fillna(0).astype(int)
    return df


def prep_1982() -> pd.DataFrame:
    d = pd.read_stata(PROJ / "data/temp/census_1982_cleaned.dta", convert_categoricals=False)
    d = d[["countyid", "birthyr", "eduy", "sex", "ethniccn"]].copy()
    d["countyid_curr6"] = d["countyid"].map(code6)
    d = d[d["countyid_curr6"] != ""].copy()
    d["female"] = np.where(d["sex"].notna(), (d["sex"] == 2).astype(float), np.nan)
    d["minority"] = np.where(d["ethniccn"].notna(), (d["ethniccn"] != 1).astype(float), np.nan)
    d["urban_tag"] = np.nan
    d["rural_tag"] = np.nan
    d = d.dropna(subset=["birthyr", "eduy"]).copy()
    return base_merge_controls(d, 1982)


def prep_1990() -> pd.DataFrame:
    d = pd.read_stata(PROJ / "data/raw/census_1990_clean.dta", convert_categoricals=False)
    d = d[["region1990", "year_birth", "yedu", "male", "han_ethn", "rural"]].copy()
    d = d.rename(columns={"year_birth": "birthyr", "yedu": "eduy"})
    d["countyid_curr6"] = d["region1990"].map(code6)
    d = d[d["countyid_curr6"] != ""].copy()
    d["female"] = np.where(d["male"].notna(), (d["male"] == 0).astype(float), np.nan)
    d["minority"] = np.where(d["han_ethn"].notna(), (d["han_ethn"] == 0).astype(float), np.nan)
    d["rural_tag"] = np.where(d["rural"].notna(), (d["rural"] == 1).astype(float), np.nan)
    d["urban_tag"] = np.where(d["rural"].notna(), (d["rural"] == 0).astype(float), np.nan)
    d = d.dropna(subset=["birthyr", "eduy"]).copy()
    return base_merge_controls(d, 1990)


def prep_2000() -> pd.DataFrame:
    # chunked read to avoid I/O stalls on full 2000 raw dta
    cw = pd.read_csv(PROJ / "data/temp/countyid_2000_to_current_routes_v1.csv", dtype=str)
    cw["old6"] = cw["county_old6"].map(code6)
    cw["countyid_curr6"] = cw["county_curr6"].map(code6)
    cw = cw[(cw["old6"] != "") & (cw["countyid_curr6"] != "")][["old6", "countyid_curr6"]].drop_duplicates("old6")
    cw_map = dict(zip(cw["old6"], cw["countyid_curr6"]))

    treat = pd.read_stata(PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
    treat["countyid_curr6"] = treat["countyid_curr6"].map(code6)
    treat = treat[["countyid_curr6", "ln_martyr_per100k_1953"]].drop_duplicates("countyid_curr6")
    treat_map = dict(zip(treat["countyid_curr6"], treat["ln_martyr_per100k_1953"]))

    reloc = pd.read_stata(PROJ / "data/temp/county_university_relocation_any_v1.dta", convert_categoricals=False)
    reloc["countyid_curr6"] = reloc["countyid_curr6"].map(code6)
    reloc["reloc_any"] = reloc["reloc_any"].fillna(0).astype(int)
    reloc_map = dict(zip(reloc["countyid_curr6"], reloc["reloc_any"]))

    groups = ["male", "female", "urban", "rural", "reloc0", "reloc1"]
    pieces: dict[str, list[pd.DataFrame]] = {g: [] for g in groups}
    keys = ["countyid_curr6", "birth_i", "ln_martyr_per100k_1953"]

    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(PROJ / "data/raw/census/census2000.dta"),
        chunksize=800000,
        usecols=["uid", "birthyr", "eduyr", "sex", "race", "urban", "rural"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        chunk = chunk.rename(columns={"eduyr": "eduy"})
        chunk["old6"] = chunk["uid"].map(code6)
        chunk["countyid_curr6"] = chunk["old6"].map(cw_map)
        chunk = chunk[chunk["countyid_curr6"].notna()].copy()
        chunk = chunk.dropna(subset=["birthyr", "eduy"])
        chunk["birth_i"] = np.floor(chunk["birthyr"]).astype(int)
        chunk = chunk[(chunk["birth_i"] >= 1920) & (chunk["birth_i"] <= 1978) & (chunk["birth_i"] != 1939)]
        chunk = chunk[(chunk["eduy"] >= 0) & (chunk["eduy"] <= 25)]
        if chunk.empty:
            continue
        chunk["female"] = np.where(chunk["sex"].notna(), (chunk["sex"] == 2).astype(int), -1)
        chunk["urban_tag"] = np.where(chunk["urban"].notna(), (chunk["urban"] == 1).astype(int), -1)
        chunk["rural_tag"] = np.where(chunk["rural"].notna(), (chunk["rural"] == 1).astype(int), -1)
        chunk["reloc_any"] = chunk["countyid_curr6"].map(reloc_map).fillna(0).astype(int)
        chunk["ln_martyr_per100k_1953"] = chunk["countyid_curr6"].map(treat_map)
        chunk = chunk[chunk["ln_martyr_per100k_1953"].notna()].copy()
        if chunk.empty:
            continue

        cond = {
            "male": chunk["female"] == 0,
            "female": chunk["female"] == 1,
            "urban": chunk["urban_tag"] == 1,
            "rural": chunk["rural_tag"] == 1,
            "reloc0": chunk["reloc_any"] == 0,
            "reloc1": chunk["reloc_any"] == 1,
        }
        for g in groups:
            sub = chunk.loc[cond[g], ["countyid_curr6", "birth_i", "ln_martyr_per100k_1953", "eduy"]]
            if sub.empty:
                continue
            agg = sub.groupby(keys, as_index=False).agg(sum_eduy=("eduy", "sum"), n=("eduy", "size"))
            pieces[g].append(agg)
        if i % 2 == 0:
            print(f"2000 chunk {i} done")

    out = []
    for g in groups:
        if not pieces[g]:
            continue
        d = pd.concat(pieces[g], ignore_index=True)
        d = d.groupby(keys, as_index=False).agg(sum_eduy=("sum_eduy", "sum"), n=("n", "sum"))
        d["eduy_mean"] = d["sum_eduy"] / d["n"]
        d["group"] = g
        out.append(d[keys + ["eduy_mean", "group"]])
    if not out:
        return pd.DataFrame(columns=["countyid_curr6", "birth_i", "ln_martyr_per100k_1953", "eduy_mean", "group"])
    return pd.concat(out, ignore_index=True)


def save_wave_groups(df: pd.DataFrame, wave: int) -> None:
    out_dir = PROJ / "data/temp/heterogeneity_groups_v1"
    out_dir.mkdir(parents=True, exist_ok=True)
    groups = ["male", "female", "reloc0", "reloc1"]
    if wave in (1990, 2000):
        groups += ["urban", "rural"]
    for g in groups:
        panel = aggregate_panel(df, g)
        panel.to_csv(out_dir / f"panel_{wave}_{g}.csv", index=False, encoding="utf-8-sig")
        panel.to_stata(out_dir / f"panel_{wave}_{g}.dta", write_index=False, version=118)


def main() -> None:
    d82 = prep_1982()
    save_wave_groups(d82, 1982)
    print("1982 done", len(d82))

    d90 = prep_1990()
    save_wave_groups(d90, 1990)
    print("1990 done", len(d90))

    d00 = prep_2000()
    out_dir = PROJ / "data/temp/heterogeneity_groups_v1"
    out_dir.mkdir(parents=True, exist_ok=True)
    for g in ["male", "female", "urban", "rural", "reloc0", "reloc1"]:
        panel = d00[d00["group"] == g][["countyid_curr6", "birth_i", "ln_martyr_per100k_1953", "eduy_mean"]].copy()
        panel.to_csv(out_dir / f"panel_2000_{g}.csv", index=False, encoding="utf-8-sig")
        panel.to_stata(out_dir / f"panel_2000_{g}.dta", write_index=False, version=118)
    print("2000 done", len(d00))


if __name__ == "__main__":
    main()
