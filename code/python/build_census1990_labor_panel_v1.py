#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import shutil

import numpy as np
import pandas as pd
import pyreadstat


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
RAW = PROJ / "data/raw"
TEMP = PROJ / "data/temp"
TMP_CSV = Path("/tmp/census1990_labor_panel_v1.csv")
TMP_DTA = Path("/tmp/census1990_labor_panel_v1.dta")


def code6(x) -> str:
    if pd.isna(x):
        return ""
    s = str(x).replace(".0", "").strip()
    if not s or s.lower() == "nan":
        return ""
    digits = "".join(ch for ch in s if ch.isdigit())
    return digits.zfill(6)[-6:] if digits else ""


def main() -> None:
    cd = pd.read_stata(RAW / "county_data.dta", convert_categoricals=False)
    cd["old6"] = cd["region1990"].map(code6)
    cd["countyid_curr6"] = cd["region2010"].map(code6)
    map90 = dict(zip(cd.loc[cd["old6"] != "", "old6"], cd.loc[cd["old6"] != "", "countyid_curr6"]))

    treat = pd.read_stata(TEMP / "martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
    treat["countyid_curr6"] = treat["countyid_curr6"].map(code6)
    treat = treat[["countyid_curr6", "ln_martyr_per100k_1953"]].drop_duplicates("countyid_curr6")
    treat_map = dict(zip(treat["countyid_curr6"], treat["ln_martyr_per100k_1953"]))
    pref_treat = (
        pd.read_stata(TEMP / "martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
        .assign(countyid_curr6=lambda d: d["countyid_curr6"].map(code6))
        .assign(pref4_curr=lambda d: pd.to_numeric(d["countyid_curr6"].str[:4], errors="coerce"))
        .groupby("pref4_curr", as_index=False)
        .agg(pop_1953=("pop_1953", "sum"), martyr_count_1931_1945=("martyr_count_1931_1945", "sum"))
    )
    pref_treat["ln_martyr_per100k_1953"] = np.log(pref_treat["martyr_count_1931_1945"] / pref_treat["pop_1953"] * 100000.0 + 1.0)
    pref_treat_map = dict(zip(pref_treat["pref4_curr"], pref_treat["ln_martyr_per100k_1953"]))

    pieces = []
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(RAW / "census/census1990.dta"),
        chunksize=800000,
        usecols=["county", "age_c", "age", "sex", "race", "regstatu", "occu", "unemp_st"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        chunk["old6"] = chunk["county"].map(code6)
        chunk["countyid_curr6"] = chunk["old6"]
        direct_hit = chunk["countyid_curr6"].map(treat_map).notna()
        chunk.loc[~direct_hit, "countyid_curr6"] = chunk.loc[~direct_hit, "old6"].map(map90)
        chunk = chunk[chunk["countyid_curr6"].notna()].copy()
        chunk["birth_i"] = 1000 + pd.to_numeric(chunk["age_c"], errors="coerce") * 100 + pd.to_numeric(chunk["age"], errors="coerce")
        chunk = chunk[chunk["birth_i"].between(1920, 1968) & (chunk["birth_i"] != 1939)].copy()
        if chunk.empty:
            continue

        occu = pd.to_numeric(chunk["occu"], errors="coerce")
        unemp = pd.to_numeric(chunk["unemp_st"], errors="coerce")
        sex = pd.to_numeric(chunk["sex"], errors="coerce")
        race = pd.to_numeric(chunk["race"], errors="coerce")
        reg = pd.to_numeric(chunk["regstatu"], errors="coerce")

        chunk["male"] = np.where(sex.isin([1, 2]), (sex == 1).astype(float), np.nan)
        chunk["minority"] = np.where(race.notna(), (race != 1).astype(float), np.nan)
        chunk["rural"] = np.where(reg.between(1, 5), (reg == 1).astype(float), np.nan)
        chunk["employed"] = np.where(occu.notna(), (occu > 0).astype(float), np.nan)
        chunk["unemployed"] = np.where(unemp.notna() | occu.notna(), (unemp == 5).astype(float), np.nan)
        chunk["in_labor_force"] = np.where(occu.notna() | unemp.notna(), ((occu > 0) | (unemp == 5)).astype(float), np.nan)
        chunk["white_collar"] = np.where(chunk["employed"] == 1, occu.between(11, 499).astype(float), np.nan)
        chunk["professional_manager"] = np.where(chunk["employed"] == 1, occu.between(11, 399).astype(float), np.nan)
        chunk["clerical"] = np.where(chunk["employed"] == 1, occu.between(400, 499).astype(float), np.nan)
        chunk["service_sales"] = np.where(chunk["employed"] == 1, occu.between(500, 599).astype(float), np.nan)
        chunk["agri_occupation"] = np.where(chunk["employed"] == 1, occu.between(600, 699).astype(float), np.nan)
        chunk["craft"] = np.where(chunk["employed"] == 1, occu.between(700, 799).astype(float), np.nan)
        chunk["machine_operator"] = np.where(chunk["employed"] == 1, occu.between(800, 899).astype(float), np.nan)
        chunk["elementary"] = np.where(chunk["employed"] == 1, occu.between(900, 999).astype(float), np.nan)
        chunk["manual"] = np.where(chunk["employed"] == 1, occu.between(500, 999).astype(float), np.nan)
        chunk["nonagri"] = np.where(chunk["employed"] == 1, (~occu.between(600, 699)).astype(float), np.nan)

        keys = ["countyid_curr6", "birth_i"]
        agg = chunk.groupby(keys, as_index=False).agg(
            n_obs=("birth_i", "size"),
            male_share=("male", "mean"),
            minority_share=("minority", "mean"),
            rural_share=("rural", "mean"),
            in_labor_force=("in_labor_force", "mean"),
            employed=("employed", "mean"),
            unemployed=("unemployed", "mean"),
            nonagri=("nonagri", "mean"),
            white_collar=("white_collar", "mean"),
            professional_manager=("professional_manager", "mean"),
            clerical=("clerical", "mean"),
            service_sales=("service_sales", "mean"),
            agri_occupation=("agri_occupation", "mean"),
            craft=("craft", "mean"),
            machine_operator=("machine_operator", "mean"),
            elementary=("elementary", "mean"),
            manual=("manual", "mean"),
        )
        agg["pref4_curr"] = pd.to_numeric(agg["countyid_curr6"].str[:4], errors="coerce")
        agg["ln_martyr_per100k_1953"] = agg["countyid_curr6"].map(treat_map)
        agg.loc[agg["ln_martyr_per100k_1953"].isna(), "ln_martyr_per100k_1953"] = agg.loc[agg["ln_martyr_per100k_1953"].isna(), "pref4_curr"].map(pref_treat_map)
        pieces.append(agg)
        if i % 1 == 0:
            print(f"1990 labor chunk {i} done", flush=True)

    out = pd.concat(pieces, ignore_index=True)
    out = out.groupby(["countyid_curr6", "birth_i"], as_index=False).agg(
        n_obs=("n_obs", "sum"),
        male_share=("male_share", "mean"),
        minority_share=("minority_share", "mean"),
        rural_share=("rural_share", "mean"),
        in_labor_force=("in_labor_force", "mean"),
        employed=("employed", "mean"),
        unemployed=("unemployed", "mean"),
        nonagri=("nonagri", "mean"),
        white_collar=("white_collar", "mean"),
        professional_manager=("professional_manager", "mean"),
        clerical=("clerical", "mean"),
        service_sales=("service_sales", "mean"),
        agri_occupation=("agri_occupation", "mean"),
        craft=("craft", "mean"),
        machine_operator=("machine_operator", "mean"),
        elementary=("elementary", "mean"),
        manual=("manual", "mean"),
        ln_martyr_per100k_1953=("ln_martyr_per100k_1953", "mean"),
    )
    out["post"] = (out["birth_i"] >= 1940).astype(int)
    out["ln_martyr_per100k_1953"] = pd.to_numeric(out["ln_martyr_per100k_1953"], errors="coerce")
    out.loc[~np.isfinite(out["ln_martyr_per100k_1953"]), "ln_martyr_per100k_1953"] = np.nan
    out = out[out["ln_martyr_per100k_1953"].notna()].copy()

    out.to_csv(TMP_CSV, index=False, encoding="utf-8-sig")
    out.to_stata(TMP_DTA, write_index=False, version=118)
    shutil.copy2(TMP_CSV, TEMP / "census1990_labor_panel_v1.csv")
    shutil.copy2(TMP_DTA, TEMP / "census1990_labor_panel_v1.dta")
    print("census1990 labor panel saved", flush=True)


if __name__ == "__main__":
    main()
