#!/usr/bin/env python3
"""Build sacrifice-place and native-place count tables for 1931-1945 martyrs."""

from __future__ import annotations

import csv
import gzip
import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple

import requests


ROOT_QY_JSON = (
    "https://www.chinamartyrs.gov.cn/v2/JSON/allQyJSON/000000000000/000000000000.json"
)
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
)

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


@dataclass
class Area:
    area_id: str
    name: str
    level: str
    path_names: str


def strip_suffix(name: str) -> str:
    for suffix in SUFFIXES:
        if name.endswith(suffix) and len(name) > len(suffix):
            return name[: -len(suffix)]
    return name


def load_areas() -> Dict[str, Area]:
    response = requests.get(
        ROOT_QY_JSON,
        headers={"User-Agent": USER_AGENT, "Referer": "https://www.chinamartyrs.gov.cn/"},
        timeout=60,
    )
    response.raise_for_status()
    root = response.json()[0]

    areas: Dict[str, Area] = {}

    def walk(node: Dict[str, Any], names: List[str], depth: int) -> None:
        node_id = str(node.get("orgId") or "")
        node_name = str(node.get("deptName") or "")
        cur_names = names + ([node_name] if node_name else [])
        if node_id:
            if depth <= 1:
                level = "province"
            elif depth == 2:
                level = "city"
            else:
                level = "county"
            areas[node_id] = Area(
                area_id=node_id,
                name=node_name,
                level=level,
                path_names=">".join(cur_names),
            )
        for child in node.get("children") or []:
            walk(child, cur_names, depth + 1)

    for child in root.get("children") or []:
        walk(child, [], 1)
    return areas


def build_alias_index(areas: Dict[str, Area]) -> Tuple[Dict[str, str], Dict[str, List[Tuple[str, str]]]]:
    alias_to_ids: Dict[str, set[str]] = defaultdict(set)
    for area_id, area in areas.items():
        name = area.name.strip()
        if not name:
            continue
        alias_to_ids[name].add(area_id)
        stripped = strip_suffix(name)
        if stripped and stripped != name and len(stripped) >= 2:
            alias_to_ids[stripped].add(area_id)

    unique_alias_to_id = {a: next(iter(ids)) for a, ids in alias_to_ids.items() if len(ids) == 1}
    aliases_by_first_char: Dict[str, List[Tuple[str, str]]] = defaultdict(list)
    for alias, area_id in unique_alias_to_id.items():
        aliases_by_first_char[alias[0]].append((alias, area_id))

    for ch, values in aliases_by_first_char.items():
        values.sort(key=lambda x: len(x[0]), reverse=True)
        aliases_by_first_char[ch] = values

    return unique_alias_to_id, aliases_by_first_char


def normalize_text(text: Any) -> str:
    text = str(text or "").strip()
    if not text:
        return ""
    text = re.sub(r"\s+", "", text)
    text = text.replace("\u3000", "")
    return text


def extract_sacrifice_phrase(row: Dict[str, Any]) -> Tuple[str, str]:
    death_place = normalize_text(row.get("mmdrDeathPlace"))
    deeds = normalize_text(row.get("mmdrDeeds"))

    if death_place:
        src = "death_place_field"
        text = death_place
    elif deeds:
        src = "deeds_fallback"
        text = deeds
    else:
        return "", "empty"

    for pat in SACRIFICE_PATTERNS:
        m = pat.search(text)
        if m:
            phrase = m.group(1).strip("，。；;、 ")
            phrase = re.sub(r"^[0-9零一二三四五六七八九十百千万〇○O年月日时分秒\-]+", "", phrase)
            if phrase:
                return phrase, f"{src}_regex"

    if len(text) <= 30:
        return text, f"{src}_raw"
    return text[:30], f"{src}_raw_trunc"


def extract_native_phrase(row: Dict[str, Any]) -> Tuple[str, str]:
    xian = normalize_text(row.get("mmdrXian"))
    shi = normalize_text(row.get("mmdrShi"))
    sheng = normalize_text(row.get("mmdrSheng"))
    if xian:
        return xian, "field_xian"
    if shi:
        return shi, "field_shi"
    if sheng:
        return sheng, "field_sheng"

    text = normalize_text(row.get("mmdrDeeds")) or normalize_text(row.get("mmdrDeathPlace")) or normalize_text(row.get("mmdrDesc"))
    if not text:
        return "", "empty"

    for pat in NATIVE_PATTERNS:
        m = pat.search(text)
        if m:
            phrase = m.group(1).strip("，。；;、 ")
            phrase = re.sub(r"^[0-9零一二三四五六七八九十百千万〇○O年月日时分秒\-]+", "", phrase)
            if phrase:
                return phrase, "text_regex"
    return "", "text_no_match"


