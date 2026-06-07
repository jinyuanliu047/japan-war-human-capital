#!/usr/bin/env python3
from __future__ import annotations

import math
from pathlib import Path

import pandas as pd
import numpy as np


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
PROV_CSV = Path("/tmp/jw_collectivesim/Province_Collectivism_Index_1982_2020.csv")
PREF_CSV = Path("/tmp/jw_collectivesim/Prefecture_Collectivism_Index_2000_2020.csv")


def sigstars(p: float) -> str:
    if pd.isna(p):
        return ""
    if p < 0.01:
        return "***"
    if p < 0.05:
        return "**"
    if p < 0.1:
        return "*"
    return ""


def fmt_coef(b: float, p: float) -> str:
    return f"{b:.3f}{sigstars(p)}"


def fmt_se(se: float) -> str:
    return f"({se:.3f})"


def ols_row(y: pd.Series, x: pd.Series) -> dict[str, float]:
    df = pd.concat([y, x], axis=1).dropna()
    if df.empty:
        raise ValueError("No observations after dropping missing values")
    yy = pd.to_numeric(df.iloc[:, 0], errors="coerce").to_numpy(dtype=float)
    xx = pd.to_numeric(df.iloc[:, 1], errors="coerce").to_numpy(dtype=float)
    mask = ~np.isnan(yy) & ~np.isnan(xx)
    yy = yy[mask]
    xx = xx[mask]
    X = np.column_stack([np.ones(len(xx)), xx])
    XtX_inv = np.linalg.inv(X.T @ X)
    beta = XtX_inv @ (X.T @ yy)
    resid = yy - X @ beta
    n = len(yy)
    k = X.shape[1]
    meat = np.zeros((k, k))
    for i in range(n):
        xi = X[i : i + 1].T
        meat += float(resid[i] ** 2) * (xi @ xi.T)
    hc1 = (n / (n - k)) * XtX_inv @ meat @ XtX_inv
    se = np.sqrt(np.diag(hc1))
    b = float(beta[1])
    se_b = float(se[1])
    z = b / se_b if se_b != 0 else np.nan
    p = math.erfc(abs(z) / math.sqrt(2)) if not math.isnan(z) else np.nan
    ybar = yy.mean()
    ssr = float(np.sum((yy - X @ beta) ** 2))
    sst = float(np.sum((yy - ybar) ** 2))
    r2 = 1.0 - ssr / sst if sst != 0 else float("nan")
    ar2 = 1.0 - (1.0 - r2) * (n - 1) / (n - k) if n > k else float("nan")
    return {
        "b": b,
        "se": se_b,
        "p": p,
        "n": int(n),
        "r2": r2,
        "ar2": ar2,
    }


