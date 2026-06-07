from __future__ import annotations

import re
from pathlib import Path

import numpy as np
import pandas as pd


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
RAW_XLSX = PROJ / "data/raw/heritatge.xlsx"
CROSSWALK = PROJ / "data/temp/countyid6_name_crosswalk_v1.csv"
OUT_COUNTY = PROJ / "data/temp/heritage_county_level_v2.csv"
OUT_CONTROLS_CSV = PROJ / "data/temp/county_controls_full_heritage_v2.csv"
OUT_CONTROLS_DTA = PROJ / "data/temp/county_controls_full_heritage_v2.dta"
OUT_AUDIT = PROJ / "data/temp/heritage_county_mapping_audit_v2.csv"


# High-confidence manual recodes only.
MANUAL_RECODE = {
    "120119": ("120225", "rename_unique_manual"),   # 蓟州区 -> 蓟县
    "370505": ("370521", "rename_unique_manual"),   # 垦利区 -> 垦利县
    "420882": ("420821", "rename_unique_manual"),   # 京山市 -> 京山县
    "140403": ("140402", "urban_to_cityproper_manual"),  # 潞州区 -> 长治市城区
    "370116": ("371202", "rename_unique_manual"),   # 莱芜区 -> 莱城区
    "440309": ("440306", "urban_to_cityproper_manual"),  # 龙华区 -> 原宝安区
    "440404": ("440402", "urban_to_cityproper_manual"),  # 金湾区三灶 -> 原香洲区
    "450204": ("450201", "urban_to_cityproper_manual"),  # 柳南区 -> 柳州市辖区
}

OUTSIDE_SAMPLE = {"820000", "970000", "980000", "990000"}


def normalize_code(x: object) -> str | None:
    if pd.isna(x):
        return None
    try:
        return f"{int(float(x)):06d}"
    except Exception:
        s = str(x).strip()
        return s.zfill(6) if s else None


def strip_suffix(s: object) -> str:
    s = "" if pd.isna(s) else str(s)
    return re.sub(
        "壮族自治区|回族自治区|维吾尔自治区|自治区|自治县|自治旗|林区|特区|省|市|县|区|旗",
        "",
        s,
    )


def first_nonmissing(series: pd.Series) -> str:
    x = series.dropna().astype(str)
    return x.iloc[0] if len(x) else ""


