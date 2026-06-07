from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
RESULT = PROJ / "result/table"
FIG = PROJ / "paper/assets/figures"

plt.rcParams.update(
    {
        "font.family": "serif",
        "font.serif": ["Libertinus Serif", "Times New Roman", "DejaVu Serif"],
        "font.size": 10,
        "axes.titlesize": 12,
        "axes.labelsize": 10,
    }
)

graduation_labels = {
    "primary": "Primary",
    "junior_high": "Junior high",
    "senior_high": "Senior high",
    "college": "College",
}

robust_labels = {
    "baseline": "Baseline",
    "sdy_density": "SDY density",
    "famine": "Famine",
    "victims": "Victims",
    "grain_output": "Grain output",
    "urbanization": "Urbanization",
}


def coefplot_with_ci(ax, xpos, b, se, color):
    ax.errorbar(xpos, b, 1.96 * se, fmt="o", color=color, capsize=3, lw=1.2)


for cutoff in (1940, 1946):
    for wave in (1982, 1990, 2000):
        p = RESULT / f"graduation_rates_{wave}_cutoff{cutoff}_v2.csv"
        if not p.exists():
            continue
        df = pd.read_csv(p)
        fig, ax = plt.subplots(figsize=(8.3, 4.8))
        outcomes = ["primary", "junior_high", "senior_high", "college"]
        base_x = range(len(outcomes))
        for i, out in enumerate(outcomes):
            row_b = df[(df["outcome"] == out) & (df["spec"] == "baseline")].iloc[0]
            row_f = df[(df["outcome"] == out) & (df["spec"] == "all_five")].iloc[0]
            coefplot_with_ci(ax, i - 0.12, row_b["b"], row_b["se"], "#1f4e79")
            coefplot_with_ci(ax, i + 0.12, row_f["b"], row_f["se"], "#b45f06")
        ax.axhline(0, color="black", lw=0.8)
        ax.set_xticks(list(base_x))
        ax.set_xticklabels([graduation_labels[o] for o in outcomes])
        ax.set_ylabel("Coefficient")
        ax.set_title(f"Graduation Outcomes, {wave} Census, cutoff {cutoff}")
        ax.legend(
            [
                plt.Line2D([0], [0], marker="o", color="#1f4e79", lw=1.2),
                plt.Line2D([0], [0], marker="o", color="#b45f06", lw=1.2),
            ],
            ["Baseline", "+ all five"],
            frameon=False,
            loc="best",
        )
        fig.tight_layout()
        fig.savefig(FIG / f"fig_grad_{wave}_cutoff{cutoff}_v2.png", dpi=220)
        plt.close(fig)


for cutoff in (1940, 1946):
    for wave in (1982, 1990, 2000):
        p = RESULT / f"historical_shocks_{wave}_cutoff{cutoff}_onebyone_v1.csv"
        if not p.exists():
            continue
        df = pd.read_csv(p)
        df["label"] = df["spec"].map(robust_labels)
        fig, ax = plt.subplots(figsize=(8.3, 4.8))
        y = list(range(len(df)))[::-1]
        ax.errorbar(df["b"], y, xerr=1.96 * df["se"], fmt="o", color="#8c2d04", capsize=3)
        ax.axvline(0, color="black", lw=0.8)
        ax.set_yticks(y)
        ax.set_yticklabels(df["label"])
        ax.set_xlabel("Coefficient")
        ax.set_title(f"Historical-shock robustness, {wave} Census, cutoff {cutoff}")
        fig.tight_layout()
        fig.savefig(FIG / f"fig_histshock_{wave}_cutoff{cutoff}.png", dpi=220)
        plt.close(fig)


p = RESULT / "mechanism_cgss_foreign_attitudes_reghdfe_summary_v1.csv"
if p.exists():
    df = pd.read_csv(p)
    fig, ax = plt.subplots(figsize=(8.3, 4.8))
    y = list(range(len(df)))[::-1]
    ax.errorbar(df["b"], y, xerr=1.96 * df["se"], fmt="o", color="#2b6cb0", capsize=3)
    ax.axvline(0, color="black", lw=0.8)
    ax.set_yticks(y)
    ax.set_yticklabels(df["outcome_label"])
    ax.set_xlabel("Coefficient")
    ax.set_title("CGSS foreign attitudes")
    fig.tight_layout()
    fig.savefig(FIG / "fig_cgss_foreign_attitudes.png", dpi=220)
    plt.close(fig)
