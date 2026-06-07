#!/usr/bin/env python3
"""Build sacrifice-place treatment DID panel from existing county-birthyear panel.

Rules requested by user:
- if county/city can be recognized, use county/city code
- if not recognized, keep original scraped location (saved to unresolved file)
"""

from __future__ import annotations

import math
import re
from collections import Counter
from pathlib import Path

import pandas as pd


def extract_code6(place_id: str) -> tuple[str, str]:
    pid = "" if pd.isna(place_id) else str(place_id).strip()
    if not pid:
        return "", "missing_place_id"
    if re.fullmatch(r"\d{12}", pid):
        return pid[:6], "id12_prefix6"

    m6 = re.match(r"^(\d{6})", pid)
    if m6:
        return m6.group(1), "numeric_prefix6"

    # Special development-zone IDs like 4403A2000000: fallback to city code 440300.
    m4a = re.match(r"^(\d{4})[A-Za-z]\d+", pid)
    if m4a:
        return m4a.group(1) + "00", "special_zone_city_fallback"

    return "", "unresolved_non_numeric"


def main() -> None:
    base = Path(
        "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
    )

    panel_in = base / "data/temp/did_1982_county_birthyr_martyr_native_v2.dta"
    sac_in = base / "data/scrape/chinamartyrs_outputs/chinamartyrs_1931_1945_sacrifice_place_counts_clean_county_fallback.csv"

    out_csv = base / "data/temp/did_1982_county_birthyr_martyr_sacrifice_v2.csv"
    out_dta = base / "data/temp/did_1982_county_birthyr_martyr_sacrifice_v2.dta"
    out_route = base / "data/temp/sacrifice_place_to_code6_routes_v2.csv"
    out_unresolved = base / "data/temp/sacrifice_place_unresolved_kept_raw_v2.csv"

    panel = pd.read_stata(panel_in, convert_categoricals=False)

    s = pd.read_csv(sac_in, dtype={"place_id": str})
    if "martyr_count" not in s.columns:
        raise ValueError("martyr_count column not found in sacrifice input.")

    routes = Counter()
    code_list = []
    for row in s.itertuples(index=False):
        code6, route = extract_code6(row.place_id)
        routes[route] += int(row.martyr_count) if not pd.isna(row.martyr_count) else 0
        code_list.append(code6)
    s["countyid_curr6"] = code_list

    unresolved = s[s["countyid_curr6"] == ""].copy()
    unresolved_cols = [c for c in ["place_id", "place_name", "place_level", "place_path", "martyr_count"] if c in unresolved.columns]
    unresolved = unresolved[unresolved_cols].sort_values("martyr_count", ascending=False)
    unresolved.to_csv(out_unresolved, index=False)

    s2 = s[s["countyid_curr6"] != ""].copy()
    s2["martyr_count"] = pd.to_numeric(s2["martyr_count"], errors="coerce").fillna(0.0)
    treat = (
        s2.groupby("countyid_curr6", as_index=False)["martyr_count"]
        .sum()
        .rename(columns={"martyr_count": "martyr_sacrifice_count_1931_1945"})
    )

    out = panel.merge(treat, on="countyid_curr6", how="left")
    out["martyr_sacrifice_count_1931_1945"] = out["martyr_sacrifice_count_1931_1945"].fillna(0.0)
    out["ln_martyr_sacrifice_count"] = out["martyr_sacrifice_count_1931_1945"].map(lambda x: math.log1p(float(x)))

    out["did_sch_sac"] = out["ln_martyr_sacrifice_count"] * out["schoolage_war"]
    out["did_war_sac"] = out["ln_martyr_sacrifice_count"] * out["wartime_birth"]
    out["did_post_sac"] = out["ln_martyr_sacrifice_count"] * out["postwar_birth"]

    out.to_csv(out_csv, index=False)
    out.to_stata(out_dta, write_index=False, version=118)

    route_df = pd.DataFrame(
        [{"route": k, "martyr_count_sum": v} for k, v in sorted(routes.items(), key=lambda x: x[1], reverse=True)]
    )
    route_df.to_csv(out_route, index=False)

    print(f"panel_rows={len(out)}")
    print(f"county_n={out['countyid_curr6'].nunique()}")
    print(f"positive_treat_county_n={out[out['martyr_sacrifice_count_1931_1945']>0]['countyid_curr6'].nunique()}")
    print(f"positive_treat_row_share={(out['martyr_sacrifice_count_1931_1945']>0).mean():.4f}")
    print(f"unresolved_places_n={len(unresolved)} unresolved_martyr_sum={unresolved['martyr_count'].sum() if len(unresolved) else 0}")
    print(f"output_csv={out_csv}")
    print(f"output_dta={out_dta}")
    print(f"route_summary={out_route}")
    print(f"unresolved_file={out_unresolved}")


if __name__ == "__main__":
    main()
