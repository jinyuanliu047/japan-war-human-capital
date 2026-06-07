#!/usr/bin/env python3
"""Build extended county controls for robustness checks.

Outputs
- data/temp/county_controls_full_v1.csv/.dta
- data/scrape/chinamartyrs_outputs/memorial_facilities_full_v1.csv
- data/scrape/chinamartyrs_outputs/memorial_facilities_county_level_v1.csv
- data/temp/major_case_events_parsed_v1.csv
- data/temp/major_case_events_county_exposure_v1.csv
"""

from __future__ import annotations

import math
import re
from collections import defaultdict
from pathlib import Path

import numpy as np
import pandas as pd
import requests
from docx import Document


PROJ = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
)

MEMORIAL_API = "https://yinglie.chinamartyrs.gov.cn/dev-api/api/cemetery/getCemeteryListByVr"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "Referer": "https://www.chinamartyrs.gov.cn/shengji1_jnss/qjlsjnsslist/",
}


def code6(value: object) -> str:
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return ""
    txt = str(value).strip()
    if not txt:
        return ""
    txt = txt.replace(".0", "")
    digits = "".join(ch for ch in txt if ch.isdigit())
    if len(digits) >= 6:
        return digits[:6]
    if digits:
        return digits.zfill(6)
    return ""


def clean_text(value: object) -> str:
    text = str(value or "").strip()
    text = re.sub(r"\s+", "", text)
    return text


def normalize_place(value: object) -> str:
    text = clean_text(value)
    if not text:
        return ""
    text = re.sub(r"（[^）]*）", "", text)
    text = re.sub(r"\([^\)]*\)", "", text)
    text = text.replace("（", "").replace("）", "")
    suffixes = [
        "维吾尔自治区",
        "壮族自治区",
        "回族自治区",
        "特别行政区",
        "蒙古自治州",
        "藏族自治州",
        "哈萨克自治州",
        "朝鲜族自治州",
        "自治区",
        "自治州",
        "自治县",
        "自治旗",
        "地区",
        "新区",
        "矿区",
        "林区",
        "盟",
        "省",
        "市",
        "县",
        "区",
        "旗",
    ]
    changed = True
    while changed and text:
        changed = False
        for sf in suffixes:
            if text.endswith(sf) and len(text) > len(sf):
                text = text[: -len(sf)]
                changed = True
                break
    return text


def build_county_dict() -> pd.DataFrame:
    county = pd.read_excel(
        PROJ / "data/raw/China_Map/County0010.xlsx",
        sheet_name="County0010",
        usecols=["GbProv", "Prov_CH", "GbCity", "City_CH", "GBCounty", "County_CH"],
    ).copy()
    county["countyid_curr6"] = county["GBCounty"].apply(code6)
    county = county[county["countyid_curr6"] != ""].copy()
    county["prov_code2"] = county["GbProv"].astype(int).astype(str).str.zfill(2)
    county["city_code4"] = county["GbCity"].astype(int).astype(str).str.zfill(4)

    county["prov_name"] = county["Prov_CH"].astype(str)
    county["city_name"] = county["City_CH"].astype(str)
    county["county_name"] = county["County_CH"].astype(str)

    county["prov_norm"] = county["prov_name"].apply(normalize_place)
    county["city_norm"] = county["city_name"].apply(normalize_place)
    county["county_norm"] = county["county_name"].apply(normalize_place)

    return county[
        [
            "countyid_curr6",
            "prov_code2",
            "city_code4",
            "prov_name",
            "city_name",
            "county_name",
            "prov_norm",
            "city_norm",
            "county_norm",
        ]
    ].drop_duplicates()


def fetch_memorial_rows() -> pd.DataFrame:
    first = requests.post(MEMORIAL_API, headers=HEADERS, data={"pageNum": 1, "pageSize": 100}, timeout=30)
    first.raise_for_status()
    payload = first.json()
    total = int(payload.get("total", 0))
    rows = list(payload.get("rows", []))
    pages = max(1, math.ceil(total / 100))

    for page in range(2, pages + 1):
        resp = requests.post(
            MEMORIAL_API,
            headers=HEADERS,
            data={"pageNum": page, "pageSize": 100},
            timeout=30,
        )
        resp.raise_for_status()
        rows.extend(resp.json().get("rows", []))

    df = pd.DataFrame(rows)
    if df.empty:
        return df

    keep_cols = [
        "mmdwGuid",
        "mmdwName",
        "mmdwLevelId",
        "mmdwLevel",
        "mmdwShengId",
        "mmdwSheng",
        "mmdwShiId",
        "mmdwShi",
        "mmdwXianId",
        "mmdwXian",
        "mmdwAddress",
    ]
    for c in keep_cols:
        if c not in df.columns:
            df[c] = ""
    return df[keep_cols].copy()


