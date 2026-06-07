from pathlib import Path
import re
import shutil

import numpy as np
import pandas as pd
import pyreadstat
from pypinyin import lazy_pinyin


PROJ = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/"
    "My Drive/Projects/ongoing/japan_war"
)

IPUMS = PROJ / "data/raw/census/Census1990#11835947.dta"
CW = PROJ / "data/temp/countyid6_name_crosswalk_v1.csv"
PF = PROJ / "data/temp/county_to_pref4_crosswalk_v1.csv"
TREAT = PROJ / "data/temp/martyr_pop1953_treatment_county_v2.dta"
TMP_CSV = Path("/tmp/census1990_ipums_labor_industry_panel_v1.csv")
TMP_DTA = Path("/tmp/census1990_ipums_labor_industry_panel_v1.dta")


MANUAL_CN = {
    "长治市": "changzhi",
    "朝阳市": "chaoyang",
    "吕梁市": "lvliang",
    "六安市": "liuan",
    "亳州市": "bozhou",
    "呼和浩特市": "hohhot",
    "鄂尔多斯市": "eerduosi",
    "呼伦贝尔市": "hulunbeier",
    "巴彦淖尔市": "bayannaoer",
    "乌兰察布市": "wulanchabu",
    "锡林郭勒盟": "xilingol",
    "延边朝鲜族自治州": "yanbian",
    "哈尔滨市": "harbin",
    "齐齐哈尔市": "qiqihar",
    "淮安市": "huaian",
    "丽水市": "lishui",
    "台州市": "taizhou",
    "阿拉善盟": "alxa",
    "兴安盟": "xingan",
    "白山市": "baishan",
    "北京市（辖区）": "beijing",
    "北京市（辖县）": "beijing",
    "天津市（辖区）": "tianjin",
    "天津市（辖县）": "tianjin",
    "上海市（辖区）": "shanghai",
    "上海市（辖县）": "shanghai",
    "重庆市（辖区）": "chongqing",
    "重庆市（辖县）": "chongqing",
}

MANUAL_EN = {
    "beijing municipality": "beijing",
    "tianjin municipality": "tianjin",
    "shanghai municipality (districts)": "shanghai",
    "chongqing city": "chongqing",
    "hulunbuir league": "hulunbeier",
    "xilin gol league": "xilingol",
    "ulaan chab league": "wulanchabu",
    "xing'an league": "xingan",
    "yikezhao league": "eerduosi",
    "bayannur league": "bayannaoer",
    "alxa league": "alxa",
    "yanbian korean autonomous prefecture": "yanbian",
    "qiqihar city": "qiqihar",
    "harbin city": "harbin",
    "huaiyin city": "huaian",
    "changzhi city": "changzhi",
    "chaoyang city": "chaoyang",
    "luliang prefecture": "lvliang",
    "liu'an prefecture": "liuan",
    "songhuajiang prefecture": "harbin",
    "hunjiang city": "baishan",
    "acheng city": "harbin",
    "dayong city": "zhangjiajie",
    "lingling prefecture": "yongzhou",
    "shashi city": "jingzhou",
    "luohe city": "luohe",
    "wudu prefecture": "longnan",
    "heze prefecture": "heze",
}

VALID_OCC = set(range(1, 12))
VALID_IND = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 111, 112, 113, 114, 120, 130}


def norm_cn_city(s: str) -> str:
    s = str(s)
    if s in MANUAL_CN:
        return MANUAL_CN[s]
    s = re.sub(r"（.*?）|\(.*?\)", "", s)
    for suf in ["地区", "自治州", "盟", "市", "州"]:
        if s.endswith(suf):
            s = s[: -len(suf)]
            break
    return "".join(lazy_pinyin(s)).replace("lü", "lv")


def norm_en_geo2(s: str) -> str:
    s = str(s).lower().strip()
    if s in MANUAL_EN:
        return MANUAL_EN[s]
    for suf in [
        " autonomous prefecture",
        " municipality (districts)",
        " province direct administrative area (chaozhou city)",
        " province direct administrative area",
        " municipality",
        " prefecture",
        " league",
        " city",
    ]:
        if s.endswith(suf):
            s = s[: -len(suf)]
            break
    return re.sub(r"[^a-z]", "", s)


