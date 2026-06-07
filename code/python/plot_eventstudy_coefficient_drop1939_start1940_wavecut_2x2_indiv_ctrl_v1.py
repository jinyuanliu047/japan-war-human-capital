#!/usr/bin/env python3
"""2x2 panel for individual-level coefficients with controls."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


BASE = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
)
TEMP = BASE / "data" / "temp"
FIG = BASE / "result" / "figure"


def _load(wave: str) -> pd.DataFrame:
    p = TEMP / f"eventstudy_coefficient_drop1939_start1940_{wave}_indiv_ctrl_v1.csv"
    df = pd.read_csv(p)
    for c in ["birthyr", "coefficient", "lb", "ub", "sample_hi"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    return df.sort_values("birthyr")


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

    colors = {"1982": "#1F2D4F", "1990": "#7A1F2B", "2000": "#2E4A3F"}
    markers = {"1982": "o", "1990": "^", "2000": "s"}
    titles = {"1982": "A. Census 1982", "1990": "B. Census 1990", "2000": "C. Census 2000"}
    dfs = {w: _load(w) for w in ["1982", "1990", "2000"]}
    hi = max(int(d["sample_hi"].dropna().iloc[0]) for d in dfs.values())

    fig, axes = plt.subplots(2, 2, figsize=(12.8, 10.8))
    axes = axes.flatten()

    for i, w in enumerate(["1982", "1990", "2000"]):
        ax = axes[i]
        d = dfs[w]
        ax.axvspan(1940, hi, color="#ECE9E3", alpha=0.45, zorder=0)
        ax.fill_between(d["birthyr"], d["lb"], d["ub"], color=colors[w], alpha=0.18, linewidth=0, zorder=1)
        ax.plot(d["birthyr"], d["coefficient"], color=colors[w], linewidth=2.0, marker=markers[w], markersize=3.6, zorder=2)
        ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0)
        ax.axvline(1940, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)
        ax.set_xlim(1920, hi)
        ax.set_title(titles[w], loc="left", fontsize=12.5, fontweight="bold")
        ax.set_xlabel("Birth cohort")
        ax.set_ylabel("Coefficient")

    ax = axes[3]
    ax.axvspan(1940, hi, color="#ECE9E3", alpha=0.45, zorder=0)
    for w in ["1982", "1990", "2000"]:
        d = dfs[w]
        ax.plot(
            d["birthyr"],
            d["coefficient"],
            color=colors[w],
            linewidth=2.0,
            marker=markers[w],
            markersize=3.6,
            label=f"Census {w}",
            zorder=2,
        )
    ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0)
    ax.axvline(1940, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)
    ax.set_xlim(1920, hi)
    ax.set_title("D. Overlay (1982/1990/2000)", loc="left", fontsize=12.5, fontweight="bold")
    ax.set_xlabel("Birth cohort")
    ax.set_ylabel("Coefficient")
    ax.legend(frameon=False, loc="best")

    fig.suptitle(
        "Cohort Coefficients (Individual eduy + controls, Drop 1939, Treated >= 1940)",
        x=0.01,
        ha="left",
        fontsize=15,
        fontweight="bold",
    )
    fig.tight_layout(rect=[0, 0.02, 1, 0.96])

    FIG.mkdir(parents=True, exist_ok=True)
    out = FIG / "eventstudy_coefficient_drop1939_start1940_wavecut_2x2_indiv_ctrl_v1.png"
    fig.savefig(out, dpi=320)
    fig.savefig(out.with_suffix(".pdf"))
    print(out)


if __name__ == "__main__":
    main()

