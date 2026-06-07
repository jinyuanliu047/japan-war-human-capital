#!/usr/bin/env python3
"""Draw publication-style postwar event-study figures (v4)."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


BASE = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
)
TEMP = BASE / "data" / "temp"
FIG = BASE / "result" / "figure"


def _load(stub: str) -> pd.DataFrame:
    p = TEMP / f"{stub}.csv"
    if not p.exists():
        raise FileNotFoundError(f"Missing input file: {p}")
    df = pd.read_csv(p)
    df = df.sort_values("birthyr").reset_index(drop=True)
    for c in ["birthyr", "beta", "lb", "ub", "baseyr", "tstart", "tend"]:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")
    return df


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
            "axes.labelcolor": "#2B2B2B",
            "xtick.color": "#2B2B2B",
            "ytick.color": "#2B2B2B",
            "font.size": 11,
            "font.family": "serif",
            "font.serif": ["DejaVu Serif", "Songti SC", "Noto Serif CJK SC", "Times New Roman"],
            "axes.unicode_minus": False,
            "axes.titlesize": 13,
            "axes.titleweight": "bold",
            "axes.labelsize": 11,
            "legend.frameon": False,
        }
    )


def _plot_single(
    df: pd.DataFrame,
    title: str,
    subtitle: str,
    out_png: Path,
    color: str,
) -> None:
    base = int(df["baseyr"].iloc[0])
    tstart = int(df["tstart"].iloc[0])
    tend = int(df["tend"].iloc[0])

    fig, ax = plt.subplots(figsize=(10.8, 6.3))
    ax.axvspan(tstart, tend, color="#FEE8C8", alpha=0.55, zorder=0, label="Treated cohorts")
    ax.fill_between(df["birthyr"], df["lb"], df["ub"], color=color, alpha=0.18, linewidth=0, zorder=1)
    ax.plot(df["birthyr"], df["beta"], color=color, linewidth=2.1, zorder=2)
    ax.scatter(df["birthyr"], df["beta"], color=color, s=18, zorder=3)

    ax.axhline(0, color="#5C5C5C", linestyle=(0, (4, 3)), linewidth=1.0, zorder=1)
    ax.axvline(base, color="#111111", linestyle=(0, (2, 2)), linewidth=1.0, zorder=2)
    ax.axvline(tstart, color="#B22222", linestyle=(0, (5, 3)), linewidth=1.0, zorder=2)
    ax.axvline(tend, color="#B22222", linestyle=(0, (5, 3)), linewidth=1.0, zorder=2)

    ax.set_title(title, loc="left", pad=10)
    ax.text(
        0.0,
        1.01,
        subtitle,
        transform=ax.transAxes,
        ha="left",
        va="bottom",
        fontsize=10.2,
        color="#4A4A4A",
    )
    ax.set_xlabel("Birth cohort")
    ax.set_ylabel("Effect relative to base cohort")
    ax.set_xlim(df["birthyr"].min() - 0.5, df["birthyr"].max() + 0.5)

    y_min = float(df["lb"].min())
    y_max = float(df["ub"].max())
    pad = max(0.003, 0.12 * (y_max - y_min))
    ax.set_ylim(y_min - pad, y_max + pad)

    note = f"Base cohort: {base}. Red dashed lines: treated-window bounds ({tstart}-{tend})."
    fig.text(0.01, 0.012, note, fontsize=9.5, color="#4D4D4D")

    fig.tight_layout(rect=[0, 0.04, 1, 1])
    fig.savefig(out_png, dpi=320)
    fig.savefig(out_png.with_suffix(".pdf"))
    plt.close(fig)


def _plot_panel(specs: list[dict], out_png: Path) -> None:
    fig, axes = plt.subplots(2, 2, figsize=(15.2, 9.6), sharey=False)
    axes = axes.flatten()

    for ax, s in zip(axes, specs):
        df = s["df"]
        base = int(df["baseyr"].iloc[0])
        tstart = int(df["tstart"].iloc[0])
        tend = int(df["tend"].iloc[0])
        color = s["color"]

        ax.axvspan(tstart, tend, color="#FEE8C8", alpha=0.5, zorder=0)
        ax.fill_between(df["birthyr"], df["lb"], df["ub"], color=color, alpha=0.18, linewidth=0, zorder=1)
        ax.plot(df["birthyr"], df["beta"], color=color, linewidth=1.9, zorder=2)
        ax.scatter(df["birthyr"], df["beta"], color=color, s=14, zorder=3)

        ax.axhline(0, color="#5C5C5C", linestyle=(0, (4, 3)), linewidth=0.9, zorder=1)
        ax.axvline(base, color="#111111", linestyle=(0, (2, 2)), linewidth=0.9, zorder=2)
        ax.axvline(tstart, color="#B22222", linestyle=(0, (5, 3)), linewidth=0.9, zorder=2)
        ax.axvline(tend, color="#B22222", linestyle=(0, (5, 3)), linewidth=0.9, zorder=2)

        ax.set_title(s["title"], loc="left", fontsize=11.8, pad=7)
        ax.text(
            0.0,
            1.0,
            s["subtitle"],
            transform=ax.transAxes,
            ha="left",
            va="bottom",
            fontsize=9.2,
            color="#4A4A4A",
        )
        ax.set_xlabel("Birth cohort", fontsize=10.3)
        ax.set_ylabel("Relative effect", fontsize=10.3)
        ax.set_xlim(df["birthyr"].min() - 0.5, df["birthyr"].max() + 0.5)

    fig.suptitle("Postwar Event Study (Native-Place Martyr Intensity)", x=0.01, ha="left", fontsize=15, fontweight="bold")
    fig.text(
        0.01,
        0.013,
        "Shaded zone = treated cohorts. Red dashed lines = treatment window bounds. Black dotted line = base cohort.",
        fontsize=10,
        color="#4D4D4D",
    )
    fig.tight_layout(rect=[0, 0.04, 1, 0.95])
    fig.savefig(out_png, dpi=320)
    fig.savefig(out_png.with_suffix(".pdf"))
    plt.close(fig)


def main() -> None:
    _style()

    specs = [
        {
            "stub": "es_postwar_schentry_wide_prebase_v4",
            "title": "A. School-entry postwar (wide)",
            "subtitle": "Pre-period base (1942); treated 1943-1960",
            "color": "#0B5FA5",
            "out": FIG / "eventstudy_postwar_schentry_wide_prebase_v4.png",
        },
        {
            "stub": "es_postwar_birth_wide_prebase_v4",
            "title": "B. Birth postwar (wide)",
            "subtitle": "Pre-period base (1945); treated 1946-1960",
            "color": "#D95F02",
            "out": FIG / "eventstudy_postwar_birth_wide_prebase_v4.png",
        },
        {
            "stub": "es_postwar_schentry_wide_currentbase_v4",
            "title": "C. School-entry postwar (wide)",
            "subtitle": "Current-period base (1943); treated 1943-1960",
            "color": "#0B5FA5",
            "out": FIG / "eventstudy_postwar_schentry_wide_currentbase_v4.png",
        },
        {
            "stub": "es_postwar_birth_wide_currentbase_v4",
            "title": "D. Birth postwar (wide)",
            "subtitle": "Current-period base (1946); treated 1946-1960",
            "color": "#D95F02",
            "out": FIG / "eventstudy_postwar_birth_wide_currentbase_v4.png",
        },
    ]

    for s in specs:
        s["df"] = _load(s["stub"])
        _plot_single(
            df=s["df"],
            title=s["title"],
            subtitle=s["subtitle"],
            out_png=s["out"],
            color=s["color"],
        )

    _plot_panel(specs, FIG / "eventstudy_postwar_main_v4_panel.png")
    print("saved:")
    for s in specs:
        print(s["out"])
    print(FIG / "eventstudy_postwar_main_v4_panel.png")


if __name__ == "__main__":
    main()