def build_geo2_root_map() -> pd.DataFrame:
    cw = pd.read_csv(CW, dtype={"countyid_curr6": str})
    pf = pd.read_csv(PF, dtype={"countyid_curr6": str, "pref4_curr": str})
    cur = cw.merge(pf, on="countyid_curr6", how="left")[["pref4_curr", "city_name"]].drop_duplicates()
    cur["root"] = cur["city_name"].map(norm_cn_city)
    cur["prov2"] = cur["pref4_curr"].str[:2]

    treat = pd.read_stata(TREAT, convert_categoricals=False)
    treat["countyid_curr6"] = pd.to_numeric(treat["countyid_curr6"], errors="coerce").astype("Int64")
    treat = treat.dropna(subset=["countyid_curr6", "martyr_count_1931_1945", "pop_1953"]).copy()
    treat["countyid_curr6"] = treat["countyid_curr6"].astype(int).map(lambda x: f"{x:06d}")
    treat["pref4_curr"] = treat["countyid_curr6"].str[:4]
    pref_treat = (
        treat.groupby("pref4_curr", as_index=False)
        .agg(pop_1953=("pop_1953", "sum"), martyr_count_1931_1945=("martyr_count_1931_1945", "sum"))
    )

    cur = cur.merge(pref_treat, on="pref4_curr", how="left")
    root_treat = (
        cur.groupby(["prov2", "root"], as_index=False)
        .agg(
            pop_1953=("pop_1953", "sum"),
            martyr_count_1931_1945=("martyr_count_1931_1945", "sum"),
            pref4_list=("pref4_curr", lambda x: "|".join(sorted(set(x.dropna())))),
            n_pref=("pref4_curr", lambda x: len(set(x.dropna()))),
        )
    )
    root_treat["ln_martyr_per100k_1953"] = np.log(
        root_treat["martyr_count_1931_1945"] / root_treat["pop_1953"] * 100000.0 + 1.0
    )

    _, meta = pyreadstat.read_dta(str(IPUMS), metadataonly=True)
    geo2_lab = meta.value_labels[meta.variable_to_label["geo2_cn1990"]]
    geo2 = pd.DataFrame([{"geo2_cn1990": int(k), "geo2_label": v} for k, v in geo2_lab.items()])
    geo2["root"] = geo2["geo2_label"].map(norm_en_geo2)
    geo2["prov2"] = geo2["geo2_cn1990"].astype(int).map(lambda x: f"{x:05d}"[:2])
    geo2 = geo2.merge(root_treat, on=["prov2", "root"], how="left")
    geo2["matched"] = geo2["ln_martyr_per100k_1953"].notna().astype(int)
    return geo2


def ratio(num: pd.Series, den: pd.Series) -> pd.Series:
    return np.where(den > 0, num / den, np.nan)


