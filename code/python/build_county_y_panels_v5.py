from pathlib import Path

import numpy as np
import pandas as pd
import pyreadstat


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
RAW = PROJ / "data/raw"
TEMP = PROJ / "data/temp"
TREAT = TEMP / "martyr_pop1953_treatment_county_v2.dta"
CW1982 = TEMP / "countyid_1982_to_current_crosswalk_v2.csv"

THRESHOLDS = {
    "primary_comp": 6,
    "junior_high_comp": 9,
    "senior_high_comp": 12,
    "college_comp": 15,
}

WAVE_SPECS = {
    1982: {
        "path": Path("/tmp/census_1982_clean.dta") if Path("/tmp/census_1982_clean.dta").exists() else RAW / "census_1982_clean.dta",
        "county_col": "region1982",
        "birth_col": "year_birth",
        "eduy_col": "yedu",
        "lo": 1920,
        "hi": 1960,
        "needs_1982_crosswalk": True,
    },
    1990: {
        "path": Path("/tmp/census_1990_clean.dta") if Path("/tmp/census_1990_clean.dta").exists() else RAW / "census_1990_clean.dta",
        "county_col": "region1990",
        "birth_col": "year_birth",
        "eduy_col": "yedu",
        "lo": 1920,
        "hi": 1968,
        "needs_1982_crosswalk": False,
    },
    2000: {
        "path": Path("/tmp/census_2000_clean.dta") if Path("/tmp/census_2000_clean.dta").exists() else RAW / "census_2000_clean.dta",
        "county_col": "region2000",
        "birth_col": "year_birth",
        "eduy_col": "yedu",
        "lo": 1920,
        "hi": 1978,
        "needs_1982_crosswalk": False,
    },
}


def code6(x) -> str:
    if pd.isna(x):
        return ""
    s = str(x).replace(".0", "").strip()
    if not s or s.lower() == "nan":
        return ""
    digits = "".join(ch for ch in s if ch.isdigit())
    return digits.zfill(6)[-6:] if digits else ""


def read_treatment() -> pd.DataFrame:
    treat = pd.read_stata(TREAT, convert_categoricals=False)
    treat["countyid_curr6"] = treat["countyid_curr6"].map(code6)
    keep = [
        "countyid_curr6",
        "pop_1953",
        "martyr_count_1931_1945",
        "martyr_per100k_1953",
        "ln_martyr_raw",
        "ln_martyr_per100k_1953",
    ]
    return treat[keep].drop_duplicates("countyid_curr6")


def read_cw1982() -> pd.DataFrame:
    cw = pd.read_csv(CW1982, dtype=str)
    cw = cw.rename(columns={"countyid_old6": "old6", "countyid_curr6_final": "countyid_curr6"})
    cw["old6"] = cw["old6"].map(code6)
    cw["countyid_curr6"] = cw["countyid_curr6"].map(code6)
    cw = cw[(cw["old6"] != "") & (cw["countyid_curr6"] != "")].copy()
    return cw[["old6", "countyid_curr6"]].drop_duplicates("old6")


def add_completion_vars(df: pd.DataFrame) -> pd.DataFrame:
    for name, threshold in THRESHOLDS.items():
        df[name] = np.where(df["eduy"].notna(), (df["eduy"] >= threshold).astype(float), np.nan)
    return df


def collapse_chunks(chunks: list[pd.DataFrame]) -> pd.DataFrame:
    if not chunks:
        raise RuntimeError("no chunks to collapse")
    out = pd.concat(chunks, ignore_index=True)
    out = (
        out.groupby(["countyid_curr6", "birth_i"], as_index=False)
        .agg(
            n_obs=("n_obs", "sum"),
            eduy_sum=("eduy_sum", "sum"),
            primary_sum=("primary_sum", "sum"),
            junior_high_sum=("junior_high_sum", "sum"),
            senior_high_sum=("senior_high_sum", "sum"),
            college_sum=("college_sum", "sum"),
        )
    )
    return out


