#!/usr/bin/env python3
"""Plot postwar event-study curves for 1982/1990/2000 (pop1953, unweighted)."""

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
            "figure.facecolor": "#F6F5F2",
            "axes.facecolor": "#FCFBF8",
            "axes.grid": True,
            "grid.color": "#D8D3CB",
            "grid.linewidth": 0.7,
            "axes.spines.top": False,
            "axes.spines.right": False,
            "font.family": "serif",
            "font.serif": ["Palatino Linotype", "Times New Roman", "Songti SC", "Noto Serif CJK SC"],
            "font.size": 11,
            "axes.unicode_minus": False,
        }
    )


def _load_coef(wave: str, spec: str) -> pd.DataFrame:
    p = TEMP / f"eventstudy_coef_pop1953_unwt_{wave}_{spec}.csv"
    if not p.exists():
        raise FileNotFoundError(p)
    df = pd.read_csv(p).sort_values("birthyr")
    for c in ["birthyr", "beta", "se", "lb", "ub", "baseyr", "startyr", "sample_hi"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    return df


def _load_stats(wave: str, spec: str) -> dict[str, float]:
    p = TEMP / "eventstudy_spec_scan_pop1953_unwt_multiwave_v1.csv"
    df = pd.read_csv(p)
    row = df[(df["wave"].astype(str) == wave) & (df["spec"] == spec)]
    if row.empty:
        return {"p_pre": float("nan"), "p_post": float("nan"), "b_did": float("nan"), "p_did": float("nan")}
    r = row.iloc[0]
    return {
        "p_pre": float(r["p_pre"]),
        "p_post": float(r["p_post"]),
        "b_did": float(r["b_did"]),
        "p_did": float(r["p_did"]),
    }


def _fmt_p(x: float) -> str:
    if pd.isna(x):
        return "NA"
    if x < 1e-4:
        return f"{x:.1e}"
    return f"{x:.4f}"


def main() -> None:
    _style()
    FIG.mkdir(parents=True, exist_ok=True)

    specs = [
        {"wave": "1982", "spec": "post_w65_base45", "title": "A. Census 1982 (1931-1965)", "color": "#1F5AA6"},
        {"wave": "1990", "spec": "post_w75_base45", "title": "B. Census 1990 (1931-1975)", "color": "#D97904"},
        {"wave": "2000", "spec": "post_w75_base45", "title": "C. Census 2000 (1931-1975)", "color": "#1B7F5C"},
    ]

    fig, axes = plt.subplots(1, 3, figsize=(17.5, 5.8), sharey=False)
    for ax, s in zip(axes, specs):
        df = _load_coef(s["wave"], s["spec"])
        st = _load_stats(s["wave"], s["spec"])
        baseyr = int(df["baseyr"].dropna().iloc[0])
        startyr = int(df["startyr"].dropna().iloc[0])
        endyr = int(df["sample_hi"].dropna().iloc[0])

        ax.axvspan(startyr, endyr, color="#F4E2C8", alpha=0.55, zorder=0)
        ax.fill_between(df["birthyr"], df["lb"], df["ub"], color=s["color"], alpha=0.18, linewidth=0, zorder=1)
        ax.plot(df["birthyr"], df["beta"], color=s["color"], linewidth=2.0, zorder=2)
        ax.scatter(df["birthyr"], df["beta"], color=s["color"], s=15, zorder=3)

        ax.axhline(0, color="#555555", linestyle=(0, (4, 3)), linewidth=0.95)
        ax.axvline(baseyr, color="#111111", linestyle=(0, (2, 2)), linewidth=1.0)
        ax.axvline(startyr, color="#B03A2E", linestyle=(0, (5, 3)), linewidth=1.0)

        ax.set_title(s["title"], loc="left", fontsize=12.3, fontweight="bold")
        ax.set_xlabel("Birth cohort")
        ax.set_ylabel("Relative effect (vs base cohort)")
        ax.set_xlim(df["birthyr"].min() - 0.5, df["birthyr"].max() + 0.5)

        txt = (
            f"DID={st['b_did']:.3f}, p={_fmt_p(st['p_did'])}\n"
            f"Pre-joint p={_fmt_p(st['p_pre'])}\n"
            f"Post-joint p={_fmt_p(st['p_post'])}"
        )
        ax.text(
            0.02,
            0.98,
            txt,
            transform=ax.transAxes,
            va="top",
            ha="left",
            fontsize=9.5,
            bbox={"facecolor": "white", "alpha": 0.75, "edgecolor": "#BEB8AE", "boxstyle": "round,pad=0.25"},
        )

    fig.suptitle(
        "Postwar Event Study (Native-Place Martyr Intensity; normalized by 1953 population)",
        x=0.01,
        ha="left",
        fontsize=15,
        fontweight="bold",
    )
    fig.text(
        0.01,
        0.02,
        "Base cohort: 1945. Shaded area: treated cohorts (>=1946). Dashed black: zero effect. Dashed red: treatment start.",
        fontsize=9.8,
        color="#4D4D4D",
    )
    fig.tight_layout(rect=[0, 0.05, 1, 0.92])

    out = FIG / "eventstudy_pop1953_unwt_multiwave_v1.png"
    fig.savefig(out, dpi=320)
    fig.savefig(out.with_suffix(".pdf"))
    plt.close(fig)
    print(out)


if __name__ == "__main__":
    main()