def best_match_area(
    phrase: str,
    areas: Dict[str, Area],
    aliases_by_first_char: Dict[str, List[Tuple[str, str]]],
) -> Tuple[str, str]:
    phrase = normalize_text(phrase)
    if not phrase:
        return "", ""

    seen = set()
    candidates: List[Tuple[int, int, str, str]] = []
    for ch in set(phrase):
        for alias, area_id in aliases_by_first_char.get(ch, []):
            if alias in seen:
                continue
            if alias in phrase:
                seen.add(alias)
                area = areas[area_id]
                depth_score = {"province": 1, "city": 2, "county": 3}.get(area.level, 0)
                candidates.append((len(alias), depth_score, alias, area_id))

    if not candidates:
        return "", ""
    candidates.sort(reverse=True)
    _, _, alias, area_id = candidates[0]
    return area_id, alias


def clamp_raw_label(text: str) -> str:
    text = normalize_text(text)
    text = text.strip("，。；;、:：")
    text = re.sub(r"[（(].*?[）)]", "", text)
    if len(text) > 24:
        text = text[:24]
    return text


def write_count_table(path: Path, counts: Dict[Tuple[str, str, str, str, str], int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "place_id",
                "place_name",
                "place_level",
                "place_path",
                "source_type",
                "martyr_count",
            ],
        )
        writer.writeheader()
        for (place_id, place_name, place_level, place_path, source_type), cnt in sorted(
            counts.items(), key=lambda x: x[1], reverse=True
        ):
            writer.writerow(
                {
                    "place_id": place_id,
                    "place_name": place_name,
                    "place_level": place_level,
                    "place_path": place_path,
                    "source_type": source_type,
                    "martyr_count": cnt,
                }
            )


def write_route_summary(path: Path, route_counts: Counter[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["route", "row_count"])
        writer.writeheader()
        for route, cnt in route_counts.most_common():
            writer.writerow({"route": route, "row_count": cnt})


def main() -> None:
    base = Path(
        "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
    )
    input_path = base / "raw_data/chinamartyrs_outputs/chinamartyrs_martyrs_1931_1945.jsonl.gz"
    sacrifice_out = base / "raw_data/chinamartyrs_outputs/chinamartyrs_1931_1945_sacrifice_place_counts.csv"
    native_out = base / "raw_data/chinamartyrs_outputs/chinamartyrs_1931_1945_native_place_counts.csv"
    sacrifice_route_out = base / "raw_data/chinamartyrs_outputs/chinamartyrs_1931_1945_sacrifice_route_summary.csv"
    native_route_out = base / "raw_data/chinamartyrs_outputs/chinamartyrs_1931_1945_native_route_summary.csv"

    areas = load_areas()
    _, aliases_by_first_char = build_alias_index(areas)

    sacrifice_counts: Dict[Tuple[str, str, str, str, str], int] = defaultdict(int)
    native_counts: Dict[Tuple[str, str, str, str, str], int] = defaultdict(int)
    sacrifice_routes: Counter[str] = Counter()
    native_routes: Counter[str] = Counter()

    rows = 0
    with gzip.open(input_path, "rt", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            rows += 1
            row = json.loads(line)

            # Sacrifice place
            sac_phrase, sac_route = extract_sacrifice_phrase(row)
            sacrifice_routes[sac_route] += 1
            sac_area_id, _ = best_match_area(sac_phrase, areas, aliases_by_first_char)
            if sac_area_id:
                area = areas[sac_area_id]
                key = (sac_area_id, area.name, area.level, area.path_names, "admin_matched")
            else:
                raw = clamp_raw_label(sac_phrase) or "未知"
                key = ("", raw, "raw_text", "", "raw_text")
            sacrifice_counts[key] += 1

            # Native place
            native_phrase, native_route = extract_native_phrase(row)
            native_routes[native_route] += 1
            nat_area_id, _ = best_match_area(native_phrase, areas, aliases_by_first_char)
            if nat_area_id:
                area = areas[nat_area_id]
                key = (nat_area_id, area.name, area.level, area.path_names, "admin_matched")
            else:
                raw = clamp_raw_label(native_phrase) or "未知"
                key = ("", raw, "raw_text", "", "raw_text")
            native_counts[key] += 1

    write_count_table(sacrifice_out, sacrifice_counts)
    write_count_table(native_out, native_counts)
    write_route_summary(sacrifice_route_out, sacrifice_routes)
    write_route_summary(native_route_out, native_routes)

    print(f"rows={rows}")
    print(f"sacrifice_out={sacrifice_out}")
    print(f"native_out={native_out}")
    print(f"sacrifice_route_out={sacrifice_route_out}")
    print(f"native_route_out={native_route_out}")
    print(f"sacrifice_unique_places={len(sacrifice_counts)}")
    print(f"native_unique_places={len(native_counts)}")


if __name__ == "__main__":
    main()

