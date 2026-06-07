from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm


PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
DATA_TEMP = PROJ / "data" / "temp"
RESULT_TABLE = PROJ / "result" / "table"


def weighted_group_mean(values: np.ndarray, weights: np.ndarray, groups: np.ndarray) -> np.ndarray:
    values = np.asarray(values).reshape(-1)
    weights = np.asarray(weights).reshape(-1)
    groups = np.asarray(groups).reshape(-1)
    df = pd.DataFrame({"g": groups, "w": weights})
    df["vw"] = values * weights
    sums = df.groupby("g", sort=False)["vw"].sum()
    wsum = df.groupby("g", sort=False)["w"].sum()
    means = (sums / wsum).to_dict()
    return np.array([means[g] for g in groups], dtype=float)


def residualize_two_way(
    values: np.ndarray,
    weights: np.ndarray,
    g1: np.ndarray,
    g2: np.ndarray,
    max_iter: int = 40,
    tol: float = 1e-8,
) -> np.ndarray:
    res = values.astype(float).copy()
    for _ in range(max_iter):
        old = res.copy()
        res -= weighted_group_mean(res, weights, g1)
        res -= weighted_group_mean(res, weights, g2)
        if np.max(np.abs(res - old)) < tol:
            break
    return res


def fit_twfe(
    df: pd.DataFrame,
    y: str,
    xvars: list[str],
    weight: str,
    cluster: str,
    fe1: str,
    fe2: str,
) -> dict[str, float]:
    cols = list(dict.fromkeys([y, weight, cluster, fe1, fe2] + xvars))
    work = df[cols].dropna().copy()
    w = work[weight].to_numpy(dtype=float)
    g1 = work[fe1].astype(str).to_numpy()
    g2 = work[fe2].astype(int).to_numpy()

    y_res = residualize_two_way(work[y].to_numpy(dtype=float), w, g1, g2)
    x_res_cols = []
    for x in xvars:
        x_res_cols.append(residualize_two_way(work[x].to_numpy(dtype=float), w, g1, g2))
    x_res = np.column_stack(x_res_cols)

    model = sm.WLS(y_res, x_res, weights=w)
    fit = model.fit(cov_type="cluster", cov_kwds={"groups": work[cluster].astype(str).to_numpy()})

    out = {"n_obs": float(len(work)), "n_clust": float(work[cluster].nunique())}
    for i, x in enumerate(xvars):
        out[f"b_{x}"] = float(fit.params[i])
        out[f"se_{x}"] = float(fit.bse[i])
        out[f"p_{x}"] = float(fit.pvalues[i])
    return out


def prep_did_panel(path: Path, sample_hi: int, cutoff: int) -> pd.DataFrame:
    df = pd.read_csv(path, encoding="utf-8-sig")
    df = df[df["countyid_curr6"].notna()].copy()
    df["countyid_curr6"] = df["countyid_curr6"].astype(str).str.zfill(6)
    df = df[df["countyid_curr6"] != "000000"].copy()
    df["birth_i"] = np.floor(df["birthyr"]).astype(int)
    df = df[(df["birth_i"] >= 1920) & (df["birth_i"] <= sample_hi)].copy()
    df = df[df["birth_i"] != cutoff - 1].copy()
    df["post"] = (df["birth_i"] >= cutoff).astype(int)
    df["did"] = df["ln_martyr_per100k_1953"] * df["post"]
    return df


def run_main_cutoff_sweep() -> None:
    rows = []
    wave_hi = {1982: 1960, 1990: 1968, 2000: 1978}
    cutoffs = [1940, 1946, 1947, 1950, 1956, 1958]

    for wave, hi in wave_hi.items():
        path = DATA_TEMP / f"did_{wave}_county_birthyr_pop1953_unwt_v2.csv"
        for cutoff in cutoffs:
            df = prep_did_panel(path, hi, cutoff)
            fit = fit_twfe(
                df=df,
                y="eduy_mean",
                xvars=["did"],
                weight="n_obs",
                cluster="countyid_curr6",
                fe1="countyid_curr6",
                fe2="birth_i",
            )
            rows.append(
                {
                    "wave": wave,
                    "sample_hi": hi,
                    "cutoff": cutoff,
                    "b": fit["b_did"],
                    "se": fit["se_did"],
                    "p": fit["p_did"],
                    "n_cells": int(fit["n_obs"]),
                    "n_counties": int(fit["n_clust"]),
                }
            )

    out = pd.DataFrame(rows).sort_values(["wave", "cutoff"])
    out.to_csv(RESULT_TABLE / "main_cutoff_sweep_python_summary_v1.csv", index=False)


