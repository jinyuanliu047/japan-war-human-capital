#!/usr/bin/env python3
"""Prepare DID panel from 1982 census with old->current county harmonization.

This version is built for merge usability:
- treatment uses martyr native-place counts from data/scrape
- county mapping has two tiers:
  1) strict mapping (high-confidence old->current)
  2) final mapping (strict + deterministic city-level fallback)
"""

from __future__ import annotations

import math
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path

import pandas as pd


@dataclass
class CountyMapResult:
    strict_code: str
    strict_route: str
    final_code: str
    final_route: str
    strict_ok: int


def normalize_text(val) -> str:
    s = "" if pd.isna(val) else str(val).lower()
    s = s.replace("&", "and")
    return re.sub(r"[^a-z]+", "", s)


def strip_suffix(s: str) -> str:
    # Conservative suffix removal for pinyin/english labels.
    suffixes = [
        "municipality",
        "prefecture",
        "districts",
        "district",
        "counties",
        "county",
        "city",
        "autonomousprefecture",
        "autonomouscounty",
        "autonomousbanner",
        "autonomous",
        "banner",
        "miningarea",
        "minearea",
        "specialdistrict",
        "specialregion",
        "special",
        "kuangqu",
        "zizhizhou",
        "zizhixian",
        "meng",
        "qi",
        "shi",
        "xian",
        "qu",
    ]
    out = s
    changed = True
    while changed:
        changed = False
        for suf in suffixes:
            if out.endswith(suf) and len(out) > len(suf) + 1:
                # Avoid over-stripping short pinyin units (e.g., tongxian -> tong).
                if suf in {"meng", "qi", "shi", "xian", "qu"} and (len(out) - len(suf) < 5):
                    continue
                out = out[: -len(suf)]
                changed = True
    return out


def municipality_old_to_new(old6: str) -> str:
    # Typical old coding: 1100xx/1200xx/3100xx -> 1101xx/1201xx/3101xx.
    if len(old6) != 6 or old6[:2] not in {"11", "12", "31"} or old6[2:4] != "00":
        return old6
    return f"{old6[:2]}01{old6[4:6]}"


