#!/usr/bin/env python3
"""Additional diagnostics plots for treatment and new controls."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

BASE = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war"
)
FIG = BASE / "result" / "figure"
TEMP = BASE / "data" / "temp"


def main() -> None:
    tr = pd.read_stata(TEMP / "martyr_pop1953_treatment_county_v2.dta", convert_categoricals=False)
    c = pd.read_stata(TEMP / "county_controls_full_v1.dta", convert_categoricals=False)
    d = tr[["countyid_curr6", "ln_martyr_per100k_1953", "martyr_per100k_1953"]].merge(
        c[["countyid_curr6", "ln_memorial_cnt", "memorial_cnt_total", "ln_massacre_death", "massacre_event_w"]],
        on="countyid_curr6",
        how="left",
    )
    for v in ["ln_memorial_cnt", "memorial_cnt_total", "ln_massacre_death", "massacre_event_w"]:
        d[v] = d[v].fillna(0.0)

    plt.rcParams.update(
        {
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "axes.grid": True,
            "grid.color": "#DDDDDD",
            "grid.alpha": 0.6,
            "axes.spines.top": False,
            "axes.spines.right": False,
            "font.family": "serif",
            "font.serif": ["Times New Roman", "Songti SC", "Noto Serif CJK SC", "DejaVu Serif"],
            "font.size": 11,
            "axes.unicode_minus": False,
        }
    )

    fig, axes = plt.subplots(2, 2, figsize=(12.8, 10.8))
    axes = axes.flatten()

    axes[0].hist(d["ln_martyr_per100k_1953"].dropna(), bins=45, color="#1F2D4F", alpha=0.85)
    axes[0].set_title("A. Treatment Distribution: ln(1+martyr per 100k)", loc="left", fontweight="bold")
    axes[0].set_xlabel("ln_martyr_per100k_1953")
    axes[0].set_ylabel("Counties")

    axes[1].hist(d["ln_memorial_cnt"].dropna(), bins=45, color="#7A1F2B", alpha=0.85)
    axes[1].set_title("B. Alternative X: ln(1+memorial count)", loc="left", fontweight="bold")
    axes[1].set_xlabel("ln_memorial_cnt")
    axes[1].set_ylabel("Counties")

    x = d["ln_martyr_per100k_1953"].to_numpy()
    y = d["ln_memorial_cnt"].to_numpy()
    axes[2].scatter(x, y, s=10, alpha=0.35, color="#2E4A3F")
    m = np.isfinite(x) & np.isfinite(y)
    if m.sum() > 5:
        b1, b0 = np.polyfit(x[m], y[m], 1)
        xx = np.linspace(np.nanmin(x[m]), np.nanmax(x[m]), 200)
        axes[2].plot(xx, b1 * xx + b0, color="#B03A2E", lw=2)
    axes[2].set_title("C. Correlation: martyr intensity vs memorial intensity", loc="left", fontweight="bold")
    axes[2].set_xlabel("ln_martyr_per100k_1953")
    axes[2].set_ylabel("ln_memorial_cnt")

    axes[3].hist(d["ln_massacre_death"].dropna(), bins=45, color="#5A5A5A", alpha=0.85)
    axes[3].set_title("D. Control Distribution: ln(1+massacre deaths)", loc="left", fontweight="bold")
    axes[3].set_xlabel("ln_massacre_death")
    axes[3].set_ylabel("Counties")

    fig.suptitle("Additional Diagnostics for Treatment and New Robustness Controls", x=0.01, ha="left", fontsize=15, fontweight="bold")
    fig.tight_layout(rect=[0, 0.02, 1, 0.96])

    FIG.mkdir(parents=True, exist_ok=True)
    out = FIG / "additional_diagnostics_2x2_v1.png"
    fig.savefig(out, dpi=320)
    fig.savefig(out.with_suffix(".pdf"))
    print(out)


if __name__ == "__main__":
    main()