def run_1982_pre_glf_sweep() -> None:
    rows = []
    path = DATA_TEMP / "did_1982_county_birthyr_pop1953_unwt_v2.csv"
    for cutoff in [1940, 1946]:
        for hi in [1956, 1958, 1960]:
            df = prep_did_panel(path, hi, cutoff)
            fit = fit_twfe(
                df=df,
                y="eduy_mean",
                xvars=["did"],
                weight="n_obs",
                cluster="countyid_curr6",
                fe1="countyid_curr6",
                fe2="birth_i",
            )
            rows.append(
                {
                    "wave": 1982,
                    "sample_hi": hi,
                    "cutoff": cutoff,
                    "b": fit["b_did"],
                    "se": fit["se_did"],
                    "p": fit["p_did"],
                    "n_cells": int(fit["n_obs"]),
                    "n_counties": int(fit["n_clust"]),
                }
            )
    out = pd.DataFrame(rows).sort_values(["cutoff", "sample_hi"])
    out.to_csv(RESULT_TABLE / "main_1982_pre_glf_sweep_python_summary_v1.csv", index=False)


def run_gender_cutoff_sweep() -> None:
    rows = []
    for subgroup in ["male", "female"]:
        path = DATA_TEMP / "heterogeneity_groups_v4" / f"panel_1990_{subgroup}.csv"
        df = pd.read_csv(path, encoding="utf-8-sig")
        df["countyid_curr6"] = df["countyid_curr6"].astype(str).str.zfill(6)
        df = df[df["countyid_curr6"] != "000000"].copy()
        for cutoff in [1940, 1946, 1947, 1950, 1956]:
            work = df.copy()
            work = work[(work["birth_i"] >= 1920) & (work["birth_i"] <= 1968)].copy()
            work = work[work["birth_i"] != cutoff - 1].copy()
            work["post"] = (work["birth_i"] >= cutoff).astype(int)
            work["did"] = work["ln_martyr_per100k_1953"] * work["post"]
            fit = fit_twfe(
                df=work,
                y="eduy_mean",
                xvars=["did", "minority_share"],
                weight="n",
                cluster="countyid_curr6",
                fe1="countyid_curr6",
                fe2="birth_i",
            )
            rows.append(
                {
                    "wave": 1990,
                    "subgroup": subgroup,
                    "cutoff": cutoff,
                    "b": fit["b_did"],
                    "se": fit["se_did"],
                    "p": fit["p_did"],
                    "n_cells": int(fit["n_obs"]),
                    "n_counties": int(fit["n_clust"]),
                }
            )
    out = pd.DataFrame(rows).sort_values(["subgroup", "cutoff"])
    out.to_csv(RESULT_TABLE / "heterogeneity_gender_cutoff_sweep_python_summary_v1.csv", index=False)


def run_baseedu_cutoff_sweep() -> None:
    rows = []
    path = DATA_TEMP / "did_1990_county_birthyr_pop1953_unwt_v2.csv"
    full = pd.read_csv(path, encoding="utf-8-sig")
    full["countyid_curr6"] = full["countyid_curr6"].astype(str).str.zfill(6)
    full = full[full["countyid_curr6"] != "000000"].copy()
    full["birth_i"] = np.floor(full["birthyr"]).astype(int)

    base = (
        full[(full["birth_i"] >= 1920) & (full["birth_i"] <= 1938)]
        .groupby("countyid_curr6", as_index=False)["eduy_mean"]
        .mean()
        .rename(columns={"eduy_mean": "baseedu"})
    )
    base["baseedu_tercile"] = pd.qcut(base["baseedu"], 3, labels=[1, 2, 3])
    full = full.merge(base[["countyid_curr6", "baseedu_tercile"]], on="countyid_curr6", how="left")

    for cutoff in [1940, 1946, 1947, 1950, 1956]:
        work0 = full[(full["birth_i"] >= 1920) & (full["birth_i"] <= 1968)].copy()
        work0 = work0[work0["birth_i"] != cutoff - 1].copy()
        work0["post"] = (work0["birth_i"] >= cutoff).astype(int)
        work0["did"] = work0["ln_martyr_per100k_1953"] * work0["post"]
        for grp in [1, 2, 3]:
            work = work0[work0["baseedu_tercile"].astype(float) == grp].copy()
            fit = fit_twfe(
                df=work,
                y="eduy_mean",
                xvars=["did"],
                weight="n_obs",
                cluster="countyid_curr6",
                fe1="countyid_curr6",
                fe2="birth_i",
            )
            rows.append(
                {
                    "wave": 1990,
                    "group": f"B{grp}",
                    "cutoff": cutoff,
                    "b": fit["b_did"],
                    "se": fit["se_did"],
                    "p": fit["p_did"],
                    "n_cells": int(fit["n_obs"]),
                    "n_counties": int(fit["n_clust"]),
                }
            )
    out = pd.DataFrame(rows).sort_values(["group", "cutoff"])
    out.to_csv(RESULT_TABLE / "heterogeneity_baseedu_cutoff_sweep_python_summary_v1.csv", index=False)


def main() -> None:
    run_main_cutoff_sweep()
    run_1982_pre_glf_sweep()
    run_gender_cutoff_sweep()
    run_baseedu_cutoff_sweep()


if __name__ == "__main__":
    main()
