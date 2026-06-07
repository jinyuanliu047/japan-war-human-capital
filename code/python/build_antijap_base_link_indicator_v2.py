#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import pandas as pd


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
PLACES = PROJ / "data/temp/antijap_base_link_explicit_places_v1.csv"
CW = PROJ / "data/temp/county_to_pref4_crosswalk_v1.csv"
OUT = PROJ / "data/temp/antijap_base_link_indicator_v2.csv"
OUT_DTA = PROJ / "data/temp/antijap_base_link_indicator_v2.dta"


def code6(x) -> str:
    s = str(x).replace(".0", "").strip()
    digits = "".join(ch for ch in s if ch.isdigit())
    return digits.zfill(6)[-6:] if digits else ""


def main() -> None:
    cw = pd.read_csv(CW)
    cw["countyid_curr6"] = cw["countyid_curr6"].map(code6)
    cw["pref4_curr"] = pd.to_numeric(cw["pref4_curr"], errors="coerce").astype("Int64")

    places = pd.read_csv(PLACES, dtype=str)
    county_codes = {code6(x) for x in places.loc[places["level"] == "county", "code"]}
    pref_codes = {int(x) for x in places.loc[places["level"] == "prefecture", "code"] if str(x).isdigit()}

    cw["base_link_any"] = 0
    cw.loc[cw["countyid_curr6"].isin(county_codes), "base_link_any"] = 1
    cw.loc[cw["pref4_curr"].isin(pref_codes), "base_link_any"] = 1

    out = cw[["countyid_curr6", "pref4_curr", "base_link_any"]].drop_duplicates("countyid_curr6")
    out.to_csv(OUT, index=False, encoding="utf-8-sig")
    out.to_stata(OUT_DTA, write_index=False, version=118)


if __name__ == "__main__":
    main()
