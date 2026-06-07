#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
OUT_DIR = PROJ / "data/temp"

MANUAL_SUCCESSOR = {
    310103: "310101",
    310108: "310106",
    310119: "310115",
    110010: "110110",
}


def load_maps() -> tuple[dict[int, str], dict[int, str], dict[int, str], pd.DataFrame]:
    county = pd.read_excel(PROJ / "data/raw/China_Map/County0010.xlsx", sheet_name="County0010", usecols=["GBCounty"])
    county["GBCounty"] = pd.to_numeric(county["GBCounty"], errors="coerce").astype("Int64")
    county = county.dropna().drop_duplicates()
    county_dict = {int(v): f"{int(v):06d}" for v in county["GBCounty"]}

    cw1982 = pd.read_csv(PROJ / "data/temp/countyid_1982_to_current_crosswalk_v2.csv", dtype=str)
    cw1982["countyid_old6"] = pd.to_numeric(cw1982["countyid_old6"], errors="coerce").astype("Int64")
    cw1982["countyid_curr6_final"] = pd.to_numeric(cw1982["countyid_curr6_final"], errors="coerce").astype("Int64")
    cw1982 = cw1982.dropna(subset=["countyid_old6", "countyid_curr6_final"])
    cw1982_map = {
        int(old): f"{int(curr):06d}"
        for old, curr in cw1982[["countyid_old6", "countyid_curr6_final"]].drop_duplicates("countyid_old6").itertuples(index=False)
    }

    cw2000 = pd.read_csv(PROJ / "data/temp/countyid_2000_to_current_routes_v1.csv", dtype=str)
    cw2000["county_old6"] = pd.to_numeric(cw2000["county_old6"], errors="coerce").astype("Int64")
    cw2000["county_curr6"] = pd.to_numeric(cw2000["county_curr6"], errors="coerce").astype("Int64")
    cw2000 = cw2000.dropna(subset=["county_old6", "county_curr6"])
    cw2000_map = {
        int(old): f"{int(curr):06d}"
        for old, curr in cw2000[["county_old6", "county_curr6"]].drop_duplicates("county_old6").itertuples(index=False)
    }

    treat = pd.read_stata(PROJ / "data/temp/did_1982_county_birthyr_pop1953_unwt_v2.dta", convert_categoricals=False)
    treat = treat[
        [
            "countyid_curr6",
            "pop_1953",
            "martyr_count_1931_1945",
            "ln_martyr_raw",
            "martyr_per100k_1953",
            "ln_martyr_per100k_1953",
        ]
    ].drop_duplicates("countyid_curr6")
    treat["countyid_curr6"] = treat["countyid_curr6"].astype(str).str.zfill(6)
    return county_dict, cw1982_map, cw2000_map, treat


def resolve_old_codes(codes: pd.Series, county_dict: dict[int, str], cw1982_map: dict[int, str]) -> pd.Series:
    vals = pd.to_numeric(codes, errors="coerce").astype("Int64")
    out = vals.map(MANUAL_SUCCESSOR)
    out = out.where(out.notna(), vals.map(county_dict))
    out = out.where(out.notna(), vals.map(cw1982_map))

    s = vals.astype("string").str.zfill(6)
    is_muni = s.str.slice(0, 2).isin(["11", "12", "31"]) & s.str.slice(2, 4).eq("00")
    muni = (s.str.slice(0, 2) + "01" + s.str.slice(4, 6)).where(is_muni)
    muni_num = pd.to_numeric(muni, errors="coerce").astype("Int64")
    out = out.where(out.notna(), muni_num.map(county_dict))
    out = out.where(out.notna(), muni_num.map(cw1982_map))
    return out


def collapse_piece(df: pd.DataFrame) -> pd.DataFrame:
    keys = ["countyid_curr6", "birth_i"]
    out = (
        df.groupby(keys, as_index=False)
        .agg(
            n_obs=("eduy", "size"),
            sum_eduy=("eduy", "sum"),
            sum_pri=("pri", "sum"),
            sum_mid=("mid", "sum"),
            sum_high=("high", "sum"),
            sum_college=("college", "sum"),
        )
    )
    return out


def finalize(pieces: list[pd.DataFrame], treat: pd.DataFrame) -> pd.DataFrame:
    d = pd.concat(pieces, ignore_index=True)
    d = (
        d.groupby(["countyid_curr6", "birth_i"], as_index=False)
        .agg(
            n_obs=("n_obs", "sum"),
            sum_eduy=("sum_eduy", "sum"),
            sum_pri=("sum_pri", "sum"),
            sum_mid=("sum_mid", "sum"),
            sum_high=("sum_high", "sum"),
            sum_college=("sum_college", "sum"),
        )
    )
    d["eduy_mean"] = d["sum_eduy"] / d["n_obs"]
    d["pri_comp"] = d["sum_pri"] / d["n_obs"]
    d["mid_comp"] = d["sum_mid"] / d["n_obs"]
    d["high_comp"] = d["sum_high"] / d["n_obs"]
    d["college_comp"] = d["sum_college"] / d["n_obs"]
    d = d.merge(treat, on="countyid_curr6", how="left")
    d = d.sort_values(["countyid_curr6", "birth_i"]).reset_index(drop=True)
    return d


