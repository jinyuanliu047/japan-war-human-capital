#!/usr/bin/env python3
"""Overlay plot of cohort coefficients across three census waves."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


BASE = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
)
TEMP = BASE / "data" / "temp"
FIG = BASE / "result" / "figure"


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

    series = [
        ("1982", "#1F5AA6", "Census 1982"),
        ("1990", "#D97904", "Census 1990"),
        ("2000", "#1B7F5C", "Census 2000"),
    ]

    fig, ax = plt.subplots(figsize=(10.8, 6.4))
    for wave, color, label in series:
        df = pd.read_csv(TEMP / f"eventstudy_coefficient_drop1939_start1940_{wave}_v1.csv")
        df["birthyr"] = pd.to_numeric(df["birthyr"], errors="coerce")
        df["coefficient"] = pd.to_numeric(df["coefficient"], errors="coerce")
        df = df.sort_values("birthyr")
        ax.plot(df["birthyr"], df["coefficient"], color=color, linewidth=2.0, label=label)

    ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0)
    ax.axvline(1940, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)
    ax.axvspan(1940, 1978, color="#FBE9D5", alpha=0.38, zorder=0)

    ax.set_title("Overlay of Cohort Coefficients (Drop 1939, Treated >= 1940)", loc="left", fontsize=14, fontweight="bold")
    ax.set_xlabel("Birth cohort")
    ax.set_ylabel("Coefficient")
    ax.set_xlim(1920, 1978)
    ax.legend(frameon=False, loc="best")

    fig.tight_layout()

    out = FIG / "eventstudy_coefficient_drop1939_start1940_wavecut_overlay_v1.png"
    fig.savefig(out, dpi=320)
    fig.savefig(out.with_suffix(".pdf"))
    print(out)


if __name__ == "__main__":
    main()