def build_name_maps(county: pd.DataFrame):
    county_name_map = defaultdict(set)
    city_name_map = defaultdict(set)
    prov_name_map = defaultdict(set)

    for _, r in county.iterrows():
        cid = r["countyid_curr6"]
        for name in {clean_text(r["county_name"]), r["county_norm"]}:
            if name and len(name) >= 2:
                county_name_map[name].add(cid)
        for name in {clean_text(r["city_name"]), r["city_norm"]}:
            if name and len(name) >= 2:
                city_name_map[name].add(cid)
        for name in {clean_text(r["prov_name"]), r["prov_norm"]}:
            if name and len(name) >= 2:
                prov_name_map[name].add(cid)

    return county_name_map, city_name_map, prov_name_map


def resolve_memorial_counties(df: pd.DataFrame, county: pd.DataFrame) -> pd.DataFrame:
    county_set = set(county["countyid_curr6"])
    county_name_map, city_name_map, _ = build_name_maps(county)

    records: list[dict[str, object]] = []
    for _, row in df.iterrows():
        matched = set()

        for field in ["mmdwXianId", "mmdwShiId", "mmdwShengId"]:
            c = code6(row.get(field, ""))
            if c in county_set:
                matched.add(c)

        if not matched:
            xian = clean_text(row.get("mmdwXian", ""))
            shi = clean_text(row.get("mmdwShi", ""))
            if xian in county_name_map:
                matched.update(county_name_map[xian])
            xian_norm = normalize_place(xian)
            if xian_norm in county_name_map:
                matched.update(county_name_map[xian_norm])
            if not matched:
                if shi in city_name_map:
                    matched.update(city_name_map[shi])
                shi_norm = normalize_place(shi)
                if shi_norm in city_name_map:
                    matched.update(city_name_map[shi_norm])

        if not matched:
            continue

        weight = 1.0 / len(matched)
        lv = str(row.get("mmdwLevelId", "")).strip()
        for cid in matched:
            records.append(
                {
                    "countyid_curr6": cid,
                    "mmdwGuid": row.get("mmdwGuid", ""),
                    "mmdwName": row.get("mmdwName", ""),
                    "mmdwLevelId": lv,
                    "mmdwLevel": row.get("mmdwLevel", ""),
                    "memorial_weight": weight,
                }
            )

    mapped = pd.DataFrame(records)
    if mapped.empty:
        return pd.DataFrame(columns=["countyid_curr6"])

    out = mapped.groupby("countyid_curr6", as_index=False).agg(memorial_cnt_total=("memorial_weight", "sum"))

    level_vars = {
        "1": "memorial_cnt_national",
        "2": "memorial_cnt_prov",
        "3": "memorial_cnt_city",
        "4": "memorial_cnt_county",
        "5": "memorial_cnt_undetermined",
    }
    for lid, vname in level_vars.items():
        tmp = (
            mapped[mapped["mmdwLevelId"] == lid]
            .groupby("countyid_curr6", as_index=False)["memorial_weight"]
            .sum()
            .rename(columns={"memorial_weight": vname})
        )
        out = out.merge(tmp, on="countyid_curr6", how="left")

    for c in out.columns:
        if c != "countyid_curr6":
            out[c] = out[c].fillna(0.0)

    return mapped, out


def parse_death_number(text: str) -> float:
    if not text:
        return np.nan
    vals = []
    for m in re.findall(r"(\d+(?:\.\d+)?)\s*万", text):
        vals.append(float(m) * 10000.0)
    for m in re.findall(r"(\d+(?:\.\d+)?)\s*千", text):
        vals.append(float(m) * 1000.0)
    for m in re.findall(r"(\d+(?:\.\d+)?)\s*(?:余)?人", text):
        vals.append(float(m))
    if not vals:
        return np.nan
    return float(max(vals))


