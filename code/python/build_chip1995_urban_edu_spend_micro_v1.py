#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
HH_SRC = PROJ / "data/raw/1995/1995_DS0004_urban_household/DS0004_urban_household/03012-0004-Data.dta"
IND_SRC = PROJ / "data/raw/1995/1995_DS0003_urban_individual/DS0003_urban_individual/03012-0003-Data.dta"
COUNTY_TREAT = PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta"
COUNTY_MAP = PROJ / "data/raw/China_Map/County0010.xlsx"
OUT_DTA = PROJ / "data/temp/chip1995_urban_edu_spend_micro_v1.dta"
OUT_CSV = PROJ / "data/temp/chip1995_urban_edu_spend_micro_v1.csv"
AUDIT_CSV = PROJ / "data/temp/chip1995_urban_prefecture_match_audit_v1.csv"


def build_pref_treat() -> pd.DataFrame:
    county = pd.read_excel(COUNTY_MAP, sheet_name="County0010", usecols=["GbCity", "GBCounty"])
    county["GBCounty"] = pd.to_numeric(county["GBCounty"], errors="coerce").astype("Int64")
    county["GbCity"] = pd.to_numeric(county["GbCity"], errors="coerce").astype("Int64")
    county = county.dropna(subset=["GBCounty", "GbCity"]).copy()
    county["countyid_curr6"] = county["GBCounty"].astype(int).map(lambda x: f"{x:06d}")
    county["pref4_curr"] = county["GbCity"].astype(int)

    treat = pd.read_stata(COUNTY_TREAT, convert_categoricals=False)
    treat["countyid_curr6"] = pd.to_numeric(treat["countyid_curr6"], errors="coerce").astype("Int64")
    treat = treat.dropna(subset=["countyid_curr6"]).copy()
    treat["countyid_curr6"] = treat["countyid_curr6"].astype(int).map(lambda x: f"{x:06d}")
    treat = treat[["countyid_curr6", "pop_1953", "martyr_count_1931_1945"]].copy()
    treat = treat.merge(county[["countyid_curr6", "pref4_curr"]], on="countyid_curr6", how="left")
    treat = treat.dropna(subset=["pref4_curr"]).copy()

    pref = (
        treat.groupby("pref4_curr", as_index=False)
        .agg(pop_1953=("pop_1953", "sum"), martyr_count_1931_1945=("martyr_count_1931_1945", "sum"))
    )
    pref["martyr_per100k_1953"] = np.where(
        pref["pop_1953"] > 0,
        pref["martyr_count_1931_1945"] / pref["pop_1953"] * 100000.0,
        np.nan,
    )
    pref["ln_martyr_per100k_1953"] = np.log(pref["martyr_per100k_1953"] + 1.0)
    return pref


def main() -> None:
    hh, _ = pyreadstat.read_dta(str(HH_SRC), usecols=["N1", "PROVINCE", "COUNTY", "NHH", "H38", "H39", "H40", "H41"])
    ind, _ = pyreadstat.read_dta(
        str(IND_SRC),
        usecols=["N1", "PROVINCE", "COUNTY", "A2", "A3", "A4", "A5", "A6", "A11", "A12"],
    )

    hh["N1"] = pd.to_numeric(hh["N1"], errors="coerce")
    ind["N1"] = pd.to_numeric(ind["N1"], errors="coerce")
    hh["pref4_guess"] = (pd.to_numeric(hh["PROVINCE"], errors="coerce") * 100 + pd.to_numeric(hh["COUNTY"], errors="coerce") - 10).astype("Int64")
    ind["pref4_guess"] = (pd.to_numeric(ind["PROVINCE"], errors="coerce") * 100 + pd.to_numeric(ind["COUNTY"], errors="coerce") - 10).astype("Int64")

    head = ind.loc[pd.to_numeric(ind["A2"], errors="coerce") == 1].copy()
    head = head.sort_values(["N1"]).drop_duplicates("N1")
    head["head_birth_i"] = 1995 - pd.to_numeric(head["A5"], errors="coerce")
    head["head_female"] = np.where(pd.to_numeric(head["A4"], errors="coerce").isin([1, 2]), (pd.to_numeric(head["A4"], errors="coerce") == 2).astype(float), np.nan)
    head["head_working"] = np.where(pd.to_numeric(head["A6"], errors="coerce").isin(range(1, 9)), (pd.to_numeric(head["A6"], errors="coerce") == 1).astype(float), np.nan)
    head["head_eduy"] = np.where(pd.to_numeric(head["A12"], errors="coerce").between(0, 30), pd.to_numeric(head["A12"], errors="coerce"), np.nan)
    head = head[["N1", "pref4_guess", "head_birth_i", "head_female", "head_working", "head_eduy"]].copy()

    out = hh.merge(head, on=["N1", "pref4_guess"], how="left")
    for col in ["H38", "H39", "H40", "H41", "NHH"]:
        out[col] = pd.to_numeric(out[col], errors="coerce")
    out["edu_book"] = out["H38"]
    out["tuition_fee"] = out["H39"]
    out["child_edu_other"] = out["H40"]
    out["adult_training"] = out["H41"]
    out["edu_total"] = out[["H38", "H39", "H40", "H41"]].fillna(0).sum(axis=1)

    pref_treat = build_pref_treat()
    out = out.merge(pref_treat, left_on="pref4_guess", right_on="pref4_curr", how="left")

    audit = (
        out[["pref4_guess", "pref4_curr", "ln_martyr_per100k_1953"]]
        .drop_duplicates()
        .assign(match_status=lambda d: np.where(d["ln_martyr_per100k_1953"].notna(), "matched_current_pref4", "unmatched_old_pref4"))
        .sort_values("pref4_guess")
    )
    audit.to_csv(AUDIT_CSV, index=False, encoding="utf-8-sig")

    out["birth_i"] = pd.to_numeric(out["head_birth_i"], errors="coerce")
    out = out[out["birth_i"].between(1920, 1977) & (out["birth_i"] != 1939)].copy()
    out["post"] = (out["birth_i"] >= 1940).astype(float)

    keep = [
        "N1",
        "pref4_guess",
        "birth_i",
        "post",
        "NHH",
        "head_female",
        "head_working",
        "head_eduy",
        "edu_book",
        "tuition_fee",
        "child_edu_other",
        "adult_training",
        "edu_total",
        "martyr_count_1931_1945",
        "pop_1953",
        "martyr_per100k_1953",
        "ln_martyr_per100k_1953",
    ]
    out = out[keep].copy()
    OUT_DTA.parent.mkdir(parents=True, exist_ok=True)
    out.to_stata(OUT_DTA, write_index=False, version=118)
    out.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")


if __name__ == "__main__":
    main()
