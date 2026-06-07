#!/usr/bin/env python3
"""Rebuild counts with rule: county first, else fallback to city code."""

from __future__ import annotations

import csv
import gzip
import json
from collections import Counter
from pathlib import Path
from typing import Any, Dict

import requests


ROOT_QY_JSON = (
    "https://www.chinamartyrs.gov.cn/v2/JSON/allQyJSON/000000000000/000000000000.json"
)
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
)


def normalize_admin_id(raw_id: Any) -> str:
    text = str(raw_id or "").strip()
    if not text:
        return ""
    if text.isdigit() and len(text) == 6:
        return text + "000000"
    return text


def load_area_map() -> Dict[str, Dict[str, str]]:
    response = requests.get(
        ROOT_QY_JSON,
        headers={"User-Agent": USER_AGENT, "Referer": "https://www.chinamartyrs.gov.cn/"},
        timeout=60,
    )
    response.raise_for_status()
    root = response.json()[0]

    area_map: Dict[str, Dict[str, str]] = {}

    def walk(node: Dict[str, Any], path_names: list[str], path_ids: list[str]) -> None:
        node_id = str(node.get("orgId") or "")
        node_name = str(node.get("deptName") or "")
        cur_names = path_names + ([node_name] if node_name else [])
        cur_ids = path_ids + ([node_id] if node_id else [])
        if node_id:
            area_map[node_id] = {
                "name": node_name,
                "path_names": ">".join(cur_names),
                "path_ids": ">".join(cur_ids),
            }
        for child in node.get("children") or []:
            walk(child, cur_names, cur_ids)

    for child in root.get("children") or []:
        walk(child, [], [])
    return area_map


def main() -> None:
    base = Path(
        "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
    )
    input_path = base / "raw_data/chinamartyrs_outputs/chinamartyrs_martyrs_full.jsonl.gz"
    output_counts = base / "raw_data/chinamartyrs_outputs/chinamartyrs_effective_area_counts.csv"
    output_unresolved = base / "raw_data/chinamartyrs_outputs/chinamartyrs_effective_area_unresolved.csv"

    area_map = load_area_map()
    counts: Counter[str] = Counter()
    unresolved: Counter[str] = Counter()
    total = 0

    with gzip.open(input_path, "rt", encoding="utf-8") as f:
        for line in f:
            row = json.loads(line)
            total += 1
            county_raw = row.get("_county_id") or row.get("mmdrXianId")
            city_raw = row.get("_city_id") or row.get("mmdrShiId")
            county = normalize_admin_id(county_raw)
            city = normalize_admin_id(city_raw)

            effective = county or city
            if effective:
                counts[effective] += 1
            else:
                unresolved["MISSING_COUNTY_AND_CITY"] += 1

    output_counts.parent.mkdir(parents=True, exist_ok=True)
    with output_counts.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "effective_area_id",
                "area_name",
                "path_names",
                "path_ids",
                "martyr_count",
                "area_known_in_admin_tree",
            ],
        )
        writer.writeheader()
        for area_id, cnt in sorted(counts.items(), key=lambda x: x[1], reverse=True):
            meta = area_map.get(area_id, {})
            writer.writerow(
                {
                    "effective_area_id": area_id,
                    "area_name": meta.get("name", ""),
                    "path_names": meta.get("path_names", ""),
                    "path_ids": meta.get("path_ids", ""),
                    "martyr_count": cnt,
                    "area_known_in_admin_tree": "1" if area_id in area_map else "0",
                }
            )

    with output_unresolved.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["reason", "row_count"])
        writer.writeheader()
        for reason, cnt in sorted(unresolved.items(), key=lambda x: x[1], reverse=True):
            writer.writerow({"reason": reason, "row_count": cnt})

    print(f"total_rows={total}")
    print(f"resolved_with_county_or_city={sum(counts.values())}")
    print(f"unresolved={sum(unresolved.values())}")
    print(f"effective_area_count_file={output_counts}")
    print(f"effective_area_unresolved_file={output_unresolved}")


if __name__ == "__main__":
    main()