def parse_major_case_events(doc_path: Path) -> pd.DataFrame:
    doc = Document(str(doc_path))
    rows = []
    for idx, p in enumerate(doc.paragraphs):
        text = clean_text(p.text)
        if not text:
            continue
        if idx == 0:
            continue
        if "(" not in text or ")" not in text:
            continue
        loc = text.split("(", 1)[0]
        date_text = text.split("(", 1)[1].split(")", 1)[0]
        desc = text.split(")", 1)[1] if ")" in text else ""

        if not re.search(r"惨案|屠杀|轰炸|扫荡|爆炸", loc + desc):
            continue
        year_m = re.search(r"(19\d{2})", date_text)
        year = int(year_m.group(1)) if year_m else np.nan
        if pd.notna(year) and (year < 1931 or year > 1945):
            continue

        rows.append(
            {
                "event_text": text,
                "location_text": loc,
                "date_text": date_text,
                "year": year,
                "death_est": parse_death_number(desc),
            }
        )

    return pd.DataFrame(rows)


def map_events_to_county(events: pd.DataFrame, county: pd.DataFrame) -> pd.DataFrame:
    county_name_map, city_name_map, _ = build_name_maps(county)

    prov_to_codes = defaultdict(set)
    for _, r in county.iterrows():
        prov_to_codes[clean_text(r["prov_name"])].add(r["countyid_curr6"])
        prov_to_codes[r["prov_norm"]].add(r["countyid_curr6"])

    mapped_rows: list[dict[str, object]] = []

    county_terms = sorted(county_name_map.keys(), key=len, reverse=True)
    city_terms = sorted(city_name_map.keys(), key=len, reverse=True)

    for _, ev in events.iterrows():
        loc = clean_text(ev["location_text"])
        matched = set()

        prov_filter = set()
        for pnm, codes in prov_to_codes.items():
            if pnm and pnm in loc:
                prov_filter.update(codes)

        for t in county_terms:
            if t in loc:
                cands = set(county_name_map[t])
                if prov_filter:
                    cands = cands & prov_filter
                matched.update(cands)

        source = "county_name"
        if not matched:
            for t in city_terms:
                if t in loc:
                    cands = set(city_name_map[t])
                    if prov_filter:
                        cands = cands & prov_filter
                    matched.update(cands)
            source = "city_name"

        if not matched:
            continue

        wt = 1.0 / len(matched)
        death_val = ev["death_est"] if pd.notna(ev["death_est"]) else 1.0
        highcas = 1.0 if pd.notna(ev["death_est"]) and ev["death_est"] >= 1000 else 0.0

        for cid in matched:
            mapped_rows.append(
                {
                    "countyid_curr6": cid,
                    "year": ev["year"],
                    "event_text": ev["event_text"],
                    "location_text": ev["location_text"],
                    "death_est": ev["death_est"],
                    "map_source": source,
                    "event_w": wt,
                    "death_w": death_val * wt,
                    "highcas_w": highcas * wt,
                }
            )

    mapped = pd.DataFrame(mapped_rows)
    if mapped.empty:
        return mapped, pd.DataFrame(columns=["countyid_curr6"])

    county_exp = mapped.groupby("countyid_curr6", as_index=False).agg(
        massacre_event_w=("event_w", "sum"),
        massacre_death_w=("death_w", "sum"),
        massacre_event_highcas_w=("highcas_w", "sum"),
    )
    county_exp["massacre_any"] = (county_exp["massacre_event_w"] > 0).astype(float)
    county_exp["ln_massacre_death"] = np.log1p(county_exp["massacre_death_w"])
    return mapped, county_exp


def build_aer_controls() -> pd.DataFrame:
    cd = pd.read_stata(PROJ / "data/raw/county_data.dta", convert_categoricals=False)
    cc = pd.read_stata(PROJ / "data/raw/census_1990_county_char.dta", convert_categoricals=False)

    cd = cd[["countyid", "region2010", "sdy_density", "victims_cr", "grain_output", "urbanratio64"]].copy()
    cc = cc[["countyid", "ins_famine", "primary_graduate", "junior_graduate", "han_ethn"]].copy()

    out = cd.merge(cc, on="countyid", how="left")
    out["countyid_curr6"] = out["region2010"].apply(code6)
    out = out[out["countyid_curr6"] != ""].copy()

    keep = [
        "countyid_curr6",
        "sdy_density",
        "victims_cr",
        "grain_output",
        "urbanratio64",
        "ins_famine",
        "primary_graduate",
        "junior_graduate",
        "han_ethn",
    ]
    return out[keep].drop_duplicates(subset=["countyid_curr6"])