def build_crosswalk(
    census_path: Path,
    county_map_path: Path,
    out_crosswalk: Path,
    out_unmatched: Path,
) -> pd.DataFrame:
    use_cols = ["countyid", "geo1_cn1982", "geo2_cn1982", "geo3_cn1982"]

    # Unique county-level identifiers from 1982 data.
    pieces = []
    for ch in pd.read_stata(census_path, convert_categoricals=False, columns=use_cols, chunksize=400000):
        c = ch.dropna(subset=use_cols).drop_duplicates()
        pieces.append(c)
    old = pd.concat(pieces, ignore_index=True).drop_duplicates()
    old = old.astype(
        {
            "countyid": "int64",
            "geo1_cn1982": "int64",
            "geo2_cn1982": "int64",
            "geo3_cn1982": "int64",
        }
    )
    old["old_countyid"] = old["countyid"].astype(str).str.zfill(6)

    # Stata value labels (pinyin labels from IPUMS).
    reader = pd.io.stata.StataReader(str(census_path), convert_categoricals=False)
    value_labels = reader.value_labels()
    prov_map = value_labels["GEO1_CN1982"]
    city_map = value_labels["GEO2_CN1982"]
    county_map = value_labels["GEO3_CN1982"]

    old["prov_en_old"] = old["geo1_cn1982"].map(prov_map)
    old["city_en_old"] = old["geo2_cn1982"].map(city_map)
    old["county_en_old"] = old["geo3_cn1982"].map(county_map)

    # Normalize old labels.
    for src, dst in [
        ("prov_en_old", "prov_n"),
        ("city_en_old", "city_n"),
        ("county_en_old", "county_n"),
    ]:
        old[dst] = old[src].map(normalize_text)
        old[f"{dst}_k"] = old[dst].map(strip_suffix)

    # Current county map.
    cur = pd.read_excel(
        county_map_path,
        sheet_name="County0010",
        usecols=["GbProv", "Prov_EN", "GbCity", "City_EN", "GBCounty", "County_EN"],
    )
    cur = cur.astype({"GbProv": "int64", "GbCity": "int64", "GBCounty": "int64"})
    cur["curr_countyid"] = cur["GBCounty"].astype(str).str.zfill(6)
    for src, dst in [("Prov_EN", "prov_n"), ("City_EN", "city_n"), ("County_EN", "county_n")]:
        cur[dst] = cur[src].map(normalize_text)
        cur[f"{dst}_k"] = cur[dst].map(strip_suffix)

    cur_codes = set(cur["curr_countyid"].tolist())
    cur_by_prov = {k: v.reset_index(drop=True) for k, v in cur.groupby("GbProv")}

    # Known administrative mergers into newer districts.
    # Use name-first rules because old municipality serials are not stable in this sample.
    manual_name_successor = {
        "congwen": "110101",   # Chongwen -> Dongcheng
        "chongwen": "110101",  # Chongwen -> Dongcheng
        "xuanwu": "110102",    # Xuanwu -> Xicheng
        "luwan": "310101",     # Luwan -> Huangpu
        "zhabei": "310106",    # Zhabei -> Jing'an
        "nanhui": "310115",    # Nanhui -> Pudong
    }
    manual_code_successor = {
        "310103": "310101",  # Luwan -> Huangpu
        "310108": "310106",  # Zhabei -> Jing'an
        "310119": "310115",  # Nanhui -> Pudong
    }

    # Frequent spelling variants from GEO3 labels.
    alias_county_key = {
        "congwen": "chongwen",
        "nanaan": "nanan",
        "shihong": "sihong",
        "congyi": "chongyi",
        "congren": "chongren",
        "suangpai": "shuangpai",
        "echng": "echeng",
        "meitian": "meitan",
        "lingtong": "lintong",
        "xuniyi": "xunyi",
        "yinjun": "yijun",
        "wangrong": "wanrong",
        "haibuowan": "haibowan",
        "liangjiang": "lianjiang",
        "linshan": "lingshan",
        "nenanmongolian": "henanmengguzu",
    }

    # Old prefecture/league naming to newer city-level naming (for fallback).
    # Key: (old_province_code, old_city_key), Value: (target_province_code, target_city_key)
    city_alias_target = {
        # Chongqing-related old Sichuan units
        (51, "chongqing"): (50, "chongqing"),
        (51, "wangxian"): (50, "chongqing"),
        (51, "fuling"): (50, "chongqing"),
        (42, "yunyang"): (42, "shiyan"),
        (51, "daxian"): (51, "dazhou"),
        # Inner Mongolia old leagues
        (15, "hulunbuirleague"): (15, "hulunbeier"),
        (15, "zhelimuleague"): (15, "tongliao"),
        (15, "zhaowudaleague"): (15, "chifeng"),
        (15, "yikezhaoleague"): (15, "eerduosi"),
        (15, "ulaanchableague"): (15, "wulanchabu"),
        (15, "bayannurleague"): (15, "bayannaoer"),
        # Old prefecture renaming
        (42, "xiangyang"): (42, "xiangfan"),
        (53, "simao"): (53, "puer"),
        (45, "bose"): (45, "baise"),
        (45, "hechi"): (45, "chizhou"),
        (44, "meixian"): (44, "meizhou"),
        (44, "huiyang"): (44, "huizhou"),
        (62, "wudu"): (62, "longnan"),
        (65, "yilikazak"): (65, "yilihasake"),
        (65, "altay"): (65, "aletaidi"),
        (23, "hejiang"): (23, "heihe"),
        (23, "nenjiang"): (23, "heihe"),
        (14, "xinxian"): (14, "xinzhou"),
        (14, "yanbei"): (14, "datong"),
        (14, "jindongnan"): (14, "changzhi"),
        (34, "chuxian"): (34, "chuzhou"),
        (34, "suxian"): (34, "suzhou"),
        (34, "huizhou"): (34, "huangshan"),
        (35, "jianyang"): (35, "nanping"),
        (35, "longxi"): (35, "zhangzhou"),
        (35, "jinjiang"): (35, "quanzhou"),
        (43, "lingling"): (43, "yongzhou"),
        (43, "lianyuan"): (43, "loudi"),
        (37, "huimin"): (37, "binzhou"),
        (64, "yinnan"): (64, "wuzhong"),
        # Hainan split from Guangdong
        (44, "hainan"): (46, "hainandirectunits"),
        (44, "hainanlimiao"): (46, "hainandirectunits"),
    }

    def pick_city_core(sub: pd.DataFrame, city_key: str) -> str:
        if sub.empty:
            return ""
        if city_key:
            city_sub = sub[sub["city_n_k"] == city_key]
            if not city_sub.empty:
                # Prefer district-like code xx01/xx02, else min code in city.
                city_sub = city_sub.copy()
                city_sub["suf"] = city_sub["curr_countyid"].str[-2:]
                pref = city_sub[city_sub["suf"].isin({"01", "02"})]
                if not pref.empty:
                    return str(pref.sort_values("curr_countyid").iloc[0]["curr_countyid"])
                return str(city_sub.sort_values("curr_countyid").iloc[0]["curr_countyid"])
        sub2 = sub.copy()
        sub2["suf"] = sub2["curr_countyid"].str[-2:]
        pref = sub2[sub2["suf"].isin({"01", "02"})]
        if not pref.empty:
            return str(pref.sort_values("curr_countyid").iloc[0]["curr_countyid"])
        return str(sub2.sort_values("curr_countyid").iloc[0]["curr_countyid"])

    def pick_city_core_by_key(sub: pd.DataFrame, city_key: str) -> str:
        if sub.empty or not city_key:
            return ""
        city_sub = sub[sub["city_n_k"] == city_key]
        if city_sub.empty:
            return ""
        return pick_city_core(city_sub, city_key)

    def fuzzy_city_match(sub: pd.DataFrame, city_key: str) -> str:
        if sub.empty or not city_key:
            return ""
        uniq_cities = sorted(set([c for c in sub["city_n_k"].tolist() if c]))
        if not uniq_cities:
            return ""
        ranked = []
        for c in uniq_cities:
            score = SequenceMatcher(None, city_key, c).ratio()
            ranked.append((score, c))
        ranked.sort(key=lambda x: x[0], reverse=True)
        best_score, best_city = ranked[0]
        second_score = ranked[1][0] if len(ranked) > 1 else 0.0
        if best_score >= 0.78 and (best_score - second_score) >= 0.08:
            return best_city
        return ""

    def strict_map(old_code: str, prov: int, city_k: str, county_k: str, county_n: str) -> tuple[str, str]:
        # 0) known successor map (name-first, safer across old code serial variants)
        if county_k in manual_name_successor:
            return manual_name_successor[county_k], "manual_name_successor"

        # 0b) known successor map by code
        if old_code in manual_code_successor:
            return manual_code_successor[old_code], "manual_successor"

        # 1) direct current code hit
        if old_code in cur_codes:
            return old_code, "exact_code"

        sub = cur_by_prov.get(prov)
        if sub is None or sub.empty:
            return "", "no_province_in_map"

        target_k = alias_county_key.get(county_k, county_k)

        # 2) province + county key exact
        cands = sub[sub["county_n_k"] == target_k]
        if len(cands) == 1:
            return str(cands.iloc[0]["curr_countyid"]), "prov_county_key_exact"
        if len(cands) > 1:
            c2 = cands[cands["city_n_k"] == city_k]
            if len(c2) == 1:
                return str(c2.iloc[0]["curr_countyid"]), "prov_county_city_key_exact"

        # 3) province + county raw exact
        cands = sub[sub["county_n"] == county_n]
        if len(cands) == 1:
            return str(cands.iloc[0]["curr_countyid"]), "prov_county_raw_exact"
        if len(cands) > 1:
            c2 = cands[cands["city_n_k"] == city_k]
            if len(c2) == 1:
                return str(c2.iloc[0]["curr_countyid"]), "prov_county_city_raw_exact"

        # 4) safe fuzzy (high threshold + clear gap)
        if target_k:
            ranked = []
            for rec in sub.itertuples(index=False):
                cand = rec.county_n_k
                if not cand:
                    continue
                score = SequenceMatcher(None, target_k, cand).ratio()
                ranked.append((score, rec))
            ranked.sort(key=lambda x: x[0], reverse=True)
            if ranked:
                best = ranked[0]
                second = ranked[1][0] if len(ranked) > 1 else 0.0
                # Extra confidence if city also matches.
                city_bonus = 0.03 if best[1].city_n_k == city_k else 0.0
                if best[0] + city_bonus >= 0.94 and (best[0] - second) >= 0.08:
                    route = "prov_county_fuzzy_city" if best[1].city_n_k == city_k else "prov_county_fuzzy"
                    return str(best[1].curr_countyid), route

        # 5) municipality geo3-consistent recode (xx00yy -> xx01yy).
        # Keep this even when not present in County0010 so codes like 110010 -> 110110 survive.
        muni = municipality_old_to_new(old_code)
        if muni != old_code:
            if muni in manual_code_successor:
                return manual_code_successor[muni], "municipality_then_successor"
            if muni in cur_codes:
                return muni, "municipality_old_to_new"
            return muni, "municipality_geo3_recode"

        return "", "unmatched_strict"

    # Build strict mapping.
    results: dict[str, CountyMapResult] = {}
    unmatched_rows = []
    strict_counter = Counter()
    final_counter = Counter()

    for row in old.itertuples(index=False):
        old_code = row.old_countyid
        prov = int(row.geo1_cn1982)
        city_k = row.city_n_k
        county_k = row.county_n_k
        county_n = row.county_n
        code, route = strict_map(old_code, prov, city_k, county_k, county_n)
        strict_counter[route] += 1

        strict_ok = 1 if code else 0
        final_code = code
        final_route = route

        # Keep unmatched as unmatched; do not force city-level fallback mapping.
        if not final_code:
            final_code = ""
            final_route = "unmatched_strict"

            unmatched_rows.append(
                {
                    "old_countyid": old_code,
                    "geo1_cn1982": prov,
                    "geo2_cn1982": int(row.geo2_cn1982),
                    "geo3_cn1982": int(row.geo3_cn1982),
                    "prov_en_old": row.prov_en_old,
                    "city_en_old": row.city_en_old,
                    "county_en_old": row.county_en_old,
                    "strict_route": route,
                    "final_route": final_route,
                    "final_code": final_code,
                }
            )

        final_counter[final_route] += 1
        results[old_code] = CountyMapResult(
            strict_code=code,
            strict_route=route,
            final_code=final_code,
            final_route=final_route,
            strict_ok=strict_ok,
        )

    # Build crosswalk dataframe.
    cw = old.copy()
    cw["countyid_old6"] = cw["old_countyid"]
    cw["countyid_curr6_strict"] = cw["old_countyid"].map(lambda x: results[x].strict_code)
    cw["route_strict"] = cw["old_countyid"].map(lambda x: results[x].strict_route)
    cw["countyid_curr6_final"] = cw["old_countyid"].map(lambda x: results[x].final_code)
    cw["route_final"] = cw["old_countyid"].map(lambda x: results[x].final_route)
    cw["strict_mapped"] = cw["old_countyid"].map(lambda x: results[x].strict_ok).astype(int)

    keep_cols = [
        "countyid_old6",
        "countyid_curr6_strict",
        "countyid_curr6_final",
        "strict_mapped",
        "route_strict",
        "route_final",
        "geo1_cn1982",
        "geo2_cn1982",
        "geo3_cn1982",
        "prov_en_old",
        "city_en_old",
        "county_en_old",
    ]
    cw = cw[keep_cols].drop_duplicates(subset=["countyid_old6"]).sort_values("countyid_old6")
    out_crosswalk.parent.mkdir(parents=True, exist_ok=True)
    cw.to_csv(out_crosswalk, index=False)

    # Save unresolved strict-mapping list for manual review.
    unmatched_df = pd.DataFrame(unmatched_rows).sort_values(["geo1_cn1982", "geo2_cn1982", "county_en_old"])
    unmatched_df.to_csv(out_unmatched, index=False)

    print(f"crosswalk_county_n={len(cw)}")
    print(f"strict_mapped_county_n={int(cw['strict_mapped'].sum())}")
    print("strict_routes_top=" + str(strict_counter.most_common(10)))
    print("final_routes_top=" + str(final_counter.most_common(10)))
    return cw


