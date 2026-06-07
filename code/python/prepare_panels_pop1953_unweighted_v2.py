#!/usr/bin/env python3
"""Prepare 1982/1990/2000 county-birthyear panels (unweighted, pop1953 denominator)."""

from __future__ import annotations

import math
import re
from collections import Counter
from pathlib import Path

import pandas as pd


BASE = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
)


def municipality_old_to_new(old6: str) -> str:
    if len(old6) != 6 or old6[:2] not in {"11", "12", "31"} or old6[2:4] != "00":
        return old6
    return f"{old6[:2]}01{old6[4:6]}"


def parse_code6(val: object) -> str:
    if pd.isna(val):
        return ""
    s = str(val).strip()
    m = re.match(r"^(\d{6})", s)
    if m:
        return m.group(1)
    digits = re.sub(r"\D", "", s)
    return digits[:6] if len(digits) >= 6 else ""


def load_current_county_codes() -> set[str]:
    p = BASE / "data/raw/China_Map/County0010.xlsx"
    cur = pd.read_excel(p, sheet_name="County0010", usecols=["GBCounty"])
    cur["GBCounty"] = pd.to_numeric(cur["GBCounty"], errors="coerce")
    cur = cur.dropna(subset=["GBCounty"])
    return set(cur["GBCounty"].astype(int).astype(str).str.zfill(6).tolist())


def load_crosswalk_1982() -> tuple[dict[str, str], dict[str, str]]:
    p = BASE / "data/temp/countyid_1982_to_current_crosswalk_v2.csv"
    cw = pd.read_csv(p, dtype=str)
    cw = cw.rename(columns={"countyid_old6": "old6", "countyid_curr6_final": "curr6"})
    cw["old6"] = cw["old6"].fillna("").str.zfill(6)
    cw["curr6"] = cw["curr6"].fillna("").str.replace(r"\.0$", "", regex=True).str.zfill(6)
    cw = cw[(cw["old6"] != "") & (cw["curr6"] != "")]
    map_old_to_curr = dict(zip(cw["old6"], cw["curr6"]))
    map_old_to_route = dict(zip(cw["old6"], cw.get("route_final", pd.Series([""] * len(cw)))))
    return map_old_to_curr, map_old_to_route


def build_code_resolver(
    curr_codes: set[str], cw_map: dict[str, str]
) -> tuple[dict[str, str], dict[str, str], Counter]:
    manual_code_successor = {
        "310103": "310101",
        "310108": "310106",
        "310119": "310115",
        "110010": "110110",
    }
    cache_map: dict[str, str] = {}
    cache_route: dict[str, str] = {}
    route_counter: Counter[str] = Counter()

    def resolve(code6: str) -> tuple[str, str]:
        if code6 in manual_code_successor:
            return manual_code_successor[code6], "manual_successor"
        if code6 in curr_codes:
            return code6, "exact_code"
        if code6 in cw_map:
            return cw_map[code6], "crosswalk_1982"
        muni = municipality_old_to_new(code6)
        if muni in manual_code_successor:
            return manual_code_successor[muni], "municipality_then_successor"
        if muni in curr_codes:
            return muni, "municipality_geo3_recode"
        if muni in cw_map:
            return cw_map[muni], "municipality_then_crosswalk_1982"
        return "", "unmatched"

    def resolve_many(codes: list[str]) -> None:
        for c in codes:
            if c not in cache_map:
                m, r = resolve(c)
                cache_map[c] = m
                cache_route[c] = r
                route_counter[r] += 1

    # attach method as attribute for convenience
    resolve_many.codes_cache = cache_map  # type: ignore[attr-defined]
    resolve_many.route_cache = cache_route  # type: ignore[attr-defined]
    resolve_many.route_counter = route_counter  # type: ignore[attr-defined]
    return cache_map, cache_route, route_counter