def main() -> None:
    county = build_county_dict()

    memorial_raw = fetch_memorial_rows()
    memorial_mapped, memorial_county = resolve_memorial_counties(memorial_raw, county)

    events = parse_major_case_events(PROJ / "war_history/major_case/日寇南京大屠杀罪证.docx")
    event_mapped, massacre_county = map_events_to_county(events, county)

    aer = build_aer_controls()

    clan_quake = pd.read_stata(PROJ / "data/temp/county_clan_quake_controls_v1.dta", convert_categoricals=False)
    clan_quake["countyid_curr6"] = clan_quake["countyid_curr6"].apply(code6)

    panel_list = []
    for wave in [1982, 1990, 2000]:
        tmp = pd.read_stata(
            PROJ / f"data/temp/did_{wave}_county_birthyr_pop1953_unwt_v2.dta",
            convert_categoricals=False,
        )[["countyid_curr6"]].copy()
        panel_list.append(tmp)
    panel_base = pd.concat(panel_list, ignore_index=True).drop_duplicates()
    panel_base["countyid_curr6"] = panel_base["countyid_curr6"].apply(code6)
    panel_base = panel_base[(panel_base["countyid_curr6"] != "") & (panel_base["countyid_curr6"] != "000000")]
    panel_base = panel_base.drop_duplicates()

    out = panel_base.merge(aer, on="countyid_curr6", how="left")
    out = out.merge(
        clan_quake[
            [
                "countyid_curr6",
                "clan_num",
                "ln_clan",
                "qk_cnt_m45_pre1940",
                "qk_maxmag_pre1940",
            ]
        ],
        on="countyid_curr6",
        how="left",
    )
    out = out.merge(memorial_county, on="countyid_curr6", how="left")
    out = out.merge(massacre_county, on="countyid_curr6", how="left")

    for c in [
        "clan_num",
        "ln_clan",
        "qk_cnt_m45_pre1940",
        "qk_maxmag_pre1940",
        "memorial_cnt_total",
        "memorial_cnt_national",
        "memorial_cnt_prov",
        "memorial_cnt_city",
        "memorial_cnt_county",
        "memorial_cnt_undetermined",
        "massacre_event_w",
        "massacre_death_w",
        "massacre_event_highcas_w",
        "massacre_any",
        "ln_massacre_death",
    ]:
        if c in out.columns:
            out[c] = out[c].fillna(0.0)

    out["ln_memorial_cnt"] = np.log1p(out["memorial_cnt_total"].fillna(0.0))

    # Save outputs
    (PROJ / "data/scrape/chinamartyrs_outputs").mkdir(parents=True, exist_ok=True)
    (PROJ / "data/temp").mkdir(parents=True, exist_ok=True)

    memorial_raw.to_csv(
        PROJ / "data/scrape/chinamartyrs_outputs/memorial_facilities_full_v1.csv",
        index=False,
        encoding="utf-8-sig",
    )
    memorial_mapped.to_csv(
        PROJ / "data/scrape/chinamartyrs_outputs/memorial_facilities_county_level_v1.csv",
        index=False,
        encoding="utf-8-sig",
    )

    events.to_csv(PROJ / "data/temp/major_case_events_parsed_v1.csv", index=False, encoding="utf-8-sig")
    event_mapped.to_csv(
        PROJ / "data/temp/major_case_events_county_exposure_v1.csv", index=False, encoding="utf-8-sig"
    )

    out.to_csv(PROJ / "data/temp/county_controls_full_v1.csv", index=False, encoding="utf-8-sig")
    out.to_stata(PROJ / "data/temp/county_controls_full_v1.dta", write_index=False, version=118)

    print("Saved county controls:", len(out))
    print(
        out[
            [
                "sdy_density",
                "ins_famine",
                "victims_cr",
                "grain_output",
                "urbanratio64",
                "memorial_cnt_total",
                "massacre_event_w",
                "massacre_death_w",
            ]
        ]
        .notna()
        .sum()
        .to_dict()
    )


if __name__ == "__main__":
    main()
