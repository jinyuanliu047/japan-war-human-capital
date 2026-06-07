#!/usr/bin/env python3
from __future__ import annotations

import math
from pathlib import Path

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


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    cw = pd.read_csv(PROJ / "data/temp/countyid_2000_to_current_routes_v1.csv", dtype=str)
    cw["old6"] = cw["county_old6"].map(code6)
    cw["countyid_curr6"] = cw["county_curr6"].map(code6)
    cw = cw[(cw["old6"] != "") & (cw["countyid_curr6"] != "")][["old6", "countyid_curr6"]].drop_duplicates("old6")
    cw_map = dict(zip(cw["old6"], cw["countyid_curr6"]))

    treat = pd.read_stata(PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
    treat["countyid_curr6"] = treat["countyid_curr6"].map(code6)
    treat = treat[["countyid_curr6", "ln_martyr_per100k_1953"]].drop_duplicates("countyid_curr6")
    treat_map = dict(zip(treat["countyid_curr6"], treat["ln_martyr_per100k_1953"]))

    keys = ["countyid_curr6", "birth_i", "ln_martyr_per100k_1953"]
    pieces = {g: [] for g in ["male", "female", "urban", "rural"]}

    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(PROJ / "data/raw/census/census2000.dta"),
        chunksize=600000,
        usecols=["uid", "birthyr", "eduyr", "sex", "race", "urban", "rural"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        chunk["old6"] = chunk["uid"].map(code6)
        chunk["countyid_curr6"] = chunk["old6"].map(cw_map)
        chunk["birth_i"] = pd.to_numeric(chunk["birthyr"], errors="coerce").floordiv(1)
        chunk["eduy"] = pd.to_numeric(chunk["eduyr"], errors="coerce")
        chunk["male"] = (chunk["sex"] == 1)
        chunk["female"] = (chunk["sex"] == 2)
        chunk["urban_tag"] = (chunk["urban"] == 1)
        chunk["rural_tag"] = (chunk["rural"] == 1)
        chunk["minority"] = (chunk["race"] != 1)
        chunk = chunk[
            chunk["countyid_curr6"].notna()
            & (chunk["countyid_curr6"] != "")
            & chunk["birth_i"].between(1920, 1978)
            & (chunk["birth_i"] != 1939)
            & chunk["eduy"].between(0, 25)
        ].copy()
        chunk["ln_martyr_per100k_1953"] = chunk["countyid_curr6"].map(treat_map)
        chunk = chunk[chunk["ln_martyr_per100k_1953"].notna()].copy()
        if chunk.empty:
            continue

        cond = {
            "male": chunk["male"],
            "female": chunk["female"],
            "urban": chunk["urban_tag"],
            "rural": chunk["rural_tag"],
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
        print(f"chunk {i} kept_rows={len(chunk)}")

    for g in ["male", "female", "urban", "rural"]:
        if not pieces[g]:
            continue
        d = pd.concat(pieces[g], ignore_index=True)
        d = d.groupby(keys, as_index=False).agg(
            sum_eduy=("sum_eduy", "sum"),
            sum_minority=("sum_minority", "sum"),
            n=("n", "sum"),
        )
        d["eduy_mean"] = d["sum_eduy"] / d["n"]
        d["minority_share"] = d["sum_minority"] / d["n"]
        d = d[keys + ["eduy_mean", "minority_share", "n"]]
        d.to_csv(OUT_DIR / f"panel_2000_{g}.csv", index=False, encoding="utf-8-sig")
        d.to_stata(OUT_DIR / f"panel_2000_{g}.dta", write_index=False, version=118)
        print(f"{g} rows={len(d)}")


if __name__ == "__main__":
    main()
