#!/usr/bin/env python3
"""Scrape full martyr records from Chinamartyrs and export full rows + county counts.

Usage example:
  python3 scripts/scrape_chinamartyrs.py --workers 8
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import threading
import time
from collections import Counter
from collections import OrderedDict
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple

import requests


API_BASE = "https://yinglie.chinamartyrs.gov.cn/web-api/"
ROOT_QY_JSON = (
    "https://www.chinamartyrs.gov.cn/v2/JSON/allQyJSON/000000000000/000000000000.json"
)
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
)


def md5_hex(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def parse_positive_int(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, int):
        return value if value > 0 else None
    if isinstance(value, float):
        iv = int(value)
        return iv if iv > 0 else None
    text = str(value).strip()
    if not text:
        return None
    try:
        iv = int(float(text))
    except ValueError:
        return None
    return iv if iv > 0 else None


def format_partial_date(year: Any, month: Any, day: Any) -> str:
    y = parse_positive_int(year)
    m = parse_positive_int(month)
    d = parse_positive_int(day)
    if not y:
        return ""
    if m and d:
        return f"{y:04d}-{m:02d}-{d:02d}"
    if m:
        return f"{y:04d}-{m:02d}"
    return f"{y:04d}"


def normalize_admin_id(raw_id: Any) -> str:
    text = str(raw_id or "").strip()
    if not text:
        return ""
    if text.isdigit() and len(text) == 6:
        return text + "000000"
    return text


def resolve_effective_county_id(
    county_id_raw: Any,
    city_id_raw: Any,
    county_ids: Any,
) -> Tuple[str, str]:
    county_id = normalize_admin_id(county_id_raw)
    city_id = normalize_admin_id(city_id_raw)

    if county_id and county_id in county_ids:
        route = "county_6_to_12" if str(county_id_raw or "").strip() != county_id else "county_12"
        return county_id, route
    if city_id and city_id in county_ids:
        route = "city_6_to_12_fallback" if str(city_id_raw or "").strip() != city_id else "city_12_fallback"
        return city_id, route
    return "", "unresolved"


class MartyrsApiClient:
    def __init__(self, timeout: int, retries: int, base_sleep: float) -> None:
        self.timeout = timeout
        self.retries = retries
        self.base_sleep = base_sleep
        self._token_lock = threading.Lock()
        self._token = ""
        self._local = threading.local()

    def _session(self) -> requests.Session:
        if not hasattr(self._local, "session"):
            session = requests.Session()
            session.headers.update(
                {
                    "User-Agent": USER_AGENT,
                    "Referer": "https://www.chinamartyrs.gov.cn/",
                }
            )
            self._local.session = session
        return self._local.session

    def _refresh_token_locked(self) -> None:
        response = self._session().post(f"{API_BASE}getToken", timeout=self.timeout)
        response.raise_for_status()
        payload = response.json()
        if payload.get("code") != 200 or not payload.get("data", {}).get("token"):
            raise RuntimeError(f"Unable to fetch token: {payload}")
        self._token = payload["data"]["token"]

    def ensure_token(self, force_refresh: bool = False) -> str:
        with self._token_lock:
            if force_refresh or not self._token:
                self._refresh_token_locked()
            return self._token

    def _signed_headers(self, data: OrderedDict[str, Any], token: str) -> Dict[str, str]:
        timestamp = str(int(time.time() * 1000))
        result = "&".join(f"{k}={'' if v is None else v}" for k, v in data.items())
        autograph = md5_hex(md5_hex(f"{timestamp}{result}{token}"))
        return {
            "Authorization": token,
            "timeStamp": timestamp,
            "autograph": autograph,
        }

    def signed_post(self, endpoint: str, data: OrderedDict[str, Any]) -> Dict[str, Any]:
        last_error: Exception | None = None
        for attempt in range(1, self.retries + 1):
            token = self.ensure_token()
            headers = self._signed_headers(data, token)
            try:
                response = self._session().post(
                    f"{API_BASE}{endpoint}",
                    headers=headers,
                    data=data,
                    timeout=self.timeout,
                )
                response.raise_for_status()
                payload = response.json()
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                if attempt == self.retries:
                    break
                time.sleep(self.base_sleep * attempt)
                continue

            code = payload.get("code")
            msg = str(payload.get("msg", ""))
            if code == 200:
                return payload

            if code == 503 or "没有权限" in msg:
                self.ensure_token(force_refresh=True)
                if attempt == self.retries:
                    last_error = RuntimeError(f"Permission denied after retries: {payload}")
                    break
                time.sleep(self.base_sleep * attempt)
                continue

            if attempt == self.retries:
                last_error = RuntimeError(f"Unexpected API response: {payload}")
                break
            time.sleep(self.base_sleep * attempt)

        raise RuntimeError(f"Request failed for endpoint={endpoint}, data={dict(data)}") from last_error

    def search_page(self, page_num: int, page_size: int) -> Dict[str, Any]:
        data: OrderedDict[str, Any] = OrderedDict(
            [
                ("pageNum", page_num),
                ("pageSize", page_size),
            ]
        )
        return self.signed_post("api/martyrs/search", data)


def load_area_maps() -> Tuple[Dict[str, Dict[str, str]], Dict[str, Dict[str, str]]]:
    response = requests.get(
        ROOT_QY_JSON,
        headers={"User-Agent": USER_AGENT, "Referer": "https://www.chinamartyrs.gov.cn/"},
        timeout=60,
    )
    response.raise_for_status()
    root = response.json()[0]

    all_areas: Dict[str, Dict[str, str]] = {}
    county_map: Dict[str, Dict[str, str]] = {}

    def walk(node: Dict[str, Any], path: List[Dict[str, str]]) -> None:
        node_id = str(node.get("orgId", ""))
        node_name = str(node.get("deptName", ""))
        current_path = path + [{"id": node_id, "name": node_name}]

        if node_id:
            all_areas[node_id] = {
                "id": node_id,
                "name": node_name,
                "path_ids": ">".join(x["id"] for x in current_path),
                "path_names": ">".join(x["name"] for x in current_path if x["name"]),
            }

        children = node.get("children") or []
        if not children and node_id:
            names = [x["name"] for x in current_path if x["name"]]
            ids = [x["id"] for x in current_path]
            if len(names) >= 3:
                province_name = names[0]
                city_name = names[-2]
                county_name = names[-1]
                province_id = ids[0]
                city_id = ids[-2]
            elif len(names) == 2:
                province_name = names[0]
                city_name = names[0]
                county_name = names[1]
                province_id = ids[0]
                city_id = ids[0]
            else:
                province_name = names[0] if names else ""
                city_name = names[0] if names else ""
                county_name = names[0] if names else ""
                province_id = ids[0] if ids else ""
                city_id = ids[0] if ids else ""

            county_map[node_id] = {
                "county_id": node_id,
                "county_name": county_name,
                "city_id": city_id,
                "city_name": city_name,
                "province_id": province_id,
                "province_name": province_name,
                "path_ids": ">".join(ids),
                "path_names": ">".join(names),
            }
            return

        for child in children:
            walk(child, current_path)

    for province in root.get("children") or []:
        walk(province, [])

    return all_areas, county_map


def enrich_row(
    row: Dict[str, Any],
    page_num: int,
    area_map: Dict[str, Dict[str, str]],
    county_map: Dict[str, Dict[str, str]],
) -> Dict[str, Any]:
    row = dict(row)
    province_id = str(row.get("mmdrShengId") or "")
    city_id = str(row.get("mmdrShiId") or "")
    county_id = str(row.get("mmdrXianId") or "")

    row["_page_num"] = page_num
    row["_birth_date"] = format_partial_date(
        row.get("mmdrBirthYear"), row.get("mmdrBirthMonth"), row.get("mmdrBirthDay")
    )
    row["_sacrifice_date"] = format_partial_date(
        row.get("mmdrDeathYear"), row.get("mmdrDeathMonth"), row.get("mmdrDeathDay")
    )

    row["_province_id"] = province_id
    row["_city_id"] = city_id
    row["_county_id"] = county_id

    row["_province_name"] = row.get("mmdrSheng") or area_map.get(province_id, {}).get("name", "")
    row["_city_name"] = row.get("mmdrShi") or area_map.get(city_id, {}).get("name", "")
    row["_county_name"] = row.get("mmdrXian") or area_map.get(county_id, {}).get("name", "")

    effective_county_id, resolve_route = resolve_effective_county_id(
        county_id_raw=county_id,
        city_id_raw=city_id,
        county_ids=county_map,
    )
    row["_county_id_effective"] = effective_county_id
    row["_county_id_resolve_route"] = resolve_route

    county_meta = county_map.get(effective_county_id, {})
    row["_county_path_names"] = county_meta.get("path_names", "")
    row["_county_path_ids"] = county_meta.get("path_ids", "")
    return row


def load_checkpoint(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {"completed_pages": []}
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_checkpoint(path: Path, completed_pages: Iterable[int], total_pages: int) -> None:
    payload = {
        "total_pages": total_pages,
        "completed_pages": sorted(set(int(x) for x in completed_pages)),
        "updated_at_unix": int(time.time()),
    }
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    with tmp_path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    tmp_path.replace(path)


def build_count_csv(
    output_jsonl_gz: Path,
    count_csv: Path,
    county_map: Dict[str, Dict[str, str]],
) -> Tuple[int, int, int, Dict[str, int], Dict[str, int]]:
    counts: Dict[str, int] = {k: 0 for k in county_map.keys()}
    unknown_id_counts: Counter[str] = Counter()
    blank_county_id_rows = 0
    route_counts: Counter[str] = Counter()
    total_rows = 0
    county_ids = set(county_map.keys())

    with gzip.open(output_jsonl_gz, "rt", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            total_rows += 1
            row = json.loads(line)
            county_id_raw = row.get("_county_id") or row.get("mmdrXianId")
            city_id_raw = row.get("_city_id") or row.get("mmdrShiId")
            effective_county_id, resolve_route = resolve_effective_county_id(
                county_id_raw=county_id_raw,
                city_id_raw=city_id_raw,
                county_ids=county_ids,
            )
            route_counts[resolve_route] += 1

            if effective_county_id:
                counts[effective_county_id] = counts.get(effective_county_id, 0) + 1
            else:
                county_id = str(county_id_raw or "").strip()
                city_id = str(city_id_raw or "").strip()
                if not county_id and not city_id:
                    blank_county_id_rows += 1
                elif county_id:
                    unknown_id_counts[county_id] += 1
                elif city_id:
                    unknown_id_counts[f"[city]{city_id}"] += 1

    count_csv.parent.mkdir(parents=True, exist_ok=True)
    with count_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "county_id",
                "county_name",
                "city_id",
                "city_name",
                "province_id",
                "province_name",
                "path_ids",
                "path_names",
                "martyr_count",
            ],
        )
        writer.writeheader()
        for county_id, meta in sorted(
            county_map.items(), key=lambda x: (x[1].get("province_name", ""), x[1].get("city_name", ""), x[1].get("county_name", ""))
        ):
            writer.writerow(
                {
                    "county_id": county_id,
                    "county_name": meta.get("county_name", ""),
                    "city_id": meta.get("city_id", ""),
                    "city_name": meta.get("city_name", ""),
                    "province_id": meta.get("province_id", ""),
                    "province_name": meta.get("province_name", ""),
                    "path_ids": meta.get("path_ids", ""),
                    "path_names": meta.get("path_names", ""),
                    "martyr_count": counts.get(county_id, 0),
                }
            )
    known_county_rows = sum(counts.values())
    return (
        total_rows,
        known_county_rows,
        blank_county_id_rows,
        dict(unknown_id_counts),
        dict(route_counts),
    )


def build_nonstandard_county_csv(
    output_path: Path,
    unknown_id_counts: Dict[str, int],
    blank_county_id_rows: int,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["county_id", "martyr_count", "category"],
        )
        writer.writeheader()
        if blank_county_id_rows > 0:
            writer.writerow(
                {
                    "county_id": "",
                    "martyr_count": blank_county_id_rows,
                    "category": "MISSING_COUNTY_ID",
                }
            )
        for county_id, cnt in sorted(unknown_id_counts.items(), key=lambda x: x[1], reverse=True):
            writer.writerow(
                {
                    "county_id": county_id,
                    "martyr_count": cnt,
                    "category": "NONSTANDARD_OR_UNMAPPED_COUNTY_ID",
                }
            )


def build_route_summary_csv(output_path: Path, route_counts: Dict[str, int]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["resolve_route", "row_count"],
        )
        writer.writeheader()
        for route, cnt in sorted(route_counts.items(), key=lambda x: x[1], reverse=True):
            writer.writerow({"resolve_route": route, "row_count": cnt})


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scrape Chinamartyrs full records.")
    parser.add_argument(
        "--output",
        default="raw_data/chinamartyrs_outputs/chinamartyrs_martyrs_full.jsonl.gz",
        help="Output gzip JSONL path.",
    )
    parser.add_argument(
        "--counts-output",
        default="raw_data/chinamartyrs_outputs/chinamartyrs_county_counts.csv",
        help="County count CSV output path.",
    )
    parser.add_argument(
        "--nonstandard-counts-output",
        default="raw_data/chinamartyrs_outputs/chinamartyrs_nonstandard_county_counts.csv",
        help="CSV for missing/nonstandard county IDs.",
    )
    parser.add_argument(
        "--route-summary-output",
        default="raw_data/chinamartyrs_outputs/chinamartyrs_county_resolve_routes.csv",
        help="CSV summary of which county-id resolve route was used.",
    )
    parser.add_argument("--workers", type=int, default=8, help="Concurrent workers.")
    parser.add_argument("--page-size", type=int, default=500, help="API page size (max 500).")
    parser.add_argument("--start-page", type=int, default=1, help="First page to scrape.")
    parser.add_argument(
        "--end-page",
        type=int,
        default=0,
        help="Last page to scrape. 0 means scrape to final page.",
    )
    parser.add_argument(
        "--checkpoint",
        default="raw_data/chinamartyrs_outputs/chinamartyrs_checkpoint.json",
        help="Checkpoint path for completed pages.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite output/checkpoint instead of resuming.",
    )
    parser.add_argument("--timeout", type=int, default=60, help="HTTP timeout seconds.")
    parser.add_argument("--retries", type=int, default=6, help="Retry times per request.")
    parser.add_argument(
        "--base-sleep",
        type=float,
        default=0.8,
        help="Base sleep seconds between retries (linear backoff).",
    )
    parser.add_argument(
        "--progress-every",
        type=int,
        default=50,
        help="Print progress every N completed pages.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_path = Path(args.output)
    count_csv_path = Path(args.counts_output)
    nonstandard_count_csv_path = Path(args.nonstandard_counts_output)
    route_summary_csv_path = Path(args.route_summary_output)
    checkpoint_path = Path(args.checkpoint)

    if args.page_size > 500:
        raise ValueError("--page-size cannot exceed 500 for this API.")
    if args.start_page < 1:
        raise ValueError("--start-page must be >= 1.")
    if args.workers < 1:
        raise ValueError("--workers must be >= 1.")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)

    if args.overwrite:
        if output_path.exists():
            output_path.unlink()
        if checkpoint_path.exists():
            checkpoint_path.unlink()
    elif output_path.exists() and not checkpoint_path.exists():
        raise RuntimeError(
            f"{output_path} already exists but {checkpoint_path} is missing. "
            "Use --overwrite to restart cleanly."
        )

    print("Loading area hierarchy...")
    area_map, county_map = load_area_maps()
    print(f"Loaded {len(area_map)} areas, {len(county_map)} leaf counties.")

    client = MartyrsApiClient(timeout=args.timeout, retries=args.retries, base_sleep=args.base_sleep)
    first_payload = client.search_page(page_num=1, page_size=args.page_size)
    total_records = int(first_payload.get("total", 0))
    total_pages = max(1, (total_records + args.page_size - 1) // args.page_size)
    end_page = args.end_page if args.end_page > 0 else total_pages
    if end_page > total_pages:
        end_page = total_pages

    print(
        f"Total records={total_records}, total pages={total_pages}, "
        f"target pages={args.start_page}-{end_page}."
    )

    state = load_checkpoint(checkpoint_path)
    completed_pages = set(int(x) for x in state.get("completed_pages", []))
    target_pages = [p for p in range(args.start_page, end_page + 1) if p not in completed_pages]
    print(f"Already completed pages={len(completed_pages)}, pending pages={len(target_pages)}.")

    if not target_pages:
        print("No pending pages. Building county count CSV from existing output...")
        total_rows, known_rows, blank_rows, unknown_counts, route_counts = build_count_csv(
            output_path, count_csv_path, county_map
        )
        build_nonstandard_county_csv(nonstandard_count_csv_path, unknown_counts, blank_rows)
        build_route_summary_csv(route_summary_csv_path, route_counts)
        print(
            f"Done. Existing rows={total_rows}, mapped_to_standard_county={known_rows}, "
            f"blank_county_id={blank_rows}, unknown_county_id_rows={sum(unknown_counts.values())}, "
            f"county CSV={count_csv_path}, nonstandard CSV={nonstandard_count_csv_path}, "
            f"route summary CSV={route_summary_csv_path}"
        )
        return

    mode = "at" if output_path.exists() else "wt"
    processed_pages = 0
    written_rows = 0
    started_at = time.time()

    with gzip.open(output_path, mode, encoding="utf-8") as out:
        if 1 in target_pages:
            rows = first_payload.get("rows") or []
            for row in rows:
                enriched = enrich_row(row, 1, area_map, county_map)
                out.write(json.dumps(enriched, ensure_ascii=False) + "\n")
            written_rows += len(rows)
            completed_pages.add(1)
            processed_pages += 1
            target_pages.remove(1)
            save_checkpoint(checkpoint_path, completed_pages, total_pages)

        def fetch_page(page_num: int) -> Tuple[int, List[Dict[str, Any]]]:
            payload = client.search_page(page_num=page_num, page_size=args.page_size)
            rows = payload.get("rows") or []
            return page_num, rows

        futures = {}
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            pages_iter = iter(target_pages)
            while True:
                while len(futures) < args.workers:
                    try:
                        page = next(pages_iter)
                    except StopIteration:
                        break
                    futures[executor.submit(fetch_page, page)] = page

                if not futures:
                    break

                done, _ = wait(futures.keys(), return_when=FIRST_COMPLETED)
                for fut in done:
                    page = futures.pop(fut)
                    page_num, rows = fut.result()
                    if page_num != page:
                        raise RuntimeError(f"Page mismatch: expected={page}, got={page_num}")

                    for row in rows:
                        enriched = enrich_row(row, page_num, area_map, county_map)
                        out.write(json.dumps(enriched, ensure_ascii=False) + "\n")

                    written_rows += len(rows)
                    completed_pages.add(page_num)
                    processed_pages += 1

                    if processed_pages % args.progress_every == 0:
                        elapsed = time.time() - started_at
                        speed = processed_pages / elapsed if elapsed > 0 else 0
                        print(
                            f"Completed pages={processed_pages}, written rows={written_rows}, "
                            f"speed={speed:.2f} pages/s, last_page={page_num}"
                        )
                        save_checkpoint(checkpoint_path, completed_pages, total_pages)

        save_checkpoint(checkpoint_path, completed_pages, total_pages)

    print(
        f"Scrape done. Newly written rows={written_rows}. "
        f"Output={output_path}, checkpoint={checkpoint_path}"
    )

    print("Building county count CSV...")
    total_rows, known_rows, blank_rows, unknown_counts, route_counts = build_count_csv(
        output_path, count_csv_path, county_map
    )
    build_nonstandard_county_csv(nonstandard_count_csv_path, unknown_counts, blank_rows)
    build_route_summary_csv(route_summary_csv_path, route_counts)
    print(
        f"County count CSV done. total_rows_in_output={total_rows}, "
        f"mapped_to_standard_county={known_rows}, blank_county_id={blank_rows}, "
        f"unknown_county_id_rows={sum(unknown_counts.values())}, file={count_csv_path}, "
        f"nonstandard_file={nonstandard_count_csv_path}, route_summary_file={route_summary_csv_path}"
    )


if __name__ == "__main__":
    main()