def write_tabular(columns: list[str], rows: list[tuple[str, list[str]]], out_path: Path, colspan: int | None = None) -> None:
    ncol = len(columns) + 1
    spec = "l" + "c" * len(columns)
    lines = [
        "\\begin{tabular}{" + spec + "}",
        "\\toprule",
    ]
    header = " & " + " & ".join(columns) + " \\\\"
    lines.append(header)
    lines.append("\\midrule")
    for label, vals in rows:
        lines.append(label + " & " + " & ".join(vals) + " \\\\")
    lines.append("\\bottomrule")
    lines.append("\\end{tabular}")
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    asset_dir = PROJ / "paper" / "assets" / "tables"
    asset_dir.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------------
    # Province-level collectivism
    # ------------------------------------------------------------------
    county = pd.read_csv(PROJ / "data" / "scrape" / "chinamartyrs_outputs" / "chinamartyrs_county_counts.csv")
    county["countyid_curr6"] = pd.to_numeric(county["county_id"].astype(str).str.slice(0, 6), errors="coerce")
    county = county.dropna(subset=["countyid_curr6"]).copy()
    county["countyid_curr6"] = county["countyid_curr6"].astype(int)
    county = county[["countyid_curr6", "province_name", "city_name"]].drop_duplicates("countyid_curr6")

    treat = pd.read_csv(PROJ / "data" / "temp" / "martyr_pop1953_treatment_county_v2.csv")
    treat = treat.loc[treat["countyid_curr6"] != 0, ["countyid_curr6", "pop_1953", "martyr_count_1931_1945"]].copy()
    prov = treat.merge(county[["countyid_curr6", "province_name"]], on="countyid_curr6", how="left")

    prov_map = {
        "北京市": "北京",
        "天津市": "天津",
        "上海市": "上海",
        "重庆市": "重庆",
        "河北省": "河北",
        "山西省": "山西",
        "辽宁省": "辽宁",
        "吉林省": "吉林",
        "黑龙江省": "黑龙江",
        "江苏省": "江苏",
        "浙江省": "浙江",
        "安徽省": "安徽",
        "福建省": "福建",
        "江西省": "江西",
        "山东省": "山东",
        "河南省": "河南",
        "湖北省": "湖北",
        "湖南省": "湖南",
        "广东省": "广东",
        "海南省": "海南",
        "四川省": "四川",
        "贵州省": "贵州",
        "云南省": "云南",
        "陕西省": "陕西",
        "甘肃省": "甘肃",
        "青海省": "青海",
        "内蒙古自治区": "内蒙古",
        "广西壮族自治区": "广西",
        "西藏自治区": "西藏",
        "宁夏回族自治区": "宁夏",
        "新疆维吾尔自治区": "新疆",
        "新疆生产建设兵团": "新疆",
    }
    prov["province_short"] = prov["province_name"].map(prov_map)
    missing_prov = prov.loc[prov["province_short"].isna(), "province_name"].dropna().unique().tolist()
    if missing_prov:
        raise ValueError(f"Unmapped province names: {missing_prov}")

    prov = prov.groupby("province_short", as_index=False)[["pop_1953", "martyr_count_1931_1945"]].sum()
    prov["ln_martyr_per100k_1953"] = (1.0 + prov["martyr_count_1931_1945"] / prov["pop_1953"] * 100000.0).map(math.log)

    prov_col = pd.read_csv(PROV_CSV)
    prov_col = prov_col[[
        "ProvinceChinese",
        "ProvinceCollectivismIndex1982FourItems",
        "ProvinceCollectivismIndex1990FourItems",
        "ProvinceCollectivismIndex2000FourItems",
    ]].rename(columns={"ProvinceChinese": "province_short"})
    for c in [
        "ProvinceCollectivismIndex1982FourItems",
        "ProvinceCollectivismIndex1990FourItems",
        "ProvinceCollectivismIndex2000FourItems",
    ]:
        prov_col[c] = pd.to_numeric(prov_col[c], errors="coerce")
    prov_dat = prov.merge(prov_col, on="province_short", how="inner")
    prov_dat = prov_dat[np.isfinite(prov_dat["ln_martyr_per100k_1953"])].copy()
    if len(prov_dat) != 31:
        print(f"[collectivesim] province-level matched rows: {len(prov_dat)}")
        print(prov_dat[["province_short"]].sort_values("province_short").to_string(index=False))

    province_models = {
        "1982": ols_row(prov_dat["ProvinceCollectivismIndex1982FourItems"], prov_dat["ln_martyr_per100k_1953"]),
        "1990": ols_row(prov_dat["ProvinceCollectivismIndex1990FourItems"], prov_dat["ln_martyr_per100k_1953"]),
        "2000": ols_row(prov_dat["ProvinceCollectivismIndex2000FourItems"], prov_dat["ln_martyr_per100k_1953"]),
    }
    province_rows = [
        ("Log martyr exposure per 100,000", [
            fmt_coef(province_models[k]["b"], province_models[k]["p"]) for k in ["1982", "1990", "2000"]
        ]),
        ("", [
            fmt_se(province_models[k]["se"]) for k in ["1982", "1990", "2000"]
        ]),
        ("Observations", [f"{province_models[k]['n']}" for k in ["1982", "1990", "2000"]]),
        ("R-squared", [f"{province_models[k]['r2']:.3f}" for k in ["1982", "1990", "2000"]]),
        ("Adj. R-squared", [f"{province_models[k]['ar2']:.3f}" for k in ["1982", "1990", "2000"]]),
    ]
    write_tabular(
        ["1982", "1990", "2000"],
        province_rows,
        asset_dir / "collectivesim_province_reduced_form_v1.tex",
    )

    prov_dat.to_csv(asset_dir / "collectivesim_province_reduced_form_v1.csv", index=False)

    # ------------------------------------------------------------------
    # Prefecture-level 2000 supplement
    # ------------------------------------------------------------------
    pref = treat.merge(county, on="countyid_curr6", how="left")
    pref["pref4_curr"] = (pref["countyid_curr6"] // 100).astype(int)
    pref["pref_short"] = pref["city_name"].astype(str)
    pref.loc[pref["pref_short"].str.endswith("市"), "pref_short"] = pref.loc[pref["pref_short"].str.endswith("市"), "pref_short"].str[:-1]
    pref.loc[pref["pref_short"].str.endswith("盟"), "pref_short"] = pref.loc[pref["pref_short"].str.endswith("盟"), "pref_short"].str[:-1]
    pref_map = {
        "伊犁哈萨克自治州": "伊犁州",
        "巴音郭楞蒙古自治州": "巴音郭楞州",
        "博尔塔拉蒙古自治州": "博州",
        "昌吉回族自治州": "昌吉",
        "大理白族自治州": "大理",
        "德宏傣族景颇族自治州": "德宏",
        "临夏回族自治州": "临夏",
        "怒江傈僳族自治州": "怒江",
        "恩施土家族苗族自治州": "恩施",
        "湘西土家族苗族自治州": "湘西",
        "红河哈尼族彝族自治州": "红河",
        "楚雄彝族自治州": "楚雄",
        "西双版纳傣族自治州": "西双版纳",
        "甘孜藏族自治州": "甘孜",
        "阿坝藏族羌族自治州": "阿坝",
        "海北藏族自治州": "海北",
        "海南藏族自治州": "海南",
        "海西蒙古族藏族自治州": "海西",
        "黄南藏族自治州": "黄南",
        "玉树藏族自治州": "玉树",
        "甘南藏族自治州": "甘南",
        "凉山彝族自治州": "凉山",
        "文山壮族苗族自治州": "文山",
        "黔东南苗族侗族自治州": "黔东南",
        "黔南布依族苗族自治州": "黔南",
        "黔西南布依族苗族自治州": "黔西南",
        "大兴安岭地区": "大兴安岭",
    }
    pref["pref_short"] = pref["pref_short"].replace(pref_map)
    pref = pref.groupby(["pref4_curr", "pref_short"], as_index=False)[["pop_1953", "martyr_count_1931_1945"]].sum()
    pref["ln_martyr_per100k_1953"] = (1.0 + pref["martyr_count_1931_1945"] / pref["pop_1953"] * 100000.0).map(math.log)

    pref_col = pd.read_csv(PREF_CSV)
    pref_col = pref_col[["PrefectureChinese", "PrefectureCollectivismIndex2000"]].rename(columns={"PrefectureChinese": "pref_short"})
    pref_col["PrefectureCollectivismIndex2000"] = pd.to_numeric(pref_col["PrefectureCollectivismIndex2000"], errors="coerce")
    pref_dat = pref.merge(pref_col, on="pref_short", how="inner")
    pref_dat = pref_dat[np.isfinite(pref_dat["ln_martyr_per100k_1953"])].copy()
    if len(pref_dat) < len(pref):
        missing = sorted(set(pref["pref_short"]) - set(pref_dat["pref_short"]))
        print(f"[collectivesim] prefecture-level unmatched names: {missing[:40]}")

    pref_model = ols_row(pref_dat["PrefectureCollectivismIndex2000"], pref_dat["ln_martyr_per100k_1953"])
    pref_rows = [
        ("Log martyr exposure per 100,000", [fmt_coef(pref_model["b"], pref_model["p"])]),
        ("", [fmt_se(pref_model["se"])]),
        ("Observations", [f"{pref_model['n']}"]),
        ("R-squared", [f"{pref_model['r2']:.3f}"]),
        ("Adj. R-squared", [f"{pref_model['ar2']:.3f}"]),
    ]
    write_tabular(
        ["2000"],
        pref_rows,
        asset_dir / "collectivesim_prefecture_2000_v1.tex",
    )

    pref_dat.to_csv(asset_dir / "collectivesim_prefecture_2000_v1.csv", index=False)

    print("[collectivesim] province rows:", len(prov_dat))
    print("[collectivesim] prefecture rows:", len(pref_dat))
    print("[collectivesim] outputs written to", asset_dir)


if __name__ == "__main__":
    main()