def main() -> None:
    raw = pd.read_excel(RAW_XLSX, sheet_name="Sheet1")
    xwalk = pd.read_csv(CROSSWALK, dtype=str)

    raw["countyid_curr6_raw"] = raw["countyid"].map(normalize_code)
    raw["raw_rows"] = 1

    county = (
        raw.groupby("countyid_curr6_raw", dropna=False)
        .agg(
            raw_rows=("raw_rows", "sum"),
            province_raw=("province", first_nonmissing),
            prefecture_raw=("prefecture", first_nonmissing),
            county_raw=("county", first_nonmissing),
            cpc_sum=("cpc", lambda s: pd.to_numeric(s, errors="coerce").fillna(0).sum()),
            cpc_max=("cpc", lambda s: pd.to_numeric(s, errors="coerce").fillna(0).max()),
            first_site=("heritagename", lambda s: " | ".join(s.dropna().astype(str).head(3))),
        )
        .reset_index()
    )

    county["prov_key"] = county["province_raw"].map(strip_suffix)
    county["city_key"] = county["prefecture_raw"].map(strip_suffix)
    county["county_key"] = county["county_raw"].map(strip_suffix)

    xwalk["prov_key"] = xwalk["prov_name"].map(strip_suffix)
    xwalk["city_key"] = xwalk["city_name"].map(strip_suffix)
    xwalk["county_key"] = xwalk["county_name"].map(strip_suffix)

    records: list[dict[str, object]] = []

    for _, row in county.iterrows():
        raw_code = row["countyid_curr6_raw"]
        if raw_code in OUTSIDE_SAMPLE:
            records.append(
                {
                    **row.to_dict(),
                    "mapped_code": "",
                    "mapped_name": "",
                    "mapping_type": "outside_sample",
                }
            )
            continue

        direct = xwalk[xwalk["countyid_curr6"] == raw_code]
        if len(direct) == 1:
            hit = direct.iloc[0]
            records.append(
                {
                    **row.to_dict(),
                    "mapped_code": hit["countyid_curr6"],
                    "mapped_name": hit["county_name"],
                    "mapping_type": "direct_match",
                }
            )
            continue

        if raw_code in MANUAL_RECODE:
            code, mapping_type = MANUAL_RECODE[raw_code]
            hit = xwalk[xwalk["countyid_curr6"] == code]
            mapped_name = hit.iloc[0]["county_name"] if len(hit) == 1 else ""
            records.append(
                {
                    **row.to_dict(),
                    "mapped_code": code,
                    "mapped_name": mapped_name,
                    "mapping_type": mapping_type,
                }
            )
            continue

        cand_name = xwalk[
            (xwalk["prov_key"] == row["prov_key"])
            & (xwalk["county_key"] == row["county_key"])
        ]
        if len(cand_name) == 1:
            hit = cand_name.iloc[0]
            records.append(
                {
                    **row.to_dict(),
                    "mapped_code": hit["countyid_curr6"],
                    "mapped_name": hit["county_name"],
                    "mapping_type": "rename_unique",
                }
            )
            continue

        cand_cityproper = xwalk[
            (xwalk["prov_key"] == row["prov_key"])
            & (xwalk["city_key"] == row["city_key"])
            & (xwalk["county_name"].str.contains("市辖区|辖区", na=False))
        ]
        if len(cand_cityproper) >= 1 and str(row["county_raw"]).endswith("区"):
            hit = cand_cityproper.iloc[0]
            records.append(
                {
                    **row.to_dict(),
                    "mapped_code": hit["countyid_curr6"],
                    "mapped_name": hit["county_name"],
                    "mapping_type": "urban_to_cityproper",
                }
            )
            continue

        records.append(
            {
                **row.to_dict(),
                "mapped_code": "",
                "mapped_name": "",
                "mapping_type": "unresolved",
            }
        )

    audit = pd.DataFrame(records)
    audit["mapped_ok"] = audit["mapped_code"].ne("")
    audit.to_csv(OUT_AUDIT, index=False)

    usable = audit[audit["mapped_ok"]].copy()
    county_level = (
        usable.groupby("mapped_code", as_index=False)
        .agg(
            heritage_site_count=("raw_rows", "sum"),
            heritage_any=("raw_rows", lambda s: int(s.sum() > 0)),
            heritage_cpc_count=("cpc_max", lambda s: int(np.sum(pd.to_numeric(s, errors="coerce").fillna(0) > 0))),
            heritage_mapping_types=("mapping_type", lambda s: "|".join(sorted(pd.unique(s.astype(str))))),
        )
        .rename(columns={"mapped_code": "countyid_curr6"})
    )
    county_level["ln_heritage_site_count"] = np.log1p(county_level["heritage_site_count"])
    county_level["ln_heritage_cpc_count"] = np.log1p(county_level["heritage_cpc_count"])
    county_level.to_csv(OUT_COUNTY, index=False)

    ctrl = pd.read_csv(PROJ / "data/temp/county_controls_full_v1.csv", dtype={"countyid_curr6": str})
    ctrl["countyid_curr6"] = ctrl["countyid_curr6"].astype(str).str.zfill(6)
    merged = ctrl.merge(county_level, on="countyid_curr6", how="left")
    fill_zero = [
        "heritage_site_count",
        "heritage_any",
        "heritage_cpc_count",
        "ln_heritage_site_count",
        "ln_heritage_cpc_count",
    ]
    for col in fill_zero:
        merged[col] = pd.to_numeric(merged[col], errors="coerce").fillna(0)
    merged["heritage_mapping_types"] = merged["heritage_mapping_types"].fillna("")
    merged.to_csv(OUT_CONTROLS_CSV, index=False)
    merged.to_stata(OUT_CONTROLS_DTA, write_index=False, version=118)

    print("raw site rows:", len(raw))
    print("raw unique counties:", county['countyid_curr6_raw'].nunique())
    print("mapped site rows:", int(usable["raw_rows"].sum()))
    print("mapped unique counties:", county_level["countyid_curr6"].nunique())
    print("mapping breakdown:")
    print(audit["mapping_type"].value_counts().to_string())


if __name__ == "__main__":
    main()
