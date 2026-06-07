#!/usr/bin/env python3
"""Prepare county-birthyear DID panel from 1982 census and martyr native intensity.

Inputs
- data/temp/census_1982_cleaned.dta
- data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts_merge_ready.csv
- data/raw/China_Map/County0010.xlsx

Outputs
- data/temp/did_1982_county_birthyr_martyr_native.csv
- data/temp/did_1982_county_birthyr_martyr_native.dta
- data/temp/did_1982_county_code_harmonization_summary.csv
"""

from __future__ import annotations

import math
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, Tuple

import pandas as pd


def code6(value) -> str:
    try:
        iv = int(value)
    except Exception:
        return ""
    if iv <= 0:
        return ""
    return f"{iv:06d}"


def municipality_old_to_new(c: str) -> str:
    # Old direct-admin coding often appears as 1100xx/1200xx/3100xx in 1982 files.
    if len(c) != 6 or c[:2] not in {"11", "12", "31"} or c[2:4] != "00":
        return c
    xx = int(c[4:6])
    cityblock = "2" if xx >= 21 else "1"
    return f"{c[:2]}{cityblock}{c[4:6]}"


def build_harmonize_func(valid_counties: set[str]):
    # Deterministic merge map for major county-level mergers into current districts.
    manual_merge = {
        # Beijing: Chongwen -> Dongcheng, Xuanwu -> Xicheng
        "110103": "110101",
        "110104": "110102",
        # Shanghai: Luwan -> Huangpu, Zhabei -> Jing'an, Nanhui -> Pudong
        "310103": "310101",
        "310108": "310106",
        "310119": "310115",
    }

    def harmonize(c_raw: str) -> Tuple[str, str]:
        if not c_raw:
            return "", "missing"

        c1 = municipality_old_to_new(c_raw)
        if c1 != c_raw:
            c_raw = c1

        c2 = manual_merge.get(c_raw, c_raw)
        route = "manual_merge" if c2 != c_raw else "identity_or_old"

        if c2 in valid_counties:
            return c2, route + "_in_2010map"
        return c2, route + "_not_in_2010map"

    return harmonize


def main() -> None:
    base = Path(
        "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
    )
    census_path = base / "data/temp/census_1982_cleaned.dta"
    martyr_path = (
        base / "data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts_merge_ready.csv"
    )
    county_map_path = base / "data/raw/China_Map/County0010.xlsx"

    out_csv = base / "data/temp/did_1982_county_birthyr_martyr_native.csv"
    out_dta = base / "data/temp/did_1982_county_birthyr_martyr_native.dta"
    out_harmonize = base / "data/temp/did_1982_county_code_harmonization_summary.csv"

    # Valid county codes from County0010 map (2010-era admin layout).
    county_map = pd.read_excel(county_map_path, sheet_name="County0010", usecols=["GBCounty", "County_CH"])
    county_map["countyid_curr6"] = county_map["GBCounty"].astype(str).str.zfill(6)
    valid_counties = set(county_map["countyid_curr6"].tolist())

    # Martyr native-place intensity by 6-digit county code.
    m = pd.read_csv(martyr_path, dtype={"merge_place_id": str})
    m = m[m["merge_place_id"].str.fullmatch(r"\d{12}", na=False)].copy()
    m["countyid_curr6"] = m["merge_place_id"].str[:6]
    m = (
        m.groupby("countyid_curr6", as_index=False)["martyr_count"]
        .sum()
        .rename(columns={"martyr_count": "martyr_native_count_1931_1945"})
    )
    martyr_map = dict(zip(m["countyid_curr6"], m["martyr_native_count_1931_1945"]))

    harmonize = build_harmonize_func(valid_counties)
    harm_counter = Counter()

    # Aggregate in chunks: county x birthyr cells.
    # store: [n_obs, wt_sum, eduy_wsum]
    agg = defaultdict(lambda: [0, 0.0, 0.0])
    use_cols = ["countyid", "birthyr", "eduy", "perwt"]

    for chunk in pd.read_stata(census_path, convert_categoricals=False, chunksize=250000, columns=use_cols):
        # basic cleaning
        chunk = chunk.dropna(subset=["countyid", "birthyr", "eduy", "perwt"])
        if chunk.empty:
            continue

        # conservative filter to meaningful cohorts for this DID setup
        chunk = chunk[(chunk["birthyr"] >= 1900) & (chunk["birthyr"] <= 1965)]
        chunk = chunk[(chunk["eduy"] >= 0) & (chunk["eduy"] <= 25)]
        chunk = chunk[chunk["perwt"] > 0]
        if chunk.empty:
            continue

        for row in chunk.itertuples(index=False):
            raw_code = code6(row.countyid)
            curr_code, route = harmonize(raw_code)
            harm_counter[route] += 1
            if not curr_code:
                continue

            birthyr = int(row.birthyr)
            wt = float(row.perwt)
            eduy = float(row.eduy)
            key = (curr_code, birthyr)
            agg[key][0] += 1
            agg[key][1] += wt
            agg[key][2] += wt * eduy

    rows = []
    for (countyid_curr6, birthyr), (n_obs, wt_sum, eduy_wsum) in agg.items():
        martyr_count = float(martyr_map.get(countyid_curr6, 0.0))
        ln_martyr = math.log1p(martyr_count)
        eduy_wmean = eduy_wsum / wt_sum if wt_sum > 0 else float("nan")

        # cohort designs
        wartime_birth = 1 if 1931 <= birthyr <= 1945 else 0
        postwar_birth = 1 if 1946 <= birthyr <= 1955 else 0
        schoolage_war = 1 if 1926 <= birthyr <= 1937 else 0  # recommended baseline

        # sample windows for convenience
        sample_schoolage_did = 1 if 1915 <= birthyr <= 1937 else 0
        sample_wartime_vs_post = 1 if 1931 <= birthyr <= 1955 else 0

        rows.append(
            {
                "countyid_curr6": countyid_curr6,
                "birthyr": birthyr,
                "n_obs": n_obs,
                "wt_sum": wt_sum,
                "eduy_wmean": eduy_wmean,
                "martyr_native_count_1931_1945": martyr_count,
                "ln_martyr_native_count": ln_martyr,
                "wartime_birth": wartime_birth,
                "postwar_birth": postwar_birth,
                "schoolage_war": schoolage_war,
                "sample_schoolage_did": sample_schoolage_did,
                "sample_wartime_vs_post": sample_wartime_vs_post,
                "did_schoolage_interaction": ln_martyr * schoolage_war,
                "did_wartimebirth_interaction": ln_martyr * wartime_birth,
                "did_postwar_interaction": ln_martyr * postwar_birth,
            }
        )

    out = pd.DataFrame(rows).sort_values(["countyid_curr6", "birthyr"])
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(out_csv, index=False)
    out.to_stata(out_dta, write_index=False, version=118)

    harm_df = pd.DataFrame(
        [{"route": k, "row_count": v} for k, v in sorted(harm_counter.items(), key=lambda x: x[1], reverse=True)]
    )
    harm_df.to_csv(out_harmonize, index=False)

    print(f"panel_rows={len(out)}")
    print(f"county_n={out['countyid_curr6'].nunique()}")
    print(f"birthyr_min={out['birthyr'].min()} birthyr_max={out['birthyr'].max()}")
    print(f"output_csv={out_csv}")
    print(f"output_dta={out_dta}")
    print(f"harmonize_summary={out_harmonize}")


if __name__ == "__main__":
    main()

