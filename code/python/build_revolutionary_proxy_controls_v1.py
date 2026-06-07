#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import gzip
import json
import re

import numpy as np
import pandas as pd


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
JSONL = PROJ / "data/scrape/chinamartyrs_outputs/chinamartyrs_martyrs_full.jsonl.gz"
TREAT = PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta"
OUT = PROJ / "data/temp/revolutionary_proxy_controls_v1.csv"
OUT_DTA = PROJ / "data/temp/revolutionary_proxy_controls_v1.dta"
AUDIT = PROJ / "data/temp/revolutionary_proxy_audit_v1.csv"

KOREA_RE = re.compile(r"抗美援朝|赴朝|入朝|朝鲜战场|朝鲜战争")
LONGMARCH_RE = re.compile(r"长征")


def code6(x) -> str:
    if x is None:
        return ""
    s = str(x).replace(".0", "").strip()
    if not s or s.lower() == "nan":
        return ""
    digits = "".join(ch for ch in s if ch.isdigit())
    if not digits:
        return ""
    out = digits.zfill(6)[-6:]
    return out if len(out) == 6 else ""


def main() -> None:
    rows = []
    n_total = 0
    n_korea = 0
    n_longmarch = 0
    with gzip.open(JSONL, "rt", encoding="utf-8") as f:
        for line in f:
            n_total += 1
            obj = json.loads(line)
            county = code6(obj.get("mmdrXianId"))
            if county == "":
                continue
            texts = [
                obj.get("mmdrDeeds"),
                obj.get("mmdrDeathCause"),
                obj.get("mmdrDeathPlace"),
                obj.get("mmdrUnit"),
                obj.get("mmdrJob"),
                obj.get("mmdrBuryPlace"),
            ]
            txt = " ".join(str(x) for x in texts if x)
            korea = int(bool(KOREA_RE.search(txt)))
            longmarch = int(bool(LONGMARCH_RE.search(txt)))
            if korea == 0 and longmarch == 0:
                continue
            n_korea += korea
            n_longmarch += longmarch
            rows.append({"countyid_curr6": county, "korea_hit": korea, "longmarch_hit": longmarch})

    df = pd.DataFrame(rows)
    if df.empty:
        raise RuntimeError("no revolutionary proxy matches found")

    agg = df.groupby("countyid_curr6", as_index=False).agg(
        korea_war_martyr_count=("korea_hit", "sum"),
        longmarch_martyr_count=("longmarch_hit", "sum"),
    )

    treat = pd.read_stata(TREAT, convert_categoricals=False)
    treat["countyid_curr6"] = treat["countyid_curr6"].map(code6)
    treat = treat[["countyid_curr6", "pop_1953"]].drop_duplicates("countyid_curr6")
    agg = agg[(agg["countyid_curr6"].str.len() == 6) & (agg["countyid_curr6"] != "000000")].copy()
    agg = agg.merge(treat, on="countyid_curr6", how="inner")
    agg["korea_war_martyr_per100k"] = np.where(agg["pop_1953"] > 0, agg["korea_war_martyr_count"] / agg["pop_1953"] * 100000.0, np.nan)
    agg["longmarch_martyr_per100k"] = np.where(agg["pop_1953"] > 0, agg["longmarch_martyr_count"] / agg["pop_1953"] * 100000.0, np.nan)
    agg["ln_korea_war_martyr_count"] = np.log1p(agg["korea_war_martyr_count"])
    agg["ln_longmarch_martyr_count"] = np.log1p(agg["longmarch_martyr_count"])
    agg["ln_korea_war_martyr_per100k"] = np.log1p(agg["korea_war_martyr_per100k"])
    agg["ln_longmarch_martyr_per100k"] = np.log1p(agg["longmarch_martyr_per100k"])

    agg.to_csv(OUT, index=False, encoding="utf-8-sig")
    agg.to_stata(OUT_DTA, write_index=False, version=118)

    audit = pd.DataFrame(
        {
            "metric": ["total_records", "korea_hits", "longmarch_hits", "county_with_korea", "county_with_longmarch"],
            "value": [
                n_total,
                n_korea,
                n_longmarch,
                int((agg["korea_war_martyr_count"] > 0).sum()),
                int((agg["longmarch_martyr_count"] > 0).sum()),
            ],
        }
    )
    audit.to_csv(AUDIT, index=False, encoding="utf-8-sig")


if __name__ == "__main__":
    main()
