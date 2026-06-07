#!/usr/bin/env python3
"""Build hybrid DID panel:
- schoolage / wartime use sacrifice-place intensity
- postwar uses native-place intensity
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


def main() -> None:
    base = Path(
        "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
    )
    native_path = base / "data/temp/did_1982_county_birthyr_martyr_native_v2.dta"
    sacrifice_path = base / "data/temp/did_1982_county_birthyr_martyr_sacrifice_v2.dta"
    out_csv = base / "data/temp/did_1982_county_birthyr_martyr_hybrid_v3.csv"
    out_dta = base / "data/temp/did_1982_county_birthyr_martyr_hybrid_v3.dta"

    n = pd.read_stata(native_path, convert_categoricals=False)
    s = pd.read_stata(sacrifice_path, convert_categoricals=False)

    key = ["countyid_curr6", "birthyr"]
    s_keep = [
        "countyid_curr6",
        "birthyr",
        "martyr_sacrifice_count_1931_1945",
        "ln_martyr_sacrifice_count",
        "did_sch_sac",
        "did_war_sac",
        "did_post_sac",
    ]
    s = s[s_keep].copy()

    out = n.merge(s, on=key, how="left", validate="1:1")

    # If any missing after merge, fill with zero.
    for c in [
        "martyr_sacrifice_count_1931_1945",
        "ln_martyr_sacrifice_count",
        "did_sch_sac",
        "did_war_sac",
        "did_post_sac",
    ]:
        if c in out.columns:
            out[c] = out[c].fillna(0.0)

    # Alternative postwar-school-entry cohort definition:
    # if concern is schooling-age exposure to post-war institutions (start around 1949),
    # then treated cohorts are those reaching age 6 in/after 1949 -> birthyr >= 1943.
    out["postwar_schentry_49"] = ((out["birthyr"] >= 1943) & (out["birthyr"] <= 1955)).astype(int)
    out["sample_postwar_schentry_49"] = ((out["birthyr"] >= 1936) & (out["birthyr"] <= 1955)).astype(int)
    out["did_post49_native"] = out["ln_martyr_native_count"] * out["postwar_schentry_49"]

    out.to_csv(out_csv, index=False)
    out.to_stata(out_dta, write_index=False, version=118)

    print(f"rows={len(out)}")
    print(f"counties={out['countyid_curr6'].nunique()}")
    print(f"birthyr_range={int(out['birthyr'].min())}-{int(out['birthyr'].max())}")
    print(f"output_csv={out_csv}")
    print(f"output_dta={out_dta}")


if __name__ == "__main__":
    main()
