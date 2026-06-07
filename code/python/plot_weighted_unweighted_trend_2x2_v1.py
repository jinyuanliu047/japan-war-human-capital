#!/usr/bin/env python3
"""Plot weighted vs unweighted cohort trends by treatment intensity."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

BASE = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
)
TEMP = BASE / "data" / "temp"
FIG = BASE / "result" / "figure"


def _load_wave(wave: int) -> pd.DataFrame:
    df = pd.read_stata(TEMP / f"did_{wave}_county_birthyr_pop1953_unwt_v2.dta", convert_categoricals=False)
    hi = 1960
    if wave == 1990:
        hi = 1968
    if wave == 2000:
        hi = 1978
    df = df[df["birthyr"].between(1920, hi)].copy()
    df = df[np.floor(df["birthyr"]).astype(int) != 1939].copy()
    df = df[df["eduy_mean"].notna() & df["ln_martyr_per100k_1953"].notna()].copy()
    df["birth_i"] = np.floor(df["birthyr"]).astype(int)
    med = df[["countyid_curr6", "ln_martyr_per100k_1953"]].drop_duplicates()["ln_martyr_per100k_1953"].median()
    df["treat_hi"] = (df["ln_martyr_per100k_1953"] >= med).astype(int)
    return df


def _aggregate(df: pd.DataFrame) -> pd.DataFrame:
    out = []
    for b, d in df.groupby("birth_i"):
        for g in [0, 1]:
            dg = d[d["treat_hi"] == g]
            if len(dg) == 0:
                continue
            out.append(
                {
                    "birth_i": b,
                    "treat_hi": g,
                    "unweighted": float(dg["eduy_mean"].mean()),
                    "weighted_nobs": float(np.average(dg["eduy_mean"], weights=dg["n_obs"].clip(lower=1))),
                }
            )
    out = pd.DataFrame(out)
    wide = out.pivot(index="birth_i", columns="treat_hi", values=["unweighted", "weighted_nobs"])  # type: ignore
    wide.columns = [f"{a}_{b}" for a, b in wide.columns]
    wide = wide.reset_index().sort_values("birth_i")
    wide["gap_unweighted"] = wide["unweighted_1"] - wide["unweighted_0"]
    wide["gap_weighted"] = wide["weighted_nobs_1"] - wide["weighted_nobs_0"]
    return wide


def main() -> None:
    plt.rcParams.update(
        {
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "axes.grid": True,
            "grid.color": "#D9D9D9",
            "grid.linewidth": 0.7,
            "grid.alpha": 0.65,
            "axes.spines.top": False,
            "axes.spines.right": False,
            "axes.edgecolor": "#4C4C4C",
            "font.family": "serif",
            "font.serif": ["Times New Roman", "Songti SC", "Noto Serif CJK SC", "DejaVu Serif"],
            "font.size": 11,
            "axes.unicode_minus": False,
        }
    )

    colors = {"unw": "#1F2D4F", "w": "#B03A2E"}
    waves = [1982, 1990, 2000]
    titles = {1982: "A. Census 1982", 1990: "B. Census 1990", 2000: "C. Census 2000"}

    panel = {}
    for w in waves:
        panel[w] = _aggregate(_load_wave(w))
        panel[w]["wave"] = w

    full = pd.concat(panel.values(), ignore_index=True)
    full.to_csv(TEMP / "weighted_unweighted_gap_by_birth_v1.csv", index=False, encoding="utf-8-sig")
    full.to_stata(TEMP / "weighted_unweighted_gap_by_birth_v1.dta", write_index=False, version=118)

    fig, axes = plt.subplots(2, 2, figsize=(12.8, 10.8))
    axes = axes.flatten()

    for i, w in enumerate(waves):
        d = panel[w]
        ax = axes[i]
        hi = d["birth_i"].max()
        ax.axvspan(1940, hi, color="#ECE9E3", alpha=0.45, zorder=0)
        ax.plot(d["birth_i"], d["gap_unweighted"], color=colors["unw"], lw=2, marker="o", ms=3.5, label="Unweighted")
        ax.plot(d["birth_i"], d["gap_weighted"], color=colors["w"], lw=2, marker="^", ms=3.5, label="Weighted (n_obs)")
        ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0)
        ax.axvline(1940, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)
        ax.set_xlim(1920, hi)
        ax.set_title(titles[w], loc="left", fontsize=12.5, fontweight="bold")
        ax.set_xlabel("Birth cohort")
        ax.set_ylabel("High-low education gap")
        ax.legend(frameon=False, loc="best")

    ax = axes[3]
    for w, c in zip(waves, ["#1F2D4F", "#7A1F2B", "#2E4A3F"]):
        d = panel[w]
        ax.plot(d["birth_i"], d["gap_weighted"], color=c, lw=2, marker="o", ms=3.2, label=f"Weighted {w}")
    ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0)
    ax.axvline(1940, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)
    ax.set_title("D. Weighted gaps overlay", loc="left", fontsize=12.5, fontweight="bold")
    ax.set_xlabel("Birth cohort")
    ax.set_ylabel("High-low education gap")
    ax.legend(frameon=False, loc="best")

    fig.suptitle(
        "Weighted vs Unweighted Cohort Gaps (High vs Low Martyr Intensity)",
        x=0.01,
        ha="left",
        fontsize=15,
        fontweight="bold",
    )
    fig.tight_layout(rect=[0, 0.02, 1, 0.96])

    FIG.mkdir(parents=True, exist_ok=True)
    out = FIG / "weighted_unweighted_gap_trend_2x2_v1.png"
    fig.savefig(out, dpi=320)
    fig.savefig(out.with_suffix(".pdf"))
    print(out)


if __name__ == "__main__":
    main()