def build_martyr_map(
    curr_codes: set[str], cw_map: dict[str, str]
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    p = BASE / "data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts_clean_county_fallback.csv"
    df = pd.read_csv(p)
    df["old6"] = df["place_id"].map(parse_code6)
    df["martyr_count"] = pd.to_numeric(df["martyr_count"], errors="coerce").fillna(0.0)
    df = df[df["old6"] != ""].copy()

    cache_map, cache_route, route_counter = build_code_resolver(curr_codes, cw_map)
    uniq = df["old6"].drop_duplicates().tolist()
    for c in uniq:
        if c not in cache_map:
            # resolve
            if c in {"310103", "310108", "310119", "110010"}:
                pass
        # use helper via direct logic
    # reuse by calling a tiny loop with resolver logic from build_code_resolver
    # (inline for speed and clarity)
    manual_code_successor = {"310103": "310101", "310108": "310106", "310119": "310115", "110010": "110110"}
    for c in uniq:
        if c in cache_map:
            continue
        if c in manual_code_successor:
            m, r = manual_code_successor[c], "manual_successor"
        elif c in curr_codes:
            m, r = c, "exact_code"
        elif c in cw_map:
            m, r = cw_map[c], "crosswalk_1982"
        else:
            muni = municipality_old_to_new(c)
            if muni in manual_code_successor:
                m, r = manual_code_successor[muni], "municipality_then_successor"
            elif muni in curr_codes:
                m, r = muni, "municipality_geo3_recode"
            elif muni in cw_map:
                m, r = cw_map[muni], "municipality_then_crosswalk_1982"
            else:
                m, r = "", "unmatched"
        cache_map[c] = m
        cache_route[c] = r
        route_counter[r] += 1

    df["countyid_curr6"] = df["old6"].map(cache_map)
    df["route"] = df["old6"].map(cache_route)
    unresolved = (
        df[df["countyid_curr6"] == ""][["old6", "route"]]
        .drop_duplicates()
        .rename(columns={"old6": "code6"})
        .sort_values(["route", "code6"])
    )
    route_df = (
        pd.DataFrame({"route": list(route_counter.keys()), "n_codes": list(route_counter.values())})
        .sort_values(["n_codes", "route"], ascending=[False, True])
        .reset_index(drop=True)
    )
    out = (
        df[df["countyid_curr6"] != ""]
        .groupby("countyid_curr6", as_index=False)["martyr_count"]
        .sum()
        .rename(columns={"martyr_count": "martyr_count_1931_1945"})
    )
    return out, route_df, unresolved


def build_pop1953_map(
    curr_codes: set[str], cw_map: dict[str, str]
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    p = BASE / "data/raw/census/1953年县级人口数量.dta"
    df = pd.read_stata(p, convert_categoricals=False)
    df["old6"] = df["county_code"].map(parse_code6)
    df["pop_1953"] = pd.to_numeric(df["pop_1953"], errors="coerce")
    df = df[(df["old6"] != "") & df["pop_1953"].notna() & (df["pop_1953"] > 0)].copy()

    cache_map, cache_route, route_counter = build_code_resolver(curr_codes, cw_map)
    uniq = df["old6"].drop_duplicates().tolist()
    manual_code_successor = {"310103": "310101", "310108": "310106", "310119": "310115", "110010": "110110"}
    for c in uniq:
        if c in cache_map:
            continue
        if c in manual_code_successor:
            m, r = manual_code_successor[c], "manual_successor"
        elif c in curr_codes:
            m, r = c, "exact_code"
        elif c in cw_map:
            m, r = cw_map[c], "crosswalk_1982"
        else:
            muni = municipality_old_to_new(c)
            if muni in manual_code_successor:
                m, r = manual_code_successor[muni], "municipality_then_successor"
            elif muni in curr_codes:
                m, r = muni, "municipality_geo3_recode"
            elif muni in cw_map:
                m, r = cw_map[muni], "municipality_then_crosswalk_1982"
            else:
                m, r = "", "unmatched"
        cache_map[c] = m
        cache_route[c] = r
        route_counter[r] += 1

    df["countyid_curr6"] = df["old6"].map(cache_map)
    df["route"] = df["old6"].map(cache_route)
    unresolved = (
        df[df["countyid_curr6"] == ""][["old6", "route"]]
        .drop_duplicates()
        .rename(columns={"old6": "code6"})
        .sort_values(["route", "code6"])
    )
    route_df = (
        pd.DataFrame({"route": list(route_counter.keys()), "n_codes": list(route_counter.values())})
        .sort_values(["n_codes", "route"], ascending=[False, True])
        .reset_index(drop=True)
    )
    out = df[df["countyid_curr6"] != ""].groupby("countyid_curr6", as_index=False)["pop_1953"].sum()
    return out, route_df, unresolved


def build_treatment(pop: pd.DataFrame, martyr: pd.DataFrame) -> pd.DataFrame:
    t = pop.merge(martyr, on="countyid_curr6", how="outer")
    t["pop_1953"] = pd.to_numeric(t["pop_1953"], errors="coerce")
    t["martyr_count_1931_1945"] = pd.to_numeric(t["martyr_count_1931_1945"], errors="coerce").fillna(0.0)
    t["ln_martyr_raw"] = t["martyr_count_1931_1945"].map(lambda x: math.log1p(x))
    t["martyr_per100k_1953"] = t.apply(
        lambda r: (r["martyr_count_1931_1945"] / r["pop_1953"] * 100000.0)
        if pd.notna(r["pop_1953"]) and r["pop_1953"] > 0
        else math.nan,
        axis=1,
    )
    t["ln_martyr_per100k_1953"] = t["martyr_per100k_1953"].map(lambda x: math.log1p(x) if pd.notna(x) else math.nan)
    return t


def finalize_panel(df: pd.DataFrame, treatment: pd.DataFrame) -> pd.DataFrame:
    out = (
        df.groupby(["countyid_curr6", "birthyr"], as_index=False)
        .agg(n_obs=("eduy", "size"), eduy_sum=("eduy", "sum"))
        .copy()
    )
    out["eduy_mean"] = out["eduy_sum"] / out["n_obs"]
    out = out.merge(treatment, on="countyid_curr6", how="left")
    out = out.sort_values(["countyid_curr6", "birthyr"]).reset_index(drop=True)
    return out


def prepare_1982_unweighted(treatment: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    p = BASE / "data/temp/census_1982_cleaned.dta"
    cw = pd.read_csv(BASE / "data/temp/countyid_1982_to_current_crosswalk_v2.csv", dtype=str)
    cw["countyid_old6"] = cw["countyid_old6"].fillna("").str.zfill(6)
    cw["countyid_curr6_final"] = cw["countyid_curr6_final"].fillna("").str.replace(r"\.0$", "", regex=True).str.zfill(6)
    cw = cw[(cw["countyid_old6"] != "") & (cw["countyid_curr6_final"] != "")]
    map_old_curr = dict(zip(cw["countyid_old6"], cw["countyid_curr6_final"]))
    map_old_route = dict(zip(cw["countyid_old6"], cw["route_final"]))

    parts = []
    unmatched_codes = set()
    for ch in pd.read_stata(p, convert_categoricals=False, columns=["countyid", "birthyr", "eduy"], chunksize=400000):
        ch = ch.dropna(subset=["countyid", "birthyr", "eduy"]).copy()
        ch["birthyr"] = pd.to_numeric(ch["birthyr"], errors="coerce")
        ch["eduy"] = pd.to_numeric(ch["eduy"], errors="coerce")
        ch = ch[(ch["birthyr"] >= 1880) & (ch["birthyr"] <= 1982)]
        ch = ch[(ch["eduy"] >= 0) & (ch["eduy"] <= 25)]
        if ch.empty:
            continue
        ch["old6"] = ch["countyid"].astype(int).astype(str).str.zfill(6)
        ch["countyid_curr6"] = ch["old6"].map(map_old_curr)
        miss = ch["countyid_curr6"].isna()
        if miss.any():
            unmatched_codes.update(ch.loc[miss, "old6"].drop_duplicates().tolist())
        ch = ch[~miss].copy()
        ch["birthyr"] = ch["birthyr"].astype(int)
        parts.append(ch[["countyid_curr6", "birthyr", "eduy"]])

    if not parts:
        raise RuntimeError("No valid rows for 1982 after cleaning.")

    raw = pd.concat(parts, ignore_index=True)
    out = finalize_panel(raw, treatment)

    unmatched_df = pd.DataFrame({"old6": sorted(unmatched_codes)})
    if not unmatched_df.empty:
        unmatched_df["route"] = unmatched_df["old6"].map(map_old_route).fillna("unmatched")
    return out, unmatched_df


def prepare_1990_unweighted(treatment: pd.DataFrame, curr_codes: set[str], cw_map: dict[str, str]) -> tuple[pd.DataFrame, pd.DataFrame]:
    p = BASE / "data/raw/census/census1990.dta"
    parts = []

    # Assumption (from variable structure): `age` is the last two digits of birth year,
    # and `age_c` is century indicator (9->1900s, 8->1800s).
    educ_to_years = {
        1: 0.0,
        2: 6.0,
        3: 9.0,
        4: 12.0,
        5: 12.0,
        6: 15.0,
        7: 16.0,
    }

    cache_map, cache_route, route_counter = build_code_resolver(curr_codes, cw_map)
    manual_code_successor = {"310103": "310101", "310108": "310106", "310119": "310115", "110010": "110110"}

    for ch in pd.read_stata(
        p, convert_categoricals=False, columns=["county", "age_c", "age", "educ"], chunksize=400000
    ):
        ch = ch.dropna(subset=["county", "age_c", "age", "educ"]).copy()
        ch["county_old6"] = ch["county"].astype(int).astype(str).str.zfill(6)

        uniq = ch["county_old6"].drop_duplicates().tolist()
        for c in uniq:
            if c in cache_map:
                continue
            if c in manual_code_successor:
                m, r = manual_code_successor[c], "manual_successor"
            elif c in curr_codes:
                m, r = c, "exact_code"
            elif c in cw_map:
                m, r = cw_map[c], "crosswalk_1982"
            else:
                muni = municipality_old_to_new(c)
                if muni in manual_code_successor:
                    m, r = manual_code_successor[muni], "municipality_then_successor"
                elif muni in curr_codes:
                    m, r = muni, "municipality_geo3_recode"
                elif muni in cw_map:
                    m, r = cw_map[muni], "municipality_then_crosswalk_1982"
                else:
                    m, r = "", "unmatched"
            cache_map[c] = m
            cache_route[c] = r
            route_counter[r] += 1

        ch["countyid_curr6"] = ch["county_old6"].map(cache_map)
        ch = ch[ch["countyid_curr6"] != ""].copy()
        if ch.empty:
            continue

        ch["birthyr"] = 1000 + ch["age_c"].astype(int) * 100 + ch["age"].astype(int)
        ch["eduy"] = ch["educ"].astype(int).map(educ_to_years)
        ch = ch.dropna(subset=["birthyr", "eduy"]).copy()
        ch = ch[(ch["birthyr"] >= 1880) & (ch["birthyr"] <= 1990)]
        ch = ch[(ch["eduy"] >= 0) & (ch["eduy"] <= 25)]
        if ch.empty:
            continue
        ch["birthyr"] = ch["birthyr"].astype(int)
        parts.append(ch[["countyid_curr6", "birthyr", "eduy"]])

    if not parts:
        raise RuntimeError("No valid rows for new census1990 after cleaning.")

    raw = pd.concat(parts, ignore_index=True)
    out = finalize_panel(raw, treatment)

    route_df = (
        pd.DataFrame({"route": list(route_counter.keys()), "n_codes": list(route_counter.values())})
        .sort_values(["n_codes", "route"], ascending=[False, True])
        .reset_index(drop=True)
    )
    return out, route_df


def prepare_2000_unweighted(treatment: pd.DataFrame, curr_codes: set[str], cw_map: dict[str, str]) -> tuple[pd.DataFrame, pd.DataFrame]:
    p = BASE / "data/raw/census/census2000.dta"
    parts = []

    cache_map, cache_route, route_counter = build_code_resolver(curr_codes, cw_map)
    manual_code_successor = {"310103": "310101", "310108": "310106", "310119": "310115", "110010": "110110"}

    for ch in pd.read_stata(
        p, convert_categoricals=False, columns=["uid", "birthyr", "eduyr"], chunksize=400000
    ):
        ch = ch.dropna(subset=["uid", "birthyr", "eduyr"]).copy()
        ch["county_old6"] = ch["uid"].astype(int).astype(str).str.zfill(6)

        uniq = ch["county_old6"].drop_duplicates().tolist()
        for c in uniq:
            if c in cache_map:
                continue
            if c in manual_code_successor:
                m, r = manual_code_successor[c], "manual_successor"
            elif c in curr_codes:
                m, r = c, "exact_code"
            elif c in cw_map:
                m, r = cw_map[c], "crosswalk_1982"
            else:
                muni = municipality_old_to_new(c)
                if muni in manual_code_successor:
                    m, r = manual_code_successor[muni], "municipality_then_successor"
                elif muni in curr_codes:
                    m, r = muni, "municipality_geo3_recode"
                elif muni in cw_map:
                    m, r = cw_map[muni], "municipality_then_crosswalk_1982"
                else:
                    m, r = "", "unmatched"
            cache_map[c] = m
            cache_route[c] = r
            route_counter[r] += 1

        ch["countyid_curr6"] = ch["county_old6"].map(cache_map)
        ch = ch[ch["countyid_curr6"] != ""].copy()
        if ch.empty:
            continue

        ch["birthyr"] = pd.to_numeric(ch["birthyr"], errors="coerce")
        ch["eduy"] = pd.to_numeric(ch["eduyr"], errors="coerce")
        ch = ch.dropna(subset=["birthyr", "eduy"]).copy()
        ch = ch[(ch["birthyr"] >= 1880) & (ch["birthyr"] <= 2000)]
        ch = ch[(ch["eduy"] >= 0) & (ch["eduy"] <= 25)]
        if ch.empty:
            continue
        ch["birthyr"] = ch["birthyr"].astype(int)
        parts.append(ch[["countyid_curr6", "birthyr", "eduy"]])

    if not parts:
        raise RuntimeError("No valid rows for census2000 after cleaning.")

    raw = pd.concat(parts, ignore_index=True)
    out = finalize_panel(raw, treatment)

    route_df = (
        pd.DataFrame({"route": list(route_counter.keys()), "n_codes": list(route_counter.values())})
        .sort_values(["n_codes", "route"], ascending=[False, True])
        .reset_index(drop=True)
    )
    return out, route_df


def main() -> None:
    outdir = BASE / "data/temp"
    outdir.mkdir(parents=True, exist_ok=True)

    curr_codes = load_current_county_codes()
    cw_map, _ = load_crosswalk_1982()

    martyr_map, martyr_routes, martyr_unmatched = build_martyr_map(curr_codes, cw_map)
    pop_map, pop_routes, pop_unmatched = build_pop1953_map(curr_codes, cw_map)
    treatment = build_treatment(pop_map, martyr_map)

    p1982, u1982 = prepare_1982_unweighted(treatment)
    p1990, r1990 = prepare_1990_unweighted(treatment, curr_codes, cw_map)
    p2000, r2000 = prepare_2000_unweighted(treatment, curr_codes, cw_map)

    outputs = {
        "did_1982_county_birthyr_pop1953_unwt_v2": p1982,
        "did_1990_county_birthyr_pop1953_unwt_v2": p1990,
        "did_2000_county_birthyr_pop1953_unwt_v2": p2000,
    }
    for stub, df in outputs.items():
        df.to_csv(outdir / f"{stub}.csv", index=False)
        df.to_stata(outdir / f"{stub}.dta", write_index=False, version=118)

    treatment.to_csv(outdir / "martyr_pop1953_treatment_county_v2.csv", index=False)
    martyr_routes.to_csv(outdir / "martyr_code_routes_v2.csv", index=False)
    martyr_unmatched.to_csv(outdir / "martyr_code_unmatched_v2.csv", index=False)
    pop_routes.to_csv(outdir / "pop1953_code_routes_v2.csv", index=False)
    pop_unmatched.to_csv(outdir / "pop1953_code_unmatched_v2.csv", index=False)
    u1982.to_csv(outdir / "census1982_old6_unmatched_v2.csv", index=False)
    r1990.to_csv(outdir / "census1990_code_routes_v2.csv", index=False)
    r2000.to_csv(outdir / "census2000_code_routes_v2.csv", index=False)

    print("saved panels:")
    for stub, df in outputs.items():
        print(stub, "rows=", len(df), "counties=", df["countyid_curr6"].nunique())
    print("treatment counties:", treatment["countyid_curr6"].nunique())
    print("martyr unmatched:", len(martyr_unmatched), "pop1953 unmatched:", len(pop_unmatched))


if __name__ == "__main__":
    main()

