#!/usr/bin/env python3
"""Generate ratio-based event-study plots (3 single + overlay + 2x2 panel)."""

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
    p = TEMP / f"eventstudy_coefficient_drop1939_start1940_{wave}_ratio_v1.csv"
    df = pd.read_csv(p)
    for c in ["birthyr", "coefficient", "lb", "ub", "sample_hi"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    return df.sort_values("birthyr")


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
            "font.serif": ["Cambria", "Times New Roman", "Times", "DejaVu Serif"],
            "font.size": 11,
            "axes.unicode_minus": False,
        }
    )


def _plot_single_with_ci(df: pd.DataFrame, title: str, color: str, marker: str, out_prefix: Path) -> None:
    hi = int(df["sample_hi"].dropna().iloc[0])
    fig, ax = plt.subplots(figsize=(7.2, 5.6))
    ax.axvspan(1940, hi, color="#EEE8DF", alpha=0.46, zorder=0)
    ax.fill_between(df["birthyr"], df["lb"], df["ub"], color=color, alpha=0.18, linewidth=0, zorder=1)
    ax.plot(df["birthyr"], df["coefficient"], color=color, linewidth=2.1, marker=marker, markersize=3.9, zorder=2)
    ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0)
    ax.axvline(1940, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)
    ax.set_title(title, loc="left", fontsize=13, fontweight="bold")
    ax.set_xlabel("Birth cohort")
    ax.set_ylabel("Coefficient")
    ax.set_xlim(1920, hi)
    fig.tight_layout()
    fig.savefig(out_prefix.with_suffix(".png"), dpi=320)
    fig.savefig(out_prefix.with_suffix(".pdf"))
    plt.close(fig)


def _plot_single_overlay(dfs: dict[str, pd.DataFrame], out_prefix: Path) -> None:
    colors = {"1982": "#1F2D4F", "1990": "#7A1F2B", "2000": "#2E4A3F"}
    markers = {"1982": "o", "1990": "^", "2000": "s"}
    labels = {"1982": "Census 1982", "1990": "Census 1990", "2000": "Census 2000"}
    hi = max(int(d["sample_hi"].dropna().iloc[0]) for d in dfs.values())

    fig, ax = plt.subplots(figsize=(7.2, 5.6))
    ax.axvspan(1940, hi, color="#EEE8DF", alpha=0.46, zorder=0)
    for w in ["1982", "1990", "2000"]:
        d = dfs[w]
        ax.plot(
            d["birthyr"],
            d["coefficient"],
            color=colors[w],
            linewidth=2.1,
            marker=markers[w],
            markersize=3.9,
            label=labels[w],
            zorder=2,
        )
    ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0)
    ax.axvline(1940, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)
    ax.set_title("D. Overlay (1982/1990/2000)", loc="left", fontsize=13, fontweight="bold")
    ax.set_xlabel("Birth cohort")
    ax.set_ylabel("Coefficient")
    ax.set_xlim(1920, hi)
    ax.legend(frameon=False, loc="best")
    fig.tight_layout()
    fig.savefig(out_prefix.with_suffix(".png"), dpi=320)
    fig.savefig(out_prefix.with_suffix(".pdf"))
    plt.close(fig)


def _plot_2x2(dfs: dict[str, pd.DataFrame], out_prefix: Path) -> None:
    colors = {"1982": "#1F2D4F", "1990": "#7A1F2B", "2000": "#2E4A3F"}
    markers = {"1982": "o", "1990": "^", "2000": "s"}
    titles = {"1982": "A. Census 1982", "1990": "B. Census 1990", "2000": "C. Census 2000"}
    hi = max(int(d["sample_hi"].dropna().iloc[0]) for d in dfs.values())

    fig, axes = plt.subplots(2, 2, figsize=(12.8, 10.8))
    axes = axes.flatten()

    for i, w in enumerate(["1982", "1990", "2000"]):
        ax = axes[i]
        d = dfs[w]
        ax.axvspan(1940, hi, color="#EEE8DF", alpha=0.46, zorder=0)
        ax.fill_between(d["birthyr"], d["lb"], d["ub"], color=colors[w], alpha=0.18, linewidth=0, zorder=1)
        ax.plot(d["birthyr"], d["coefficient"], color=colors[w], linewidth=2.1, marker=markers[w], markersize=3.7, zorder=2)
        ax.axhline(0, color="#4E4E4E", linestyle=(0, (4, 3)), linewidth=1.0)
        ax.axvline(1940, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)
        ax.set_xlim(1920, hi)
        ax.set_title(titles[w], loc="left", fontsize=12.5, fontweight="bold")
        ax.set_xlabel("Birth cohort")
        ax.set_ylabel("Coefficient")

    ax = axes[3]
    ax.axvspan(1940, hi, color="#EEE8DF", alpha=0.46, zorder=0)
    for w in ["1982", "1990", "2000"]:
        d = dfs[w]
        ax.plot(
            d["birthyr"],
            d["coefficient"],
            color=colors[w],
            linewidth=2.1,
            marker=markers[w],
            markersize=3.7,
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

    fig.tight_layout()
    fig.savefig(out_prefix.with_suffix(".png"), dpi=320)
    fig.savefig(out_prefix.with_suffix(".pdf"))
    plt.close(fig)


def main() -> None:
    _style()
    FIG.mkdir(parents=True, exist_ok=True)

    dfs = {w: _load(w) for w in ["1982", "1990", "2000"]}

    _plot_single_with_ci(
        dfs["1982"],
        "A. Census 1982",
        "#1F2D4F",
        "o",
        FIG / "eventstudy_coefficient_drop1939_start1940_wavecut_ratio_A_1982_v1",
    )
    _plot_single_with_ci(
        dfs["1990"],
        "B. Census 1990",
        "#7A1F2B",
        "^",
        FIG / "eventstudy_coefficient_drop1939_start1940_wavecut_ratio_B_1990_v1",
    )
    _plot_single_with_ci(
        dfs["2000"],
        "C. Census 2000",
        "#2E4A3F",
        "s",
        FIG / "eventstudy_coefficient_drop1939_start1940_wavecut_ratio_C_2000_v1",
    )
    _plot_single_overlay(
        dfs,
        FIG / "eventstudy_coefficient_drop1939_start1940_wavecut_ratio_D_overlay_v1",
    )
    _plot_2x2(
        dfs,
        FIG / "eventstudy_coefficient_drop1939_start1940_wavecut_ratio_2x2_v1",
    )

    print(FIG / "eventstudy_coefficient_drop1939_start1940_wavecut_ratio_2x2_v1.pdf")


if __name__ == "__main__":
    main()
