#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
SRC = PROJ / "data/raw/census/census1990.dta"
TREAT = PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta"
COUNTY_MAP = PROJ / "data/raw/China_Map/County0010.xlsx"
CW1982 = PROJ / "data/temp/countyid_1982_to_current_crosswalk_v2.csv"
OUT_DTA = PROJ / "data/temp/census1990_labor_micro_v2.dta"
OUT_CSV = PROJ / "data/temp/census1990_labor_micro_v2.csv"
AUDIT_CSV = PROJ / "data/temp/census1990_labor_build_audit_v2.csv"

MANUAL_SUCCESSOR = {
    310103: "310101",
    310108: "310106",
    310119: "310115",
    110010: "110110",
}


def load_maps() -> tuple[dict[int, str], dict[int, str]]:
    county = pd.read_excel(COUNTY_MAP, sheet_name="County0010", usecols=["GBCounty"])
    county["GBCounty"] = pd.to_numeric(county["GBCounty"], errors="coerce").astype("Int64")
    county = county.dropna().drop_duplicates()
    county_dict = {int(v): f"{int(v):06d}" for v in county["GBCounty"]}

    cw1982 = pd.read_csv(CW1982, dtype=str)
    cw1982["countyid_old6"] = pd.to_numeric(cw1982["countyid_old6"], errors="coerce").astype("Int64")
    cw1982["countyid_curr6_final"] = pd.to_numeric(cw1982["countyid_curr6_final"], errors="coerce").astype("Int64")
    cw1982 = cw1982.dropna(subset=["countyid_old6", "countyid_curr6_final"])
    cw1982_map = {
        int(old): f"{int(curr):06d}"
        for old, curr in cw1982[["countyid_old6", "countyid_curr6_final"]].drop_duplicates("countyid_old6").itertuples(index=False)
    }
    return county_dict, cw1982_map


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


def main() -> None:
    county_dict, cw1982_map = load_maps()
    treat = pd.read_stata(TREAT, convert_categoricals=False)
    treat["countyid_curr6"] = pd.to_numeric(treat["countyid_curr6"], errors="coerce").astype("Int64")
    treat = treat.dropna(subset=["countyid_curr6", "ln_martyr_per100k_1953"]).copy()
    treat["countyid_curr6"] = treat["countyid_curr6"].astype(int).map(lambda x: f"{x:06d}")
    tmap = dict(zip(treat["countyid_curr6"], treat["ln_martyr_per100k_1953"]))

    pieces: list[pd.DataFrame] = []
    audit_rows: list[dict[str, float]] = []
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(SRC),
        chunksize=1_000_000,
        usecols=["county", "age_c", "age", "sex", "race", "regstatu", "industry", "occu", "unemp_st"],
    )
    for i, (chunk, _) in enumerate(reader, start=1):
        raw_n = len(chunk)
        chunk["countyid_curr6"] = resolve_old_codes(chunk["county"], county_dict, cw1982_map)
        age_c = pd.to_numeric(chunk["age_c"], errors="coerce")
        age = pd.to_numeric(chunk["age"], errors="coerce")
        chunk["birth_i"] = 1000 + age_c * 100 + age
        chunk = chunk[chunk["birth_i"].between(1920, 1968) & (chunk["birth_i"] != 1939)].copy()
        chunk["ln_martyr_per100k_1953"] = chunk["countyid_curr6"].map(tmap)
        chunk = chunk[chunk["ln_martyr_per100k_1953"].notna()].copy()

        sex = pd.to_numeric(chunk["sex"], errors="coerce")
        race = pd.to_numeric(chunk["race"], errors="coerce")
        reg = pd.to_numeric(chunk["regstatu"], errors="coerce")
        occ = pd.to_numeric(chunk["occu"], errors="coerce")
        unemp = pd.to_numeric(chunk["unemp_st"], errors="coerce")

        chunk["post"] = (chunk["birth_i"] >= 1940).astype(float)
        chunk["male"] = np.where(sex.isin([1, 2]), (sex == 1).astype(float), np.nan)
        chunk["minority"] = np.where(race.notna(), (race != 1).astype(float), np.nan)
        chunk["rural"] = np.where(reg.isin([1, 2, 3, 4, 5]), (reg == 1).astype(float), np.nan)

        employed = occ.gt(0)
        in_labor_force = employed | unemp.eq(5)
        chunk["employed"] = np.where(occ.notna(), employed.astype(float), np.nan)
        chunk["in_labor_force"] = np.where(unemp.notna() | occ.notna(), in_labor_force.astype(float), np.nan)
        chunk["white_collar"] = np.where(employed, occ.between(11, 399).astype(float), np.nan)
        chunk["manual"] = np.where(employed, occ.between(601, 999).astype(float), np.nan)
        chunk["nonagri"] = np.where(employed, (~occ.between(401, 599)).astype(float), np.nan)

        keep = [
            "countyid_curr6",
            "birth_i",
            "post",
            "male",
            "minority",
            "rural",
            "ln_martyr_per100k_1953",
            "in_labor_force",
            "employed",
            "white_collar",
            "manual",
            "nonagri",
        ]
        pieces.append(chunk[keep].copy())
        audit_rows.append(
            {
                "chunk": i,
                "raw_n": raw_n,
                "kept_n": len(chunk),
                "mapped_share": float(chunk["countyid_curr6"].notna().mean()) if len(chunk) else np.nan,
                "post_zero_n": int((chunk["post"] == 0).sum()),
                "post_one_n": int((chunk["post"] == 1).sum()),
            }
        )
        print(f"chunk {i} done: raw={raw_n}, kept={len(chunk)}")

    out = pd.concat(pieces, ignore_index=True)
    out["birth_i"] = out["birth_i"].astype(int)
    audit = pd.DataFrame(audit_rows)
    OUT_DTA.parent.mkdir(parents=True, exist_ok=True)
    out.to_stata(OUT_DTA, write_index=False, version=118)
    out.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")
    audit.to_csv(AUDIT_CSV, index=False, encoding="utf-8-sig")


if __name__ == "__main__":
    main()
