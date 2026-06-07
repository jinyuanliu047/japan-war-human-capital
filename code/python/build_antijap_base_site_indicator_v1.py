#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import pandas as pd


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
SRC = PROJ / "data/raw/heritatge.xlsx"
OUT = PROJ / "data/temp/antijap_base_site_indicator_v1.csv"
OUT_DTA = PROJ / "data/temp/antijap_base_site_indicator_v1.dta"


def code6(x) -> str:
    s = str(x).replace(".0", "").strip()
    digits = "".join(ch for ch in s if ch.isdigit())
    return digits.zfill(6)[-6:] if digits else ""


def main() -> None:
    df = pd.read_excel(SRC)
    mask = df["heritagename"].astype(str).str.contains("抗日根据地|根据地", na=False)
    out = df.loc[mask, ["countyid", "prefectureid", "heritagename"]].copy()
    out["countyid_curr6"] = out["countyid"].map(code6)
    out["pref4_curr"] = pd.to_numeric(out["prefectureid"], errors="coerce")
    out["base_site_any"] = 1
    out = out[["countyid_curr6", "pref4_curr", "heritagename", "base_site_any"]].drop_duplicates()
    out.to_csv(OUT, index=False, encoding="utf-8-sig")
    out.to_stata(OUT_DTA, write_index=False, version=118)


if __name__ == "__main__":
    main()
