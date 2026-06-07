from pathlib import Path

import pandas as pd


PROJ = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/"
    "My Drive/Projects/ongoing/japan_war"
)


def main() -> None:
    cross = pd.read_csv(PROJ / "data/temp/countyid6_name_crosswalk_v1.csv", dtype={"countyid_curr6": str})
    cross["prov2"] = cross["countyid_curr6"].str[:2]
    cross["pref4"] = cross["countyid_curr6"].str[:4]

    # Wide fallback based on the full list pasted by the user.
    # Province-level mapping is intentionally broad and is kept as an appendix-only spec.
    broad_prov = {
        "61",  # 陕
        "62",  # 甘
        "64",  # 宁
        "14",  # 晋
        "13",  # 冀
        "15",  # 绥/察/热对应的现代内蒙古 fallback
        "21",  # 辽
        "37",  # 鲁
        "32",  # 苏
        "34",  # 皖
        "33",  # 浙
        "44",  # 东江/广东
        "46",  # 琼崖
        "41",  # 河南
        "42",  # 鄂
        "43",  # 湘
        "36",  # 赣
        "35",  # 闽
        "23",  # 黑
        "22",  # 吉
        "45",  # 桂
    }

    explicit_pref = {
        "3701", "3203", "1401", "4102", "1301",
        "3208", "3207", "3209", "4419",
    }
    explicit_county = {
        "140922", "441303", "440306", "440118", "441322", "320923",
    }

    cross["base_broad_any"] = (
        cross["prov2"].isin(broad_prov)
        | cross["pref4"].isin(explicit_pref)
        | cross["countyid_curr6"].isin(explicit_county)
    ).astype(int)

    out = cross[["countyid_curr6", "base_broad_any"]].copy()
    out.to_csv(PROJ / "data/temp/antijap_base_broad_indicator_v1.csv", index=False)
    out.to_stata(PROJ / "data/temp/antijap_base_broad_indicator_v1.dta", write_index=False, version=118)

    audit = pd.DataFrame(
        {
            "metric": ["total_counties", "treated_counties", "treated_share"],
            "value": [
                len(out),
                int(out["base_broad_any"].sum()),
                float(out["base_broad_any"].mean()),
            ],
        }
    )
    audit.to_csv(PROJ / "result/table/antijap_base_broad_indicator_audit_v1.csv", index=False)

    detail = pd.DataFrame(
        {
            "type": ["province_prefix"] * len(sorted(broad_prov))
            + ["prefecture"] * len(sorted(explicit_pref))
            + ["county"] * len(sorted(explicit_county)),
            "code": sorted(broad_prov) + sorted(explicit_pref) + sorted(explicit_county),
        }
    )
    detail.to_csv(PROJ / "data/temp/antijap_base_broad_mapping_detail_v1.csv", index=False)

    print(PROJ / "data/temp/antijap_base_broad_indicator_v1.csv")
    print(PROJ / "result/table/antijap_base_broad_indicator_audit_v1.csv")


if __name__ == "__main__":
    main()
