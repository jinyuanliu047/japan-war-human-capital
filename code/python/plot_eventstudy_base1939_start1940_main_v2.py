#!/usr/bin/env python3
"""Clean event-study plots for base 1939 / treated 1940+."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


BASE = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
)
TEMP = BASE / "data" / "temp"
FIG = BASE / "result" / "figure"


def _style() -> None:
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


def _fmt_p(x: float) -> str:
    if pd.isna(x):
        return "NA"
    if x < 1e-4:
        return f"{x:.1e}"
    return f"{x:.4f}"


def main() -> None:
    _style()
    summary = pd.read_csv(TEMP / "eventstudy_base1939_start1940_main_summary_v1.csv")
    for c in ["b_did", "se_did", "p_did", "p_pre", "p_post"]:
        summary[c] = pd.to_numeric(summary[c], errors="coerce")

    waves = [
        ("1982", "#1F5AA6", "A. Census 1982"),
        ("1990", "#D97904", "B. Census 1990"),
        ("2000", "#1B7F5C", "C. Census 2000"),
    ]

    fig, axes = plt.subplots(1, 3, figsize=(17.2, 5.8), sharey=False)
    for ax, (wave, color, title) in zip(axes, waves):
        df = pd.read_csv(TEMP / f"eventstudy_coef_base1939_start1940_main_{wave}_v1.csv")
        for c in ["birthyr", "beta", "lb", "ub", "startyr", "baseyr"]:
            df[c] = pd.to_numeric(df[c], errors="coerce")
        df = df.sort_values("birthyr")
        row = summary[summary["wave"].astype(str) == wave].iloc[0]

        startyr = int(df["startyr"].dropna().iloc[0])  # 1940
        baseyr = int(df["baseyr"].dropna().iloc[0])    # 1939
        maxyr = int(df["sample_hi"].dropna().iloc[0]) if "sample_hi" in df else int(df["birthyr"].max())

        ax.axvspan(startyr, maxyr, color="#FBE9D5", alpha=0.45, zorder=0)
        ax.fill_between(df["birthyr"], df["lb"], df["ub"], color=color, alpha=0.18, linewidth=0, zorder=1)
        ax.plot(df["birthyr"], df["beta"], color=color, linewidth=2.0, zorder=2)
        ax.scatter(df["birthyr"], df["beta"], color=color, s=14, zorder=3)

        ax.axhline(0, color="#666666", linestyle=(0, (4, 3)), linewidth=0.95, zorder=1)
        ax.axvline(baseyr, color="#111111", linestyle=(0, (2, 2)), linewidth=1.0, zorder=2)
        ax.axvline(startyr, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0, zorder=2)

        ax.set_title(title, loc="left", fontsize=12.3, fontweight="bold")
        ax.set_xlabel("Birth cohort")
        ax.set_ylabel("Relative effect (base cohort = 1939)")
        ax.set_xlim(df["birthyr"].min() - 0.5, df["birthyr"].max() + 0.5)

        txt = (
            f"DID={row['b_did']:.3f}, p={_fmt_p(row['p_did'])}\n"
            f"Pre-joint p={_fmt_p(row['p_pre'])}\n"
            f"Post-joint p={_fmt_p(row['p_post'])}"
        )
        ax.text(
            0.02,
            0.98,
            txt,
            transform=ax.transAxes,
            va="top",
            ha="left",
            fontsize=9.4,
            bbox={"facecolor": "white", "alpha": 0.82, "edgecolor": "#BEB8AE", "boxstyle": "round,pad=0.25"},
        )

    fig.suptitle(
        "Event Study (Base 1939, Treated Cohorts >= 1940)",
        x=0.01,
        ha="left",
        fontsize=15,
        fontweight="bold",
    )
    fig.text(
        0.01,
        0.02,
        "Treatment variable: ln(1 + martyrs per 100k, 1953 population). Shaded area = treated cohorts.",
        fontsize=9.8,
        color="#4D4D4D",
    )
    fig.tight_layout(rect=[0, 0.05, 1, 0.92])

    out = FIG / "eventstudy_base1939_start1940_main_v2.png"
    fig.savefig(out, dpi=320)
    fig.savefig(out.with_suffix(".pdf"))
    print(out)


if __name__ == "__main__":
    main()

