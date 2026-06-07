#!/usr/bin/env python3
"""Build fully merge-ready place counts (non-empty 12-digit codes).

Output tables guarantee:
- `merge_place_id` is always a 12-digit numeric string
- No raw-text categories in main count outputs
"""

from __future__ import annotations

import csv
import gzip
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Dict, List, Tuple

import requests


ROOT_QY_JSON = (
    "https://www.chinamartyrs.gov.cn/v2/JSON/allQyJSON/000000000000/000000000000.json"
)
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
)
UNKNOWN_CODE = "999999999999"
UNKNOWN_NAME_SACRIFICE = "未匹配牺牲地"
UNKNOWN_NAME_NATIVE = "未匹配籍贯"

SUFFIXES = (
    "特别行政区",
    "维吾尔自治区",
    "壮族自治区",
    "回族自治区",
    "自治区",
    "自治州",
    "自治县",
    "地区",
    "林区",
    "省",
    "市",
    "盟",
    "州",
    "旗",
    "县",
    "区",
)

SACRIFICE_PATTERNS = [
    re.compile(
        r"(?:在|于)([^，。；;、]{2,40}?)(?:战斗中|作战中|围剿中|战役中|阻击战中|保卫战中|起义中|牺牲|遇害|殉国|就义)"
    ),
    re.compile(r"(?:在|于)([^，。；;、]{2,40}?)(?:病逝|因病去世|牺牲)"),
]
NATIVE_PATTERNS = [
    re.compile(r"(?:出生于|生于|原籍|祖籍|籍贯(?:是|为)?)([^，。；;、]{2,30})"),
    re.compile(r"(?:系|是)([^，。；;、]{2,20})人(?:，|。|；|;|$)"),
    re.compile(r"([^，。；;、]{2,12})人(?:，|。|；|;|$)"),
]


def normalize_text(v: Any) -> str:
    s = str(v or "").strip()
    if not s:
        return ""
    s = re.sub(r"\s+", "", s).replace("\u3000", "")
    return s


def normalize_to_12_digit_numeric(raw: Any) -> str:
    s = str(raw or "").strip()
    if not s:
        return ""
    digits = "".join(ch for ch in s if ch.isdigit())
    if len(digits) == 12:
        return digits
    if len(digits) == 6:
        return digits + "000000"
    return ""


def strip_suffix(name: str) -> str:
    for suf in SUFFIXES:
        if name.endswith(suf) and len(name) > len(suf):
            return name[: -len(suf)]
    return name


def load_area_name_map() -> Tuple[Dict[str, str], Dict[str, str], Dict[str, List[Tuple[str, str]]]]:
    resp = requests.get(
        ROOT_QY_JSON,
        headers={"User-Agent": USER_AGENT, "Referer": "https://www.chinamartyrs.gov.cn/"},
        timeout=60,
    )
    resp.raise_for_status()
    root = resp.json()[0]

    code_to_name: Dict[str, str] = {}
    code_to_level: Dict[str, str] = {}
    alias_to_codes: Dict[str, set[str]] = defaultdict(set)

    def walk(node: Dict[str, Any], depth: int) -> None:
        code = normalize_to_12_digit_numeric(node.get("orgId"))
        name = normalize_text(node.get("deptName"))
        if code:
            code_to_name[code] = name
            code_to_level[code] = "province" if depth <= 1 else ("city" if depth == 2 else "county")
            if name:
                alias_to_codes[name].add(code)
                short = strip_suffix(name)
                if short and short != name and len(short) >= 2:
                    alias_to_codes[short].add(code)
        for child in node.get("children") or []:
            walk(child, depth + 1)

    for child in root.get("children") or []:
        walk(child, 1)

    unique_alias = {a: next(iter(v)) for a, v in alias_to_codes.items() if len(v) == 1}
    by_first_char: Dict[str, List[Tuple[str, str]]] = defaultdict(list)
    for alias, code in unique_alias.items():
        by_first_char[alias[0]].append((alias, code))
    for ch, arr in by_first_char.items():
        arr.sort(key=lambda x: len(x[0]), reverse=True)
        by_first_char[ch] = arr

    return code_to_name, code_to_level, by_first_char


def best_match_code(phrase: str, alias_index: Dict[str, List[Tuple[str, str]]]) -> str:
    text = normalize_text(phrase)
    if not text:
        return ""
    best = ("", 0)
    seen = set()
    for ch in set(text):
        for alias, code in alias_index.get(ch, []):
            if alias in seen:
                continue
            if alias in text:
                seen.add(alias)
                if len(alias) > best[1]:
                    best = (code, len(alias))
    return best[0]


def extract_sacrifice_phrase(row: Dict[str, Any]) -> str:
    text = normalize_text(row.get("mmdrDeathPlace")) or normalize_text(row.get("mmdrDeeds"))
    if not text:
        return ""
    for pat in SACRIFICE_PATTERNS:
        m = pat.search(text)
        if m:
            return m.group(1).strip("，。；;、 ")
    return text[:30]


def extract_native_phrase(row: Dict[str, Any]) -> str:
    for f in ["mmdrXian", "mmdrShi", "mmdrSheng"]:
        v = normalize_text(row.get(f))
        if v:
            return v
    text = normalize_text(row.get("mmdrDeeds")) or normalize_text(row.get("mmdrDeathPlace")) or normalize_text(row.get("mmdrDesc"))
    if not text:
        return ""
    for pat in NATIVE_PATTERNS:
        m = pat.search(text)
        if m:
            return m.group(1).strip("，。；;、 ")
    return ""


