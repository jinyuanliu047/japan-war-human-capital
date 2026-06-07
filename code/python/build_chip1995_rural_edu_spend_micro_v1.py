#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
HH_SRC = PROJ / "data/raw/1995/1995_DS0002_rural_household/DS0002_rural_household/03012-0002-Data.dta"
IND_SRC = PROJ / "data/raw/1995/1995_DS0001_rural_individual/DS0001_rural_individual/03012-0001-Data.dta"
COUNTY_TREAT = PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta"
OUT_DTA = PROJ / "data/temp/chip1995_rural_edu_spend_micro_v1.dta"
OUT_CSV = PROJ / "data/temp/chip1995_rural_edu_spend_micro_v1.csv"
AUDIT_CSV = PROJ / "data/temp/chip1995_rural_county_match_audit_v1.csv"


def main() -> None:
    hh, _ = pyreadstat.read_dta(
        str(HH_SRC),
        usecols=["A1", "B101", "NHH", "B709", "B709A", "B709B"],
    )
    ind, _ = pyreadstat.read_dta(
        str(IND_SRC),
        usecols=["A1", "B101", "B103", "B104", "B105", "B107", "B110A"],
    )

    for df in [hh, ind]:
        for col in ["A1", "B101"]:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    head = ind.loc[pd.to_numeric(ind["B103"], errors="coerce") == 1].copy()
    head = head.sort_values(["A1", "B101"]).drop_duplicates(["A1", "B101"])
    head["head_birth_i"] = 1995 - pd.to_numeric(head["B105"], errors="coerce")
    head["head_female"] = np.where(
        pd.to_numeric(head["B104"], errors="coerce").isin([1, 2]),
        (pd.to_numeric(head["B104"], errors="coerce") == 2).astype(float),
        np.nan,
    )
    head["head_working"] = np.where(
        pd.to_numeric(head["B107"], errors="coerce").isin(range(0, 10)),
        pd.to_numeric(head["B107"], errors="coerce").isin([1, 2]).astype(float),
        np.nan,
    )
    head["head_eduy"] = np.where(
        pd.to_numeric(head["B110A"], errors="coerce").between(0, 30),
        pd.to_numeric(head["B110A"], errors="coerce"),
        np.nan,
    )
    head = head[["A1", "B101", "head_birth_i", "head_female", "head_working", "head_eduy"]].copy()

    out = hh.merge(head, on=["A1", "B101"], how="left")
    for col in ["NHH", "B709", "B709A", "B709B"]:
        out[col] = pd.to_numeric(out[col], errors="coerce")

    out["countyid_curr6"] = pd.to_numeric(out["A1"], errors="coerce").astype("Int64")
    out["countyid_curr6"] = out["countyid_curr6"].astype(str).str.replace("<NA>", "", regex=False).str.zfill(6)
    out.loc[out["countyid_curr6"] == "000000", "countyid_curr6"] = pd.NA

    treat = pd.read_stata(COUNTY_TREAT, convert_categoricals=False)
    treat["countyid_curr6"] = pd.to_numeric(treat["countyid_curr6"], errors="coerce").astype("Int64")
    treat = treat.dropna(subset=["countyid_curr6"]).copy()
    treat["countyid_curr6"] = treat["countyid_curr6"].astype(int).map(lambda x: f"{x:06d}")
    keep_treat = ["countyid_curr6", "martyr_count_1931_1945", "pop_1953", "martyr_per100k_1953", "ln_martyr_per100k_1953"]
    out = out.merge(treat[keep_treat], on="countyid_curr6", how="left")

    audit = (
        out[["countyid_curr6", "ln_martyr_per100k_1953"]]
        .drop_duplicates()
        .assign(match_status=lambda d: np.where(d["ln_martyr_per100k_1953"].notna(), "matched_current_county", "unmatched_county"))
        .sort_values("countyid_curr6")
    )
    audit.to_csv(AUDIT_CSV, index=False, encoding="utf-8-sig")

    out["edu_total"] = out["B709"]
    out["schooling_fee"] = out["B709A"]
    out["training_cost"] = out["B709B"]
    out["birth_i"] = pd.to_numeric(out["head_birth_i"], errors="coerce")
    out = out[out["birth_i"].between(1920, 1977) & (out["birth_i"] != 1939)].copy()
    out["post"] = (out["birth_i"] >= 1940).astype(float)

    keep = [
        "A1",
        "B101",
        "countyid_curr6",
        "birth_i",
        "post",
        "NHH",
        "head_female",
        "head_working",
        "head_eduy",
        "edu_total",
        "schooling_fee",
        "training_cost",
        "martyr_count_1931_1945",
        "pop_1953",
        "martyr_per100k_1953",
        "ln_martyr_per100k_1953",
    ]
    out = out[keep].copy()
    OUT_DTA.parent.mkdir(parents=True, exist_ok=True)
    out.to_stata(OUT_DTA, write_index=False, version=118)
    out.to_csv(OUT_CSV, index=False, encoding="utf-8-sig")


if __name__ == "__main__":
    main()