def main() -> None:
    base = Path(
        "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
    )
    census_path = base / "data/temp/census_1982_cleaned.dta"
    martyr_path = base / "data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts_merge_ready.csv"
    county_map_path = base / "data/raw/China_Map/County0010.xlsx"

    out_crosswalk = base / "data/temp/countyid_1982_to_current_crosswalk_v2.csv"
    out_unmatched = base / "data/temp/countyid_1982_to_current_unmatched_strict_v2.csv"

    out_csv = base / "data/temp/did_1982_county_birthyr_martyr_native_v2.csv"
    out_dta = base / "data/temp/did_1982_county_birthyr_martyr_native_v2.dta"
    out_harmonize = base / "data/temp/did_1982_county_code_harmonization_summary_v2.csv"

    cw = build_crosswalk(census_path, county_map_path, out_crosswalk, out_unmatched)
    cw["countyid_old6_int"] = cw["countyid_old6"].astype(int)

    # Martyr native treatment by current county code (first 6 digits of merge_place_id).
    m = pd.read_csv(martyr_path, dtype={"merge_place_id": str})
    m = m[m["merge_place_id"].str.fullmatch(r"\d{12}", na=False)].copy()
    m["countyid_curr6"] = m["merge_place_id"].str[:6]
    m = (
        m.groupby("countyid_curr6", as_index=False)["martyr_count"]
        .sum()
        .rename(columns={"martyr_count": "martyr_native_count_1931_1945"})
    )
    martyr_map = dict(zip(m["countyid_curr6"], m["martyr_native_count_1931_1945"]))

    use_cols = ["countyid", "birthyr", "eduy", "perwt"]

    # Accumulate grouped chunks.
    grouped_chunks = []
    route_row_counter = Counter()
    route_wt_counter = defaultdict(float)

    for chunk in pd.read_stata(census_path, convert_categoricals=False, columns=use_cols, chunksize=350000):
        chunk = chunk.dropna(subset=use_cols)
        if chunk.empty:
            continue

        chunk = chunk[(chunk["birthyr"] >= 1900) & (chunk["birthyr"] <= 1965)]
        chunk = chunk[(chunk["eduy"] >= 0) & (chunk["eduy"] <= 25)]
        chunk = chunk[chunk["perwt"] > 0]
        if chunk.empty:
            continue

        chunk["countyid_old6_int"] = chunk["countyid"].astype(int)
        chunk = chunk.merge(
            cw[
                [
                    "countyid_old6_int",
                    "countyid_curr6_final",
                    "strict_mapped",
                    "route_final",
                ]
            ],
            on="countyid_old6_int",
            how="left",
        )

        chunk = chunk.dropna(subset=["countyid_curr6_final"])
        chunk = chunk[chunk["countyid_curr6_final"] != ""]
        if chunk.empty:
            continue

        # Track harmonization usage by row and by person-weight.
        vc = chunk["route_final"].value_counts()
        for k, v in vc.items():
            route_row_counter[k] += int(v)
        wt_by_route = chunk.groupby("route_final", as_index=False)["perwt"].sum()
        for r in wt_by_route.itertuples(index=False):
            route_wt_counter[str(r.route_final)] += float(r.perwt)

        chunk["eduy_w"] = chunk["eduy"] * chunk["perwt"]
        chunk["strict_w"] = chunk["perwt"] * chunk["strict_mapped"]

        g = (
            chunk.groupby(["countyid_curr6_final", "birthyr"], as_index=False)
            .agg(
                n_obs=("eduy", "size"),
                wt_sum=("perwt", "sum"),
                eduy_wsum=("eduy_w", "sum"),
                strict_wsum=("strict_w", "sum"),
            )
            .rename(columns={"countyid_curr6_final": "countyid_curr6"})
        )
        grouped_chunks.append(g)

    out = pd.concat(grouped_chunks, ignore_index=True)
    out = (
        out.groupby(["countyid_curr6", "birthyr"], as_index=False)
        .agg(
            n_obs=("n_obs", "sum"),
            wt_sum=("wt_sum", "sum"),
            eduy_wsum=("eduy_wsum", "sum"),
            strict_wsum=("strict_wsum", "sum"),
        )
        .sort_values(["countyid_curr6", "birthyr"])
    )

    out["eduy_wmean"] = out["eduy_wsum"] / out["wt_sum"]
    out["strict_share_wt"] = out["strict_wsum"] / out["wt_sum"]

    out["martyr_native_count_1931_1945"] = out["countyid_curr6"].map(martyr_map).fillna(0.0)
    out["ln_martyr_native_count"] = out["martyr_native_count_1931_1945"].map(lambda x: math.log1p(float(x)))

    # Cohort definitions.
    # School-entry-age during 1931-1945 war years: born 1925-1939 (age 6 in 1931..1945).
    out["schoolage_war"] = ((out["birthyr"] >= 1925) & (out["birthyr"] <= 1939)).astype(int)
    out["wartime_birth"] = ((out["birthyr"] >= 1931) & (out["birthyr"] <= 1945)).astype(int)
    out["postwar_birth"] = ((out["birthyr"] >= 1946) & (out["birthyr"] <= 1955)).astype(int)

    # Sample windows for different DID specs.
    out["sample_schoolage_did"] = ((out["birthyr"] >= 1915) & (out["birthyr"] <= 1950)).astype(int)
    out["sample_wartime_vs_post"] = ((out["birthyr"] >= 1931) & (out["birthyr"] <= 1955)).astype(int)
    out["sample_war_birth_vs_pre"] = ((out["birthyr"] >= 1916) & (out["birthyr"] <= 1945)).astype(int)

    out["did_schoolage_interaction"] = out["ln_martyr_native_count"] * out["schoolage_war"]
    out["did_wartimebirth_interaction"] = out["ln_martyr_native_count"] * out["wartime_birth"]
    out["did_postwar_interaction"] = out["ln_martyr_native_count"] * out["postwar_birth"]

    out_csv.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(out_csv, index=False)
    out.to_stata(out_dta, write_index=False, version=118)

    harm_rows = []
    all_routes = set(route_row_counter.keys()) | set(route_wt_counter.keys())
    for r in sorted(all_routes):
        harm_rows.append(
            {
                "route_final": r,
                "row_count": int(route_row_counter.get(r, 0)),
                "person_weight_sum": float(route_wt_counter.get(r, 0.0)),
            }
        )
    harm = pd.DataFrame(harm_rows).sort_values("row_count", ascending=False)
    harm.to_csv(out_harmonize, index=False)

    print(f"panel_rows={len(out)}")
    print(f"county_n={out['countyid_curr6'].nunique()}")
    print(f"birthyr_min={int(out['birthyr'].min())} birthyr_max={int(out['birthyr'].max())}")
    print(f"positive_treat_county_n={(out[out['martyr_native_count_1931_1945']>0]['countyid_curr6'].nunique())}")
    print(f"positive_treat_row_share={(out['martyr_native_count_1931_1945']>0).mean():.4f}")
    print(f"output_csv={out_csv}")
    print(f"output_dta={out_dta}")
    print(f"crosswalk_csv={out_crosswalk}")
    print(f"unmatched_strict_csv={out_unmatched}")
    print(f"harmonize_summary={out_harmonize}")


if __name__ == "__main__":
    main()
