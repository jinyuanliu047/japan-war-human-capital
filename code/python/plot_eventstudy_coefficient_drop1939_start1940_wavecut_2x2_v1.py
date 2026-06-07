#!/usr/bin/env python3
"""2x2 panel for wave-specific and overlay coefficient lines."""

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
    p = TEMP / f"eventstudy_coefficient_drop1939_start1940_{wave}_v1.csv"
    df = pd.read_csv(p)
    df["birthyr"] = pd.to_numeric(df["birthyr"], errors="coerce")
    df["coefficient"] = pd.to_numeric(df["coefficient"], errors="coerce")
    df["lb"] = pd.to_numeric(df["lb"], errors="coerce")
    df["ub"] = pd.to_numeric(df["ub"], errors="coerce")
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

    colors = {
        "1982": "#1F2D4F",  # navy
        "1990": "#7A1F2B",  # maroon
        "2000": "#2E4A3F",  # deep green
    }
    labels = {"1982": "A. Census 1982", "1990": "B. Census 1990", "2000": "C. Census 2000"}
    dfs = {w: _load(w) for w in ["1982", "1990", "2000"]}

    fig, axes = plt.subplots(2, 2, figsize=(12.6, 10.6))
    axes = axes.flatten()

    # A/B/C: individual lines
    for i, w in enumerate(["1982", "1990", "2000"]):
        ax = axes[i]
        df = dfs[w]
        ax.axvspan(1940, 1978, color="#ECE9E3", alpha=0.45, zorder=0)
        ax.fill_between(df["birthyr"], df["lb"], df["ub"], color=colors[w], alpha=0.18, linewidth=0, zorder=1)
        ax.plot(df["birthyr"], df["coefficient"], color=colors[w], linewidth=2.0)
        ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0)
        ax.axvline(1940, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)
        ax.set_xlim(1920, 1978)
        ax.set_title(labels[w], loc="left", fontsize=12.5, fontweight="bold")
        ax.set_xlabel("Birth cohort")
        ax.set_ylabel("Coefficient")

    # D: overlay
    ax = axes[3]
    ax.axvspan(1940, 1978, color="#ECE9E3", alpha=0.45, zorder=0)
    for w in ["1982", "1990", "2000"]:
        df = dfs[w]
        ax.plot(df["birthyr"], df["coefficient"], color=colors[w], linewidth=2.0, label=f"Census {w}")
    ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0)
    ax.axvline(1940, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)
    ax.set_xlim(1920, 1978)
    ax.set_title("D. Overlay (1982/1990/2000)", loc="left", fontsize=12.5, fontweight="bold")
    ax.set_xlabel("Birth cohort")
    ax.set_ylabel("Coefficient")
    ax.legend(frameon=False, loc="best")

    fig.suptitle(
        "Cohort Coefficients (Drop 1939, Treated Cohorts >= 1940)",
        x=0.01,
        ha="left",
        fontsize=15,
        fontweight="bold",
    )
    fig.tight_layout(rect=[0, 0.02, 1, 0.96])

    out = FIG / "eventstudy_coefficient_drop1939_start1940_wavecut_2x2_v1.png"
    fig.savefig(out, dpi=320)
    fig.savefig(out.with_suffix(".pdf"))
    print(out)


if __name__ == "__main__":
    main()