def main() -> None:
    geo2 = build_geo2_root_map()
    geo2.to_csv(PROJ / "data/temp/ipums1990_geo2_pref_match_v1.csv", index=False)
    audit = pd.DataFrame(
        {
            "metric": ["geo2_total", "geo2_matched", "geo2_match_rate"],
            "value": [len(geo2), int(geo2["matched"].sum()), float(geo2["matched"].mean())],
        }
    )
    audit.to_csv(PROJ / "result/table/ipums1990_geo2_pref_match_audit_v1.csv", index=False)

    treat_map = dict(zip(geo2["geo2_cn1990"], geo2["ln_martyr_per100k_1953"]))
    label_map = dict(zip(geo2["geo2_cn1990"], geo2["geo2_label"]))

    pieces = []
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(IPUMS),
        chunksize=800000,
        usecols=["geo2_cn1990", "birthyr", "sex", "ethniccn", "labforce", "empstat", "occisco", "indgen"],
    )

    for i, (chunk, _) in enumerate(reader, start=1):
        chunk["birth_i"] = pd.to_numeric(chunk["birthyr"], errors="coerce")
        chunk = chunk[chunk["birth_i"].between(1920, 1968) & (chunk["birth_i"] != 1939)].copy()
        if chunk.empty:
            continue

        chunk["geo2_cn1990"] = pd.to_numeric(chunk["geo2_cn1990"], errors="coerce").astype("Int64")
        chunk["ln_martyr_per100k_1953"] = chunk["geo2_cn1990"].map(treat_map)
        chunk["geo2_label"] = chunk["geo2_cn1990"].map(label_map)
        chunk = chunk[chunk["ln_martyr_per100k_1953"].notna()].copy()
        if chunk.empty:
            continue

        sex = pd.to_numeric(chunk["sex"], errors="coerce")
        ethn = pd.to_numeric(chunk["ethniccn"], errors="coerce")
        lab = pd.to_numeric(chunk["labforce"], errors="coerce")
        emp = pd.to_numeric(chunk["empstat"], errors="coerce")
        occ = pd.to_numeric(chunk["occisco"], errors="coerce")
        ind = pd.to_numeric(chunk["indgen"], errors="coerce")

        male_den = sex.isin([1, 2]).astype(int)
        male_num = (sex == 1).astype(int)
        minority_den = ethn.notna().astype(int)
        minority_num = (ethn != 1).astype(int)

        status_den = (lab.isin([1, 2]) & emp.isin([1, 2, 3])).astype(int)
        in_labor_force_num = ((lab == 2) & status_den.astype(bool)).astype(int)
        employed_num = ((emp == 1) & status_den.astype(bool)).astype(int)
        unemployed_num = ((emp == 2) & status_den.astype(bool)).astype(int)
        inactive_num = ((emp == 3) & status_den.astype(bool)).astype(int)

        employed = emp == 1
        occ_den = (employed & occ.isin(VALID_OCC)).astype(int)
        ind_den = (employed & ind.isin(VALID_IND)).astype(int)

        chunk = chunk.assign(
            male_num=male_num,
            male_den=male_den,
            minority_num=minority_num,
            minority_den=minority_den,
            status_den=status_den,
            in_labor_force_num=in_labor_force_num,
            employed_num=employed_num,
            unemployed_num=unemployed_num,
            inactive_num=inactive_num,
            occ_den=occ_den,
            white_collar_num=((occ.isin([1, 2, 3, 4, 5])) & occ_den.astype(bool)).astype(int),
            professional_manager_num=((occ.isin([1, 2, 3])) & occ_den.astype(bool)).astype(int),
            clerical_num=((occ == 4) & occ_den.astype(bool)).astype(int),
            service_sales_num=((occ == 5) & occ_den.astype(bool)).astype(int),
            agri_occupation_num=((occ == 6) & occ_den.astype(bool)).astype(int),
            craft_num=((occ == 7) & occ_den.astype(bool)).astype(int),
            machine_operator_num=((occ == 8) & occ_den.astype(bool)).astype(int),
            elementary_num=((occ == 9) & occ_den.astype(bool)).astype(int),
            ind_den=ind_den,
            agriculture_ind_num=((ind == 10) & ind_den.astype(bool)).astype(int),
            manufacturing_ind_num=((ind == 30) & ind_den.astype(bool)).astype(int),
            construction_ind_num=((ind == 50) & ind_den.astype(bool)).astype(int),
            trade_ind_num=((ind == 60) & ind_den.astype(bool)).astype(int),
            transport_ind_num=((ind == 80) & ind_den.astype(bool)).astype(int),
            finance_ind_num=((ind == 90) & ind_den.astype(bool)).astype(int),
            public_admin_ind_num=((ind == 100) & ind_den.astype(bool)).astype(int),
            business_realestate_ind_num=((ind == 111) & ind_den.astype(bool)).astype(int),
            education_ind_num=((ind == 112) & ind_den.astype(bool)).astype(int),
            health_social_ind_num=((ind == 113) & ind_den.astype(bool)).astype(int),
            other_services_ind_num=((ind == 114) & ind_den.astype(bool)).astype(int),
        )

        agg = chunk.groupby(["geo2_cn1990", "birth_i"], as_index=False).agg(
            n_obs=("birth_i", "size"),
            male_num=("male_num", "sum"),
            male_den=("male_den", "sum"),
            minority_num=("minority_num", "sum"),
            minority_den=("minority_den", "sum"),
            status_den=("status_den", "sum"),
            in_labor_force_num=("in_labor_force_num", "sum"),
            employed_num=("employed_num", "sum"),
            unemployed_num=("unemployed_num", "sum"),
            inactive_num=("inactive_num", "sum"),
            occ_den=("occ_den", "sum"),
            white_collar_num=("white_collar_num", "sum"),
            professional_manager_num=("professional_manager_num", "sum"),
            clerical_num=("clerical_num", "sum"),
            service_sales_num=("service_sales_num", "sum"),
            agri_occupation_num=("agri_occupation_num", "sum"),
            craft_num=("craft_num", "sum"),
            machine_operator_num=("machine_operator_num", "sum"),
            elementary_num=("elementary_num", "sum"),
            ind_den=("ind_den", "sum"),
            agriculture_ind_num=("agriculture_ind_num", "sum"),
            manufacturing_ind_num=("manufacturing_ind_num", "sum"),
            construction_ind_num=("construction_ind_num", "sum"),
            trade_ind_num=("trade_ind_num", "sum"),
            transport_ind_num=("transport_ind_num", "sum"),
            finance_ind_num=("finance_ind_num", "sum"),
            public_admin_ind_num=("public_admin_ind_num", "sum"),
            business_realestate_ind_num=("business_realestate_ind_num", "sum"),
            education_ind_num=("education_ind_num", "sum"),
            health_social_ind_num=("health_social_ind_num", "sum"),
            other_services_ind_num=("other_services_ind_num", "sum"),
            ln_martyr_per100k_1953=("ln_martyr_per100k_1953", "first"),
            geo2_label=("geo2_label", "first"),
        )
        pieces.append(agg)
        print(f"ipums1990 chunk {i} done", flush=True)

    out = pd.concat(pieces, ignore_index=True)
    print(f"ipums1990 concat rows={len(out)}", flush=True)
    out = out.groupby(["geo2_cn1990", "birth_i"], as_index=False).agg(
        n_obs=("n_obs", "sum"),
        male_num=("male_num", "sum"),
        male_den=("male_den", "sum"),
        minority_num=("minority_num", "sum"),
        minority_den=("minority_den", "sum"),
        status_den=("status_den", "sum"),
        in_labor_force_num=("in_labor_force_num", "sum"),
        employed_num=("employed_num", "sum"),
        unemployed_num=("unemployed_num", "sum"),
        inactive_num=("inactive_num", "sum"),
        occ_den=("occ_den", "sum"),
        white_collar_num=("white_collar_num", "sum"),
        professional_manager_num=("professional_manager_num", "sum"),
        clerical_num=("clerical_num", "sum"),
        service_sales_num=("service_sales_num", "sum"),
        agri_occupation_num=("agri_occupation_num", "sum"),
        craft_num=("craft_num", "sum"),
        machine_operator_num=("machine_operator_num", "sum"),
        elementary_num=("elementary_num", "sum"),
        ind_den=("ind_den", "sum"),
        agriculture_ind_num=("agriculture_ind_num", "sum"),
        manufacturing_ind_num=("manufacturing_ind_num", "sum"),
        construction_ind_num=("construction_ind_num", "sum"),
        trade_ind_num=("trade_ind_num", "sum"),
        transport_ind_num=("transport_ind_num", "sum"),
        finance_ind_num=("finance_ind_num", "sum"),
        public_admin_ind_num=("public_admin_ind_num", "sum"),
        business_realestate_ind_num=("business_realestate_ind_num", "sum"),
        education_ind_num=("education_ind_num", "sum"),
        health_social_ind_num=("health_social_ind_num", "sum"),
        other_services_ind_num=("other_services_ind_num", "sum"),
        ln_martyr_per100k_1953=("ln_martyr_per100k_1953", "first"),
        geo2_label=("geo2_label", "first"),
    )
    print(f"ipums1990 grouped rows={len(out)}", flush=True)

    out["male_share"] = ratio(out["male_num"], out["male_den"])
    out["minority_share"] = ratio(out["minority_num"], out["minority_den"])
    out["in_labor_force"] = ratio(out["in_labor_force_num"], out["status_den"])
    out["employed"] = ratio(out["employed_num"], out["status_den"])
    out["unemployed"] = ratio(out["unemployed_num"], out["status_den"])
    out["inactive"] = ratio(out["inactive_num"], out["status_den"])

    out["white_collar"] = ratio(out["white_collar_num"], out["occ_den"])
    out["professional_manager"] = ratio(out["professional_manager_num"], out["occ_den"])
    out["clerical"] = ratio(out["clerical_num"], out["occ_den"])
    out["service_sales"] = ratio(out["service_sales_num"], out["occ_den"])
    out["agri_occupation"] = ratio(out["agri_occupation_num"], out["occ_den"])
    out["craft"] = ratio(out["craft_num"], out["occ_den"])
    out["machine_operator"] = ratio(out["machine_operator_num"], out["occ_den"])
    out["elementary"] = ratio(out["elementary_num"], out["occ_den"])

    out["agriculture_ind"] = ratio(out["agriculture_ind_num"], out["ind_den"])
    out["manufacturing_ind"] = ratio(out["manufacturing_ind_num"], out["ind_den"])
    out["construction_ind"] = ratio(out["construction_ind_num"], out["ind_den"])
    out["trade_ind"] = ratio(out["trade_ind_num"], out["ind_den"])
    out["transport_ind"] = ratio(out["transport_ind_num"], out["ind_den"])
    out["finance_ind"] = ratio(out["finance_ind_num"], out["ind_den"])
    out["public_admin_ind"] = ratio(out["public_admin_ind_num"], out["ind_den"])
    out["business_realestate_ind"] = ratio(out["business_realestate_ind_num"], out["ind_den"])
    out["education_ind"] = ratio(out["education_ind_num"], out["ind_den"])
    out["health_social_ind"] = ratio(out["health_social_ind_num"], out["ind_den"])
    out["other_services_ind"] = ratio(out["other_services_ind_num"], out["ind_den"])

    out["geo2_code"] = out["geo2_cn1990"].astype(int).map(lambda x: f"{x:05d}")
    out["post"] = (out["birth_i"] >= 1940).astype(int)

    keep = [
        "geo2_cn1990",
        "geo2_code",
        "geo2_label",
        "birth_i",
        "post",
        "n_obs",
        "male_share",
        "minority_share",
        "in_labor_force",
        "employed",
        "unemployed",
        "inactive",
        "white_collar",
        "professional_manager",
        "clerical",
        "service_sales",
        "agri_occupation",
        "craft",
        "machine_operator",
        "elementary",
        "agriculture_ind",
        "manufacturing_ind",
        "construction_ind",
        "trade_ind",
        "transport_ind",
        "finance_ind",
        "public_admin_ind",
        "business_realestate_ind",
        "education_ind",
        "health_social_ind",
        "other_services_ind",
        "ln_martyr_per100k_1953",
    ]
    out = out[keep]
    print(f"ipums1990 final rows={len(out)}", flush=True)

    out.to_csv(TMP_CSV, index=False)
    out.to_stata(TMP_DTA, write_index=False, version=118)
    shutil.copy2(TMP_CSV, PROJ / "data/temp/census1990_ipums_labor_industry_panel_v1.csv")
    shutil.copy2(TMP_DTA, PROJ / "data/temp/census1990_ipums_labor_industry_panel_v1.dta")
    print("ipums1990 panel saved", flush=True)


if __name__ == "__main__":
    main()
