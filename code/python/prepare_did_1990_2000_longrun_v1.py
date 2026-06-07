#!/usr/bin/env python3
"""Build long-run DID panels from 1990/2000 census files.

Design notes:
- 2000 has county-like 6-digit `uid`; mapped to current county codes.
- 1990 file has prefecture-level `geo2_cn1990` (5-digit), not county-level.
- Treatment intensity is native-place martyr counts (1931-1945), with:
  1) ln(1 + martyr_count)
  2) ln(1 + martyr_count / pop82_total * 100000)
  3) ln(1 + martyr_count / pop82_prewar * 100000)
  where pop82_* are county baselines from the 1982 panel.
"""

from __future__ import annotations

import math
import re
from collections import Counter
from pathlib import Path

import pandas as pd


BASE = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
)


def parse_code6_from_place_id(val: object) -> str:
    if pd.isna(val):
        return ""
    s = str(val).strip()
    m = re.match(r"^(\d{6})", s)
    if m:
        return m.group(1)
    digits = re.sub(r"\D", "", s)
    if len(digits) >= 6:
        return digits[:6]
    return ""


def county6_to_pref5_1990(county6: str) -> str:
    if not county6 or len(county6) != 6 or not county6.isdigit():
        return ""
    prov = int(county6[:2])
    pref2 = int(county6[2:4])
    # Municipalities in 1990 coding are xxx00 at prefecture level.
    if prov in {11, 12, 31}:
        return f"{prov:02d}000"
    # 5-digit convention in GEO2_CN1990: prov(2) + pref(3)
    return f"{prov:02d}{pref2:03d}"


def municipality_old_to_new(old6: str) -> str:
    if len(old6) != 6 or old6[:2] not in {"11", "12", "31"} or old6[2:4] != "00":
        return old6
    return f"{old6[:2]}01{old6[4:6]}"


def build_treatment_maps() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    martyr_path = BASE / "data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts_clean_county_fallback.csv"
    pop_path = BASE / "data/temp/did_1982_county_birthyr_martyr_hybrid_v3.dta"

    m = pd.read_csv(martyr_path)
    m["county6"] = m["place_id"].map(parse_code6_from_place_id)
    m = m[m["county6"] != ""].copy()
    m["martyr_count"] = pd.to_numeric(m["martyr_count"], errors="coerce").fillna(0.0)
    m = m.groupby("county6", as_index=False)["martyr_count"].sum()

    p = pd.read_stata(pop_path, convert_categoricals=False, columns=["countyid_curr6", "birthyr", "wt_sum"])
    p["county6"] = p["countyid_curr6"].astype(str).str.zfill(6)
    p["birthyr"] = pd.to_numeric(p["birthyr"], errors="coerce")
    p["wt_sum"] = pd.to_numeric(p["wt_sum"], errors="coerce").fillna(0.0)
    p = p.dropna(subset=["birthyr"])
    pop_total = p.groupby("county6", as_index=False)["wt_sum"].sum().rename(columns={"wt_sum": "pop82_total"})
    pop_prewar = (
        p[p["birthyr"] <= 1930]
        .groupby("county6", as_index=False)["wt_sum"]
        .sum()
        .rename(columns={"wt_sum": "pop82_prewar"})
    )
    pop = pop_total.merge(pop_prewar, on="county6", how="left")
    pop["pop82_prewar"] = pop["pop82_prewar"].fillna(0.0)

    c = m.merge(pop, on="county6", how="left")
    c["pop82_total"] = c["pop82_total"].fillna(0.0)
    c["pop82_prewar"] = c["pop82_prewar"].fillna(0.0)

    c["ln_martyr_native"] = c["martyr_count"].map(lambda x: math.log1p(x))
    c["martyr_per100k_pop82"] = c.apply(
        lambda r: (r["martyr_count"] / r["pop82_total"] * 100000.0) if r["pop82_total"] > 0 else math.nan,
        axis=1,
    )
    c["martyr_per100k_prewar82"] = c.apply(
        lambda r: (r["martyr_count"] / r["pop82_prewar"] * 100000.0) if r["pop82_prewar"] > 0 else math.nan,
        axis=1,
    )
    c["ln_martyr_per100k_pop82"] = c["martyr_per100k_pop82"].map(lambda x: math.log1p(x) if pd.notna(x) else math.nan)
    c["ln_martyr_per100k_prewar82"] = c["martyr_per100k_prewar82"].map(
        lambda x: math.log1p(x) if pd.notna(x) else math.nan
    )

    c_out = c.rename(columns={"county6": "geoid"})

    ptmp = c.copy()
    ptmp["pref5"] = ptmp["county6"].map(county6_to_pref5_1990)
    ptmp = ptmp[ptmp["pref5"] != ""].copy()

    # Keep denominator additivity in levels, then transform.
    p_agg = (
        ptmp.groupby("pref5", as_index=False)
        .agg(
            martyr_count=("martyr_count", "sum"),
            pop82_total=("pop82_total", "sum"),
            pop82_prewar=("pop82_prewar", "sum"),
        )
        .copy()
    )
    p_agg["ln_martyr_native"] = p_agg["martyr_count"].map(lambda x: math.log1p(x))
    p_agg["martyr_per100k_pop82"] = p_agg.apply(
        lambda r: (r["martyr_count"] / r["pop82_total"] * 100000.0) if r["pop82_total"] > 0 else math.nan,
        axis=1,
    )
    p_agg["martyr_per100k_prewar82"] = p_agg.apply(
        lambda r: (r["martyr_count"] / r["pop82_prewar"] * 100000.0) if r["pop82_prewar"] > 0 else math.nan,
        axis=1,
    )
    p_agg["ln_martyr_per100k_pop82"] = p_agg["martyr_per100k_pop82"].map(
        lambda x: math.log1p(x) if pd.notna(x) else math.nan
    )
    p_agg["ln_martyr_per100k_prewar82"] = p_agg["martyr_per100k_prewar82"].map(
        lambda x: math.log1p(x) if pd.notna(x) else math.nan
    )
    p_out = p_agg.rename(columns={"pref5": "geoid"})
    return c_out, p_out, pop, m