def build_1982(county_dict: dict[int, str], cw1982_map: dict[int, str], treat: pd.DataFrame) -> None:
    pieces: list[pd.DataFrame] = []
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(PROJ / "data/temp/census_1982_cleaned.dta"),
        chunksize=1_000_000,
        usecols=["countyid", "birthyr", "eduy"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        chunk["countyid_curr6"] = resolve_old_codes(chunk["countyid"], county_dict, cw1982_map)
        chunk["birth_i"] = pd.to_numeric(chunk["birthyr"], errors="coerce").astype("Int64")
        chunk["eduy"] = pd.to_numeric(chunk["eduy"], errors="coerce")
        chunk = chunk[
            chunk["countyid_curr6"].notna()
            & chunk["birth_i"].between(1920, 1960)
            & (chunk["birth_i"] != 1939)
            & chunk["eduy"].between(0, 25)
        ].copy()
        chunk["pri"] = (chunk["eduy"] >= 6).astype(float)
        chunk["mid"] = (chunk["eduy"] >= 9).astype(float)
        chunk["high"] = (chunk["eduy"] >= 12).astype(float)
        chunk["college"] = (chunk["eduy"] >= 16).astype(float)
        pieces.append(collapse_piece(chunk))
        print(f"1982 chunk {i} done")
    out = finalize(pieces, treat)
    out.to_stata(OUT_DIR / "county_y_panel_1982_v1.dta", write_index=False, version=118)
    out.to_csv(OUT_DIR / "county_y_panel_1982_v1.csv", index=False, encoding="utf-8-sig")


def build_1990(county_dict: dict[int, str], cw1982_map: dict[int, str], treat: pd.DataFrame) -> None:
    pieces: list[pd.DataFrame] = []
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(PROJ / "data/raw/census/census1990.dta"),
        chunksize=1_000_000,
        usecols=["county", "age_c", "age", "educ"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        chunk["countyid_curr6"] = resolve_old_codes(chunk["county"], county_dict, cw1982_map)
        age_c = pd.to_numeric(chunk["age_c"], errors="coerce")
        age = pd.to_numeric(chunk["age"], errors="coerce")
        educ = pd.to_numeric(chunk["educ"], errors="coerce")
        chunk["birth_i"] = (1000 + age_c * 100 + age).astype("Int64")
        eduy = pd.Series(np.nan, index=chunk.index)
        eduy = eduy.mask(educ == 1, 0)
        eduy = eduy.mask(educ == 2, 6)
        eduy = eduy.mask(educ == 3, 9)
        eduy = eduy.mask(educ.isin([4, 5]), 12)
        eduy = eduy.mask(educ == 6, 15)
        eduy = eduy.mask(educ == 7, 16)
        chunk["eduy"] = eduy
        chunk = chunk[
            chunk["countyid_curr6"].notna()
            & chunk["birth_i"].between(1920, 1968)
            & (chunk["birth_i"] != 1939)
            & chunk["eduy"].between(0, 25)
        ].copy()
        chunk["pri"] = (chunk["eduy"] >= 6).astype(float)
        chunk["mid"] = (chunk["eduy"] >= 9).astype(float)
        chunk["high"] = (chunk["eduy"] >= 12).astype(float)
        chunk["college"] = (chunk["eduy"] >= 16).astype(float)
        pieces.append(collapse_piece(chunk))
        print(f"1990 chunk {i} done")
    out = finalize(pieces, treat)
    out.to_stata(OUT_DIR / "county_y_panel_1990_v1.dta", write_index=False, version=118)
    out.to_csv(OUT_DIR / "county_y_panel_1990_v1.csv", index=False, encoding="utf-8-sig")


def build_2000(cw2000_map: dict[int, str], treat: pd.DataFrame) -> None:
    pieces: list[pd.DataFrame] = []
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(PROJ / "data/raw/census/census2000.dta"),
        chunksize=1_000_000,
        usecols=["uid", "birthyr", "eduyr"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        uid = pd.to_numeric(chunk["uid"], errors="coerce").astype("Int64")
        chunk["countyid_curr6"] = uid.map(cw2000_map)
        chunk["birth_i"] = pd.to_numeric(chunk["birthyr"], errors="coerce").astype("Int64")
        chunk["eduy"] = pd.to_numeric(chunk["eduyr"], errors="coerce")
        chunk = chunk[
            chunk["countyid_curr6"].notna()
            & chunk["birth_i"].between(1920, 1978)
            & (chunk["birth_i"] != 1939)
            & chunk["eduy"].between(0, 25)
        ].copy()
        chunk["pri"] = (chunk["eduy"] >= 6).astype(float)
        chunk["mid"] = (chunk["eduy"] >= 9).astype(float)
        chunk["high"] = (chunk["eduy"] >= 12).astype(float)
        chunk["college"] = (chunk["eduy"] >= 16).astype(float)
        pieces.append(collapse_piece(chunk))
        print(f"2000 chunk {i} done")
    out = finalize(pieces, treat)
    out.to_stata(OUT_DIR / "county_y_panel_2000_v1.dta", write_index=False, version=118)
    out.to_csv(OUT_DIR / "county_y_panel_2000_v1.csv", index=False, encoding="utf-8-sig")


def main() -> None:
    county_dict, cw1982_map, cw2000_map, treat = load_maps()
    build_1982(county_dict, cw1982_map, treat)
    print("1982 done")
    build_1990(county_dict, cw1982_map, treat)
    print("1990 done")
    build_2000(cw2000_map, treat)
    print("2000 done")


if __name__ == "__main__":
    main()