def load_wave_micro(wave: int, cw1982: pd.DataFrame) -> pd.DataFrame:
    spec = WAVE_SPECS[wave]
    src = spec["path"]
    county_col = spec["county_col"]
    birth_col = spec["birth_col"]
    eduy_col = spec["eduy_col"]
    reader = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(src),
        chunksize=500000,
        usecols=[county_col, birth_col, eduy_col],
    )
    acc: list[pd.DataFrame] = []
    for i, (df, _) in enumerate(reader, start=1):
        df["birth_i"] = pd.to_numeric(df[birth_col], errors="coerce").round().astype("Int64")
        df["eduy"] = pd.to_numeric(df[eduy_col], errors="coerce")

        if spec["needs_1982_crosswalk"]:
            df["old6"] = df[county_col].map(code6)
            df = df.merge(cw1982, on="old6", how="left")
        else:
            df["countyid_curr6"] = df[county_col].map(code6)

        df = df[(df["countyid_curr6"].notna()) & (df["countyid_curr6"] != "") & (df["countyid_curr6"] != "000000")].copy()
        df = df[df["birth_i"].between(spec["lo"], spec["hi"]) & (df["birth_i"] != 1939)].copy()
        df = df[df["eduy"].between(0, 25)].copy()
        if df.empty:
            continue

        df = add_completion_vars(df)
        g = (
            df.groupby(["countyid_curr6", "birth_i"], as_index=False)
            .agg(
                n_obs=("eduy", "size"),
                eduy_sum=("eduy", "sum"),
                primary_sum=("primary_comp", "sum"),
                junior_high_sum=("junior_high_comp", "sum"),
                senior_high_sum=("senior_high_comp", "sum"),
                college_sum=("college_comp", "sum"),
            )
        )
        acc.append(g)
        print(f"wave {wave} chunk {i} done", flush=True)

    return collapse_chunks(acc)


def finalize_wave(grouped: pd.DataFrame, wave: int, treat: pd.DataFrame) -> pd.DataFrame:
    grouped["eduy_mean"] = grouped["eduy_sum"] / grouped["n_obs"]
    grouped["primary_comp"] = grouped["primary_sum"] / grouped["n_obs"]
    grouped["junior_high_comp"] = grouped["junior_high_sum"] / grouped["n_obs"]
    grouped["senior_high_comp"] = grouped["senior_high_sum"] / grouped["n_obs"]
    grouped["college_comp"] = grouped["college_sum"] / grouped["n_obs"]
    grouped["junior_comp"] = grouped["junior_high_comp"]
    grouped["pri_comp"] = grouped["primary_comp"]
    grouped["mid_comp"] = grouped["junior_high_comp"]
    grouped["shs_comp"] = grouped["senior_high_comp"]
    grouped["col_comp"] = grouped["college_comp"]
    grouped["wave"] = wave
    grouped = grouped.merge(treat, on="countyid_curr6", how="left")
    keep = [
        "countyid_curr6",
        "birth_i",
        "n_obs",
        "eduy_mean",
        "primary_comp",
        "junior_comp",
        "junior_high_comp",
        "senior_high_comp",
        "college_comp",
        "pri_comp",
        "mid_comp",
        "shs_comp",
        "col_comp",
        "wave",
        "pop_1953",
        "martyr_count_1931_1945",
        "martyr_per100k_1953",
        "ln_martyr_raw",
        "ln_martyr_per100k_1953",
    ]
    return grouped[keep]


def save_wave(df: pd.DataFrame, wave: int) -> None:
    out_csv = TEMP / f"county_y_panel_{wave}_v5.csv"
    out_dta = TEMP / f"county_y_panel_{wave}_v5.dta"
    df.to_csv(out_csv, index=False)
    pyreadstat.write_dta(df, str(out_dta))
    print(f"wrote {out_csv} rows={len(df)}", flush=True)


def main() -> None:
    treat = read_treatment()
    cw1982 = read_cw1982()
    for wave in (1982, 1990, 2000):
        wave_df = load_wave_micro(wave, cw1982)
        panel = finalize_wave(wave_df, wave, treat)
        save_wave(panel, wave)


if __name__ == "__main__":
    main()
