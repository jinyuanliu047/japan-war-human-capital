#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path

import pandas as pd

MOD_PATH = Path("code/python/build_county_extended_controls_v1.py").resolve()
spec = importlib.util.spec_from_file_location("extctrl", MOD_PATH)
mod = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(mod)

PROJ = Path(mod.PROJ)
SRC = Path("/Users/jinyuanliu/Desktop/work_other/高校内迁.xlsx")


def _norm(x: object) -> str:
    if pd.isna(x):
        return ""
    return mod.normalize_place(mod.clean_text(x))


def _raw(x: object) -> str:
    if pd.isna(x):
        return ""
    return mod.clean_text(x)


def build_reloc_any() -> pd.DataFrame:
    df = pd.read_excel(SRC, sheet_name=0)
    need = ["迁入省份", "迁入城市", "迁入区县", "高校名称", "内迁时间"]
    for c in need:
        if c not in df.columns:
            df[c] = ""
    d = df[need].copy()
    d["prov_raw"] = d["迁入省份"].map(_raw)
    d["city_raw"] = d["迁入城市"].map(_raw)
    d["county_raw"] = d["迁入区县"].map(_raw)
    d["prov_norm"] = d["迁入省份"].map(_norm)
    d["city_norm"] = d["迁入城市"].map(_norm)
    d["county_norm"] = d["迁入区县"].map(_norm)
    d = d[(d["prov_norm"] != "") | (d["city_norm"] != "") | (d["county_norm"] != "")].copy()

    county = mod.build_county_dict()
    county_name_map, city_name_map, _ = mod.build_name_maps(county)

    rows = []
    for _, r in d.iterrows():
        matched = set()
        has_county_text = (r["county_raw"] != "") or (r["county_norm"] != "")
        # county exact/norm first
        if has_county_text:
            for k in [r["county_raw"], r["county_norm"]]:
                if k in county_name_map:
                    matched.update(county_name_map[k])
        # city fallback only when county text is missing
        if (not has_county_text) and (not matched):
            for k in [r["city_raw"], r["city_norm"]]:
                if k in city_name_map:
                    matched.update(city_name_map[k])
        if not matched:
            continue
        w = 1.0 / len(matched)
        for cid in matched:
            rows.append(
                {
                    "countyid_curr6": cid,
                    "高校名称": r["高校名称"],
                    "内迁时间": r["内迁时间"],
                    "match_weight": w,
                }
            )

    m = pd.DataFrame(rows)
    if m.empty:
        out = county[["countyid_curr6"]].copy()
        out["reloc_weighted_cnt"] = 0.0
        out["reloc_any"] = 0
        return out

    c = m.groupby("countyid_curr6", as_index=False).agg(reloc_weighted_cnt=("match_weight", "sum"))
    c["reloc_any"] = (c["reloc_weighted_cnt"] > 0).astype(int)
    out = county[["countyid_curr6"]].drop_duplicates().merge(c, on="countyid_curr6", how="left")
    out["reloc_weighted_cnt"] = out["reloc_weighted_cnt"].fillna(0.0)
    out["reloc_any"] = out["reloc_any"].fillna(0).astype(int)
    return out


def main() -> None:
    out = build_reloc_any()
    mapped = out[out["reloc_any"] == 1].copy()
    (PROJ / "data/temp").mkdir(parents=True, exist_ok=True)
    out.to_csv(PROJ / "data/temp/county_university_relocation_any_v1.csv", index=False, encoding="utf-8-sig")
    out.to_stata(PROJ / "data/temp/county_university_relocation_any_v1.dta", write_index=False, version=118)
    mapped.to_csv(PROJ / "data/temp/county_university_relocation_matched_counties_v1.csv", index=False, encoding="utf-8-sig")
    print("counties_with_reloc_any", int((out["reloc_any"] == 1).sum()))


if __name__ == "__main__":
    main()