def fallback_code_from_saved_fields(row: Dict[str, Any], alias_index: Dict[str, List[Tuple[str, str]]]) -> Tuple[str, str]:
    # numeric IDs first
    for f in [
        "mmdrSbdwId",
        "mmdrXianId",
        "_county_id_effective",
        "_county_id",
        "mmdrShiId",
        "_city_id",
        "mmdrShengId",
        "_province_id",
    ]:
        code = normalize_to_12_digit_numeric(row.get(f))
        if code:
            return code, f"id:{f}"

    # names second
    for f in [
        "mmdrSbdw",
        "mmdrXian",
        "_county_name",
        "mmdrShi",
        "_city_name",
        "mmdrSheng",
        "_province_name",
    ]:
        name = normalize_text(row.get(f))
        if not name:
            continue
        code = best_match_code(name, alias_index)
        if code:
            return code, f"name:{f}"

    return "", "none"


def finalize_code(
    nlp_code: str,
    code_level: Dict[str, str],
    row: Dict[str, Any],
    alias_index: Dict[str, List[Tuple[str, str]]],
) -> Tuple[str, str]:
    # Keep county-level NLP only.
    if nlp_code and code_level.get(nlp_code) == "county":
        return nlp_code, "nlp_county"

    saved_code, saved_route = fallback_code_from_saved_fields(row, alias_index)
    if saved_code:
        return saved_code, f"saved_fallback:{saved_route}"

    if nlp_code:
        return nlp_code, "nlp_non_county_last_resort"

    return UNKNOWN_CODE, "unknown_fallback"


def write_count_table(path: Path, counts: Dict[Tuple[str, str, str], int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(
            f,
            fieldnames=["merge_place_id", "place_name", "place_level", "martyr_count"],
        )
        w.writeheader()
        for (code, name, level), cnt in sorted(counts.items(), key=lambda x: x[1], reverse=True):
            w.writerow(
                {
                    "merge_place_id": code,
                    "place_name": name,
                    "place_level": level,
                    "martyr_count": cnt,
                }
            )


def write_route_summary(path: Path, routes: Counter[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["route", "row_count"])
        w.writeheader()
        for route, cnt in routes.most_common():
            w.writerow({"route": route, "row_count": cnt})


def main() -> None:
    base = Path(
        "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
    )
    input_path = base / "raw_data/chinamartyrs_outputs/chinamartyrs_martyrs_1931_1945.jsonl.gz"
    sac_out = base / "raw_data/chinamartyrs_outputs/chinamartyrs_1931_1945_sacrifice_place_counts_merge_ready.csv"
    nat_out = base / "raw_data/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts_merge_ready.csv"
    sac_route_out = base / "raw_data/chinamartyrs_outputs/chinamartyrs_1931_1945_sacrifice_route_summary_merge_ready.csv"
    nat_route_out = base / "raw_data/chinamartyrs_outputs/chinamartyrs_1931_1945_native_route_summary_merge_ready.csv"

    code_to_name, code_to_level, alias_index = load_area_name_map()
    code_to_name[UNKNOWN_CODE] = UNKNOWN_NAME_SACRIFICE
    code_to_level[UNKNOWN_CODE] = "unknown"

    sac_counts: Dict[Tuple[str, str, str], int] = defaultdict(int)
    nat_counts: Dict[Tuple[str, str, str], int] = defaultdict(int)
    sac_routes: Counter[str] = Counter()
    nat_routes: Counter[str] = Counter()

    rows = 0
    with gzip.open(input_path, "rt", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            rows += 1
            row = json.loads(line)

            sac_phrase = extract_sacrifice_phrase(row)
            sac_nlp_code = best_match_code(sac_phrase, alias_index)
            sac_code, sac_route = finalize_code(sac_nlp_code, code_to_level, row, alias_index)
            sac_routes[sac_route] += 1
            sac_name = code_to_name.get(sac_code, f"代码_{sac_code}")
            sac_level = code_to_level.get(sac_code, "other")
            sac_counts[(sac_code, sac_name, sac_level)] += 1

            nat_phrase = extract_native_phrase(row)
            nat_nlp_code = best_match_code(nat_phrase, alias_index)
            nat_code, nat_route = finalize_code(nat_nlp_code, code_to_level, row, alias_index)
            nat_routes[nat_route] += 1
            nat_name = code_to_name.get(nat_code, UNKNOWN_NAME_NATIVE if nat_code == UNKNOWN_CODE else f"代码_{nat_code}")
            nat_level = code_to_level.get(nat_code, "other")
            nat_counts[(nat_code, nat_name, nat_level)] += 1

    write_count_table(sac_out, sac_counts)
    write_count_table(nat_out, nat_counts)
    write_route_summary(sac_route_out, sac_routes)
    write_route_summary(nat_route_out, nat_routes)

    print(f"rows={rows}")
    print(f"sac_out={sac_out}")
    print(f"nat_out={nat_out}")
    print(f"sac_route_out={sac_route_out}")
    print(f"nat_route_out={nat_route_out}")


if __name__ == "__main__":
    main()

