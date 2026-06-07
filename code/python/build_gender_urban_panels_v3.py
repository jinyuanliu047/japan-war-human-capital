#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
OUT_DIR = PROJ / "data/temp/heterogeneity_groups_v3"

MANUAL_SUCCESSOR = {
    310103: "310101",
    310108: "310106",
    310119: "310115",
    110010: "110110",
}


def load_dicts() -> tuple[dict[int, str], dict[int, str], dict[int, str], dict[str, float]]:
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

    treat = pd.read_stata(PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
    treat["countyid_curr6"] = pd.to_numeric(treat["countyid_curr6"], errors="coerce").astype("Int64")
    treat = treat.dropna(subset=["countyid_curr6", "ln_martyr_per100k_1953"])
    treat_map = {
        f"{int(code):06d}": float(val)
        for code, val in treat[["countyid_curr6", "ln_martyr_per100k_1953"]].drop_duplicates("countyid_curr6").itertuples(index=False)
    }

    return county_dict, cw1982_map, cw2000_map, treat_map


def resolve_old_codes(codes: pd.Series, county_dict: dict[int, str], cw1982_map: dict[int, str]) -> pd.Series:
    vals = pd.to_numeric(codes, errors="coerce").astype("Int64")
    out = vals.map(MANUAL_SUCCESSOR)
    out = out.where(out.notna(), vals.map(county_dict))
    out = out.where(out.notna(), vals.map(cw1982_map))

    s = vals.astype("string").str.zfill(6)
    is_muni = s.str.slice(0, 2).isin(["11", "12", "31"]) & s.str.slice(2, 4).eq("00")
    muni = (s.str.slice(0, 2) + "01" + s.str.slice(4, 6)).where(is_muni)
    muni_num = pd.to_numeric(muni, errors="coerce").astype("Int64")

    muni_exact = muni_num.map(county_dict)
    out = out.where(out.notna(), muni_exact)
    muni_cw = muni_num.map(cw1982_map)
    out = out.where(out.notna(), muni_cw)
    return out


def collapse_groups(df: pd.DataFrame, groups: list[str]) -> dict[str, pd.DataFrame]:
    keys = ["countyid_curr6", "birth_i", "ln_martyr_per100k_1953"]
    out: dict[str, pd.DataFrame] = {}
    masks = {
        "male": df["female"] == 0,
        "female": df["female"] == 1,
        "urban": df["urban_tag"] == 1,
        "rural": df["rural_tag"] == 1,
    }
    for g in groups:
        sub = df.loc[masks[g], keys + ["eduy", "minority"]]
        if sub.empty:
            out[g] = pd.DataFrame(columns=keys + ["sum_eduy", "sum_minority", "n"])
            continue
        agg = (
            sub.groupby(keys, as_index=False)
            .agg(sum_eduy=("eduy", "sum"), sum_minority=("minority", "sum"), n=("eduy", "size"))
        )
        out[g] = agg
    return out


def finalize_panels(pieces: dict[str, list[pd.DataFrame]]) -> dict[str, pd.DataFrame]:
    keys = ["countyid_curr6", "birth_i", "ln_martyr_per100k_1953"]
    out: dict[str, pd.DataFrame] = {}
    for g, lst in pieces.items():
        if not lst:
            out[g] = pd.DataFrame(columns=keys + ["eduy_mean", "minority_share", "n"])
            continue
        d = pd.concat(lst, ignore_index=True)
        d = d.groupby(keys, as_index=False).agg(
            sum_eduy=("sum_eduy", "sum"),
            sum_minority=("sum_minority", "sum"),
            n=("n", "sum"),
        )
        d["eduy_mean"] = d["sum_eduy"] / d["n"]
        d["minority_share"] = d["sum_minority"] / d["n"]
        out[g] = d[keys + ["eduy_mean", "minority_share", "n"]]
    return out


def save_panels(wave: int, panels: dict[str, pd.DataFrame]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for g, panel in panels.items():
        panel = panel.sort_values(["countyid_curr6", "birth_i"]).reset_index(drop=True)
        panel.to_csv(OUT_DIR / f"panel_{wave}_{g}.csv", index=False, encoding="utf-8-sig")
        panel.to_stata(OUT_DIR / f"panel_{wave}_{g}.dta", write_index=False, version=118)


def build_1982(county_dict: dict[int, str], cw1982_map: dict[int, str], treat_map: dict[str, float]) -> None:
    pieces = {"male": [], "female": []}
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(PROJ / "data/temp/census_1982_cleaned.dta"),
        chunksize=1_000_000,
        usecols=["countyid", "birthyr", "eduy", "sex", "ethniccn"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        chunk["countyid_curr6"] = resolve_old_codes(chunk["countyid"], county_dict, cw1982_map)
        chunk["birth_i"] = pd.to_numeric(chunk["birthyr"], errors="coerce").astype("Int64")
        chunk["eduy"] = pd.to_numeric(chunk["eduy"], errors="coerce")
        chunk["female"] = np.where(chunk["sex"].notna(), (pd.to_numeric(chunk["sex"], errors="coerce") == 2).astype(float), np.nan)
        chunk["minority"] = np.where(chunk["ethniccn"].notna(), (pd.to_numeric(chunk["ethniccn"], errors="coerce") != 1).astype(float), np.nan)
        chunk["urban_tag"] = np.nan
        chunk["rural_tag"] = np.nan
        chunk = chunk[
            chunk["countyid_curr6"].notna()
            & chunk["birth_i"].between(1920, 1960)
            & (chunk["birth_i"] != 1939)
            & chunk["eduy"].between(0, 25)
        ].copy()
        chunk["ln_martyr_per100k_1953"] = chunk["countyid_curr6"].map(treat_map)
        chunk = chunk[chunk["ln_martyr_per100k_1953"].notna()].copy()
        collapsed = collapse_groups(chunk, ["male", "female"])
        for g in ["male", "female"]:
            if not collapsed[g].empty:
                pieces[g].append(collapsed[g])
        print(f"1982 chunk {i} done")
    save_panels(1982, finalize_panels(pieces))


def build_1990(county_dict: dict[int, str], cw1982_map: dict[int, str], treat_map: dict[str, float]) -> None:
    pieces = {"male": [], "female": [], "urban": [], "rural": []}
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(PROJ / "data/raw/census/census1990.dta"),
        chunksize=1_000_000,
        usecols=["county", "age_c", "age", "educ", "sex", "race", "regstatu"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        chunk["countyid_curr6"] = resolve_old_codes(chunk["county"], county_dict, cw1982_map)
        age_c = pd.to_numeric(chunk["age_c"], errors="coerce")
        age = pd.to_numeric(chunk["age"], errors="coerce")
        educ = pd.to_numeric(chunk["educ"], errors="coerce")
        birth = 1000 + age_c * 100 + age
        chunk["birth_i"] = birth.astype("Int64")
        eduy = pd.Series(np.nan, index=chunk.index)
        eduy = eduy.mask(educ == 1, 0)
        eduy = eduy.mask(educ == 2, 6)
        eduy = eduy.mask(educ == 3, 9)
        eduy = eduy.mask(educ.isin([4, 5]), 12)
        eduy = eduy.mask(educ == 6, 15)
        eduy = eduy.mask(educ == 7, 16)
        chunk["eduy"] = eduy
        sex = pd.to_numeric(chunk["sex"], errors="coerce")
        race = pd.to_numeric(chunk["race"], errors="coerce")
        reg = pd.to_numeric(chunk["regstatu"], errors="coerce")
        chunk["female"] = np.where(sex.notna(), (sex == 2).astype(float), np.nan)
        chunk["minority"] = np.where(race.notna(), (race != 1).astype(float), np.nan)
        chunk["urban_tag"] = np.where(reg.notna(), reg.isin([1, 2]).astype(float), np.nan)
        chunk["rural_tag"] = np.where(reg.notna(), reg.isin([3, 4, 5]).astype(float), np.nan)
        chunk = chunk[
            chunk["countyid_curr6"].notna()
            & chunk["birth_i"].between(1920, 1968)
            & (chunk["birth_i"] != 1939)
            & chunk["eduy"].between(0, 25)
        ].copy()
        chunk["ln_martyr_per100k_1953"] = chunk["countyid_curr6"].map(treat_map)
        chunk = chunk[chunk["ln_martyr_per100k_1953"].notna()].copy()
        collapsed = collapse_groups(chunk, ["male", "female", "urban", "rural"])
        for g in ["male", "female", "urban", "rural"]:
            if not collapsed[g].empty:
                pieces[g].append(collapsed[g])
        print(f"1990 chunk {i} done")
    save_panels(1990, finalize_panels(pieces))


def build_2000(cw2000_map: dict[int, str], treat_map: dict[str, float]) -> None:
    pieces = {"male": [], "female": [], "urban": [], "rural": []}
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(PROJ / "data/raw/census/census2000.dta"),
        chunksize=1_000_000,
        usecols=["uid", "birthyr", "eduyr", "sex", "race", "urban", "rural"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        uid = pd.to_numeric(chunk["uid"], errors="coerce").astype("Int64")
        chunk["countyid_curr6"] = uid.map(cw2000_map)
        chunk["birth_i"] = pd.to_numeric(chunk["birthyr"], errors="coerce").astype("Int64")
        chunk["eduy"] = pd.to_numeric(chunk["eduyr"], errors="coerce")
        sex = pd.to_numeric(chunk["sex"], errors="coerce")
        race = pd.to_numeric(chunk["race"], errors="coerce")
        urban = pd.to_numeric(chunk["urban"], errors="coerce")
        rural = pd.to_numeric(chunk["rural"], errors="coerce")
        chunk["female"] = np.where(sex.notna(), (sex == 2).astype(float), np.nan)
        chunk["minority"] = np.where(race.notna(), (race != 1).astype(float), np.nan)
        chunk["urban_tag"] = np.where(urban.notna(), (urban == 1).astype(float), np.nan)
        chunk["rural_tag"] = np.where(rural.notna(), (rural == 1).astype(float), np.nan)
        chunk = chunk[
            chunk["countyid_curr6"].notna()
            & chunk["birth_i"].between(1920, 1978)
            & (chunk["birth_i"] != 1939)
            & chunk["eduy"].between(0, 25)
        ].copy()
        chunk["ln_martyr_per100k_1953"] = chunk["countyid_curr6"].map(treat_map)
        chunk = chunk[chunk["ln_martyr_per100k_1953"].notna()].copy()
        collapsed = collapse_groups(chunk, ["male", "female", "urban", "rural"])
        for g in ["male", "female", "urban", "rural"]:
            if not collapsed[g].empty:
                pieces[g].append(collapsed[g])
        print(f"2000 chunk {i} done")
    save_panels(2000, finalize_panels(pieces))


def main() -> None:
    county_dict, cw1982_map, cw2000_map, treat_map = load_dicts()
    build_1982(county_dict, cw1982_map, treat_map)
    print("1982 done")
    build_1990(county_dict, cw1982_map, treat_map)
    print("1990 done")
    build_2000(cw2000_map, treat_map)
    print("2000 done")


if __name__ == "__main__":
    main()
