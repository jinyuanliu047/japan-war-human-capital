#!/usr/bin/env python3
"""Plot cohort coefficients with 1939 dropped and treated cohorts >=1940."""

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

    summary = pd.read_csv(TEMP / "eventstudy_coefficient_drop1939_start1940_wavecut_summary_v1.csv")
    for c in ["b_did", "se_did", "p_did", "p_pre_equal1938", "p_post_equal1938", "sample_hi"]:
        summary[c] = pd.to_numeric(summary[c], errors="coerce")

    specs = [
        ("1982", "#1F5AA6", "A. Census 1982"),
        ("1990", "#D97904", "B. Census 1990"),
        ("2000", "#1B7F5C", "C. Census 2000"),
    ]

    fig, axes = plt.subplots(1, 3, figsize=(17.4, 5.9), sharey=False)
    for ax, (wave, color, title) in zip(axes, specs):
        df = pd.read_csv(TEMP / f"eventstudy_coefficient_drop1939_start1940_{wave}_v1.csv")
        for c in ["birthyr", "coefficient", "lb", "ub", "startyr", "sample_hi"]:
            df[c] = pd.to_numeric(df[c], errors="coerce")
        df = df.sort_values("birthyr")

        row = summary[summary["wave"].astype(str) == wave].iloc[0]
        start = int(df["startyr"].dropna().iloc[0])  # 1940
        hi = int(df["sample_hi"].dropna().iloc[0])

        ax.axvspan(start, hi, color="#FBE9D5", alpha=0.45, zorder=0)
        ax.fill_between(df["birthyr"], df["lb"], df["ub"], color=color, alpha=0.18, linewidth=0, zorder=1)
        ax.plot(df["birthyr"], df["coefficient"], color=color, linewidth=2.0, zorder=2)
        ax.scatter(df["birthyr"], df["coefficient"], color=color, s=12, zorder=3)

        ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0, zorder=1)
        ax.axvline(start, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0, zorder=2)

        ax.set_title(f"{title} (end={hi})", loc="left", fontsize=12.2, fontweight="bold")
        ax.set_xlabel("Birth cohort")
        ax.set_ylabel("Coefficient")
        ax.set_xlim(df["birthyr"].min() - 0.5, df["birthyr"].max() + 0.5)

        txt = (
            f"DID={row['b_did']:.3f}, p={_fmt_p(row['p_did'])}\n"
            f"Pre(equal-1938) p={_fmt_p(row['p_pre_equal1938'])}\n"
            f"Post(equal-1938) p={_fmt_p(row['p_post_equal1938'])}"
        )
        ax.text(
            0.02,
            0.98,
            txt,
            transform=ax.transAxes,
            va="top",
            ha="left",
            fontsize=9.2,
            bbox={"facecolor": "white", "alpha": 0.84, "edgecolor": "#BEB8AE", "boxstyle": "round,pad=0.25"},
        )

    fig.suptitle(
        "Cohort Coefficients (Drop 1939, Treated >= 1940, Wave-Specific Cutoffs)",
        x=0.01,
        ha="left",
        fontsize=14.8,
        fontweight="bold",
    )
    fig.text(
        0.01,
        0.02,
        "Treatment variable: ln(1 + martyrs per 100k, pop1953). Shaded area is treated cohorts.",
        fontsize=9.8,
        color="#4D4D4D",
    )
    fig.tight_layout(rect=[0, 0.05, 1, 0.92])

    out = FIG / "eventstudy_coefficient_drop1939_start1940_wavecut_v1.png"
    fig.savefig(out, dpi=320)
    fig.savefig(out.with_suffix(".pdf"))
    print(out)


if __name__ == "__main__":
    main()