def build_2000_resolver() -> tuple[set[str], dict[str, str]]:
    county_map_path = BASE / "data/raw/China_Map/County0010.xlsx"
    cur = pd.read_excel(
        county_map_path,
        sheet_name="County0010",
        usecols=["GBCounty"],
    )
    cur["GBCounty"] = pd.to_numeric(cur["GBCounty"], errors="coerce")
    cur = cur.dropna(subset=["GBCounty"]).copy()
    cur_codes = set(cur["GBCounty"].astype(int).astype(str).str.zfill(6).tolist())

    manual_code_successor = {
        "310103": "310101",
        "310108": "310106",
        "310119": "310115",
        "110010": "110110",
    }

    return cur_codes, manual_code_successor


def add_postwar_windows(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["postwar_birth_wide"] = ((out["birthyr"] >= 1946) & (out["birthyr"] <= 1960)).astype(int)
    out["sample_postwar_birth_wide"] = ((out["birthyr"] >= 1931) & (out["birthyr"] <= 1960)).astype(int)
    out["postwar_schentry_wide"] = ((out["birthyr"] >= 1943) & (out["birthyr"] <= 1960)).astype(int)
    out["sample_postwar_schentry_wide"] = ((out["birthyr"] >= 1928) & (out["birthyr"] <= 1960)).astype(int)
    return out


def prepare_panel_2000(treat_county: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    cur_codes, manual_code_successor = build_2000_resolver()

    def resolve(old6: str) -> tuple[str, str]:
        if old6 in manual_code_successor:
            return manual_code_successor[old6], "manual_successor"
        if old6 in cur_codes:
            return old6, "exact_code"
        muni = municipality_old_to_new(old6)
        if muni != old6 and muni in manual_code_successor:
            return manual_code_successor[muni], "municipality_then_successor"
        if muni != old6 and muni in cur_codes:
            return muni, "municipality_geo3_recode"
        return "", "unmatched"

    use_cols = ["uid", "birthyr", "eduyr"]
    parts = []
    code_cache: dict[str, str] = {}
    code_route: dict[str, str] = {}
    route_counter: Counter[str] = Counter()
    for ch in pd.read_stata(
        BASE / "data/raw/census/census2000.dta",
        convert_categoricals=False,
        columns=use_cols,
        chunksize=350000,
    ):
        ch = ch.dropna(subset=["uid", "birthyr", "eduyr"]).copy()
        ch["birthyr"] = pd.to_numeric(ch["birthyr"], errors="coerce")
        ch["eduyr"] = pd.to_numeric(ch["eduyr"], errors="coerce")
        ch = ch[(ch["birthyr"] >= 1900) & (ch["birthyr"] <= 1965)]
        ch = ch[(ch["eduyr"] >= 0) & (ch["eduyr"] <= 25)]
        if ch.empty:
            continue
        ch["countyid_2000_old6"] = ch["uid"].astype(int).astype(str).str.zfill(6)
        seen_codes = ch["countyid_2000_old6"].drop_duplicates().tolist()
        for old6 in seen_codes:
            if old6 not in code_cache:
                new6, route = resolve(old6)
                code_cache[old6] = new6
                code_route[old6] = route
                route_counter[route] += 1
        ch["countyid_curr6"] = ch["countyid_2000_old6"].map(code_cache)
        ch = ch[ch["countyid_curr6"] != ""].copy()
        if ch.empty:
            continue
        ch["wt"] = 1.0
        ch["eduy_w"] = ch["eduyr"] * ch["wt"]
        g = (
            ch.groupby(["countyid_curr6", "birthyr"], as_index=False)
            .agg(n_obs=("eduyr", "size"), wt_sum=("wt", "sum"), eduy_wsum=("eduy_w", "sum"))
            .copy()
        )
        parts.append(g)

    if not parts:
        raise RuntimeError("No valid rows from census2000.dta after cleaning.")

    panel = (
        pd.concat(parts, ignore_index=True)
        .groupby(["countyid_curr6", "birthyr"], as_index=False)
        .agg(n_obs=("n_obs", "sum"), wt_sum=("wt_sum", "sum"), eduy_wsum=("eduy_wsum", "sum"))
    )
    panel = (
        panel.groupby(["countyid_curr6", "birthyr"], as_index=False)
        .agg(n_obs=("n_obs", "sum"), wt_sum=("wt_sum", "sum"), eduy_wsum=("eduy_wsum", "sum"))
        .rename(columns={"countyid_curr6": "geoid"})
    )
    panel["eduy_wmean"] = panel["eduy_wsum"] / panel["wt_sum"]

    t = treat_county.copy()
    t["geoid"] = t["geoid"].astype(str).str.zfill(6)
    panel = panel.merge(
        t[
            [
                "geoid",
                "martyr_count",
                "ln_martyr_native",
                "martyr_per100k_pop82",
                "ln_martyr_per100k_pop82",
                "martyr_per100k_prewar82",
                "ln_martyr_per100k_prewar82",
            ]
        ],
        on="geoid",
        how="left",
    )
    panel["martyr_count"] = panel["martyr_count"].fillna(0.0)
    panel["ln_martyr_native"] = panel["ln_martyr_native"].fillna(0.0)
    panel = add_postwar_windows(panel)
    panel = panel.sort_values(["geoid", "birthyr"]).reset_index(drop=True)
    map_rows = []
    for old6 in sorted(code_cache.keys()):
        map_rows.append(
            {
                "countyid_2000_old6": old6,
                "countyid_curr6": code_cache[old6],
                "route": code_route[old6],
                "n_old_codes": route_counter[code_route[old6]],
            }
        )
    map_df = pd.DataFrame(map_rows)
    unresolved = map_df[map_df["route"] == "unmatched"][["countyid_2000_old6"]].drop_duplicates().copy()
    return panel, unresolved, map_df


def prepare_panel_1990(treat_pref: pd.DataFrame) -> pd.DataFrame:
    use_cols = ["geo2_cn1990", "birthyr", "perwt", "edattaind", "educcn"]

    # EDATTAIND-first mapping (more structured), fallback to EDUCCN.
    map_edattaind = {
        100: 2.0,
        110: 0.0,
        120: 3.0,
        130: 4.0,
        211: 5.0,
        212: 6.0,
        221: 9.0,
        222: 9.0,
        311: 12.0,
        320: 12.0,
        321: 12.0,
        312: 14.0,
        322: 14.0,
        400: 16.0,
    }
    map_educcn = {
        0: 0.0,
        10: 3.0,
        11: 3.0,
        12: 3.0,
        13: 6.0,
        19: 4.0,
        20: 8.0,
        21: 8.0,
        22: 8.0,
        23: 9.0,
        24: 8.0,
        29: 8.0,
        30: 11.0,
        31: 11.0,
        32: 11.0,
        33: 12.0,
        34: 11.0,
        35: 11.0,
        36: 11.0,
        37: 12.0,
        38: 11.0,
        39: 11.0,
        40: 14.0,
        41: 13.0,
        42: 13.0,
        43: 14.0,
        44: 14.0,
        50: 16.0,
        51: 15.0,
        52: 16.0,
        58: 14.0,
        60: 14.0,
        61: 13.0,
        62: 14.0,
    }

    parts = []
    for ch in pd.read_stata(
        BASE / "data/raw/census/Census1990#11835947.dta",
        convert_categoricals=False,
        columns=use_cols,
        chunksize=350000,
    ):
        ch = ch.dropna(subset=["geo2_cn1990", "birthyr", "perwt"]).copy()
        ch["birthyr"] = pd.to_numeric(ch["birthyr"], errors="coerce")
        ch["perwt"] = pd.to_numeric(ch["perwt"], errors="coerce")
        ch = ch[(ch["birthyr"] >= 1900) & (ch["birthyr"] <= 1965)]
        ch = ch[ch["perwt"] > 0]
        if ch.empty:
            continue

        ch["eduy"] = pd.to_numeric(ch["edattaind"], errors="coerce").map(map_edattaind)
        miss = ch["eduy"].isna()
        ch.loc[miss, "eduy"] = pd.to_numeric(ch.loc[miss, "educcn"], errors="coerce").map(map_educcn)
        ch = ch.dropna(subset=["eduy"])
        ch = ch[(ch["eduy"] >= 0) & (ch["eduy"] <= 25)]
        if ch.empty:
            continue

        ch["geoid"] = ch["geo2_cn1990"].astype(int).astype(str).str.zfill(5)
        ch["eduy_w"] = ch["eduy"] * ch["perwt"]
        g = (
            ch.groupby(["geoid", "birthyr"], as_index=False)
            .agg(n_obs=("eduy", "size"), wt_sum=("perwt", "sum"), eduy_wsum=("eduy_w", "sum"))
            .copy()
        )
        parts.append(g)

    if not parts:
        raise RuntimeError("No valid rows from Census1990#11835947.dta after cleaning.")

    panel = (
        pd.concat(parts, ignore_index=True)
        .groupby(["geoid", "birthyr"], as_index=False)
        .agg(n_obs=("n_obs", "sum"), wt_sum=("wt_sum", "sum"), eduy_wsum=("eduy_wsum", "sum"))
    )
    panel["eduy_wmean"] = panel["eduy_wsum"] / panel["wt_sum"]

    t = treat_pref.copy()
    t["geoid"] = t["geoid"].astype(str).str.zfill(5)
    panel = panel.merge(
        t[
            [
                "geoid",
                "martyr_count",
                "ln_martyr_native",
                "martyr_per100k_pop82",
                "ln_martyr_per100k_pop82",
                "martyr_per100k_prewar82",
                "ln_martyr_per100k_prewar82",
            ]
        ],
        on="geoid",
        how="left",
    )
    panel["martyr_count"] = panel["martyr_count"].fillna(0.0)
    panel["ln_martyr_native"] = panel["ln_martyr_native"].fillna(0.0)
    panel = add_postwar_windows(panel)
    panel = panel.sort_values(["geoid", "birthyr"]).reset_index(drop=True)
    return panel


def main() -> None:
    outdir = BASE / "data/temp"
    outdir.mkdir(parents=True, exist_ok=True)

    treat_county, treat_pref, _, _ = build_treatment_maps()
    panel2000, unresolved2000, route_df = prepare_panel_2000(treat_county=treat_county)
    panel1990 = prepare_panel_1990(treat_pref=treat_pref)

    p2000_csv = outdir / "did_2000_county_birthyr_martyr_longrun_v1.csv"
    p2000_dta = outdir / "did_2000_county_birthyr_martyr_longrun_v1.dta"
    p1990_csv = outdir / "did_1990_pref_birthyr_martyr_longrun_v1.csv"
    p1990_dta = outdir / "did_1990_pref_birthyr_martyr_longrun_v1.dta"

    panel2000.to_csv(p2000_csv, index=False)
    panel2000.to_stata(p2000_dta, write_index=False, version=118)
    panel1990.to_csv(p1990_csv, index=False)
    panel1990.to_stata(p1990_dta, write_index=False, version=118)

    route_out = outdir / "countyid_2000_to_current_routes_v1.csv"
    unresolved_out = outdir / "countyid_2000_to_current_unmatched_v1.csv"
    route_df.to_csv(route_out, index=False)
    unresolved2000.to_csv(unresolved_out, index=False)

    print(f"1990 rows={len(panel1990)} geoid_n={panel1990['geoid'].nunique()}")
    print(f"2000 rows={len(panel2000)} geoid_n={panel2000['geoid'].nunique()}")
    print(f"2000 unmatched old codes={len(unresolved2000)}")
    print(f"out: {p1990_dta}")
    print(f"out: {p2000_dta}")
    print(f"out: {route_out}")
    print(f"out: {unresolved_out}")


if __name__ == "__main__":
    main()
