from pathlib import Path
import re
import csv
import math

import matplotlib.pyplot as plt

PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
RES = PROJ / "result" / "table"
FIG = PROJ / "paper" / "assets" / "figures"
FIG.mkdir(parents=True, exist_ok=True)


def clean_cell(x: str) -> str:
    return (
        x.replace(r"\sym{***}", "***")
        .replace(r"\sym{**}", "**")
        .replace(r"\sym{*}", "*")
        .replace(r"\_", "_")
        .strip()
    )


def parse_esttab_singlecoef(tex_path: Path):
    lines = tex_path.read_text(errors="ignore").splitlines()
    colnames = None
    coef_vals = None
    se_vals = None
    n_vals = None
    r2_vals = None
    coef_label = None
    for ln in lines:
        if r"\multicolumn{1}{c}{" in ln and "(1)" not in ln and colnames is None:
            parts = re.findall(r"\\multicolumn\{1\}\{c\}\{([^}]*)\}", ln)
            if parts:
                colnames = [clean_cell(p) for p in parts]
                continue
        if "&" in ln and "\\\\" in ln and coef_vals is None and not ln.strip().startswith("&") and r"\hline" not in ln:
            cells = [clean_cell(c) for c in ln.split("&")]
            coef_label = cells[0]
            coef_vals = cells[1:]
            coef_vals[-1] = coef_vals[-1].replace(r"\\", "").strip()
            continue
        if coef_vals is not None and se_vals is None and "&" in ln and "(" in ln:
            cells = [clean_cell(c) for c in ln.split("&")[1:]]
            cells[-1] = cells[-1].replace(r"\\", "").strip()
            se_vals = cells
            continue
        stripped = ln.strip()
        if stripped.startswith(r"\(N\)") or stripped.startswith("Observations"):
            cells = [clean_cell(c) for c in ln.split("&")[1:]]
            cells[-1] = cells[-1].replace(r"\\", "").strip()
            n_vals = cells
            continue
        if stripped.startswith(r"\(R^{2}\)") or stripped.startswith("R-squared"):
            cells = [clean_cell(c) for c in ln.split("&")[1:]]
            cells[-1] = cells[-1].replace(r"\\", "").strip()
            r2_vals = cells
            continue
    rows = []
    if not colnames or not coef_vals:
        raise RuntimeError(f"failed to parse {tex_path}")
    for i, name in enumerate(colnames):
        rows.append(
            {
                "column": i + 1,
                "outcome": name,
                "coef_label": coef_label,
                "b": coef_vals[i] if i < len(coef_vals) else "",
                "se": se_vals[i] if se_vals and i < len(se_vals) else "",
                "N": n_vals[i] if n_vals and i < len(n_vals) else "",
                "r2": r2_vals[i] if r2_vals and i < len(r2_vals) else "",
            }
        )
    return rows


def numeric_from_star(s: str) -> float:
    s = s.replace("***", "").replace("**", "").replace("*", "").strip()
    return float(s)


def numeric_se(s: str) -> float:
    return float(s.replace("(", "").replace(")", "").strip())


def save_csv(rows, out_csv: Path):
    if not rows:
        return
    with out_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def coefficient_plot(rows, title: str, out_png: Path, color: str):
    labels = [r["outcome"] for r in rows]
    b = [numeric_from_star(r["b"]) for r in rows]
    se = [numeric_se(r["se"]) for r in rows]
    lower = [x - 1.96 * s for x, s in zip(b, se)]
    upper = [x + 1.96 * s for x, s in zip(b, se)]

    fig, ax = plt.subplots(figsize=(8.2, 4.6))
    y = list(range(len(labels)))
    ax.axvline(0, color="black", lw=0.8, alpha=0.7)
    ax.errorbar(b, y, xerr=[ [x-l for x,l in zip(b, lower)], [u-x for x,u in zip(b, upper)] ],
                fmt="o", color=color, ecolor=color, elinewidth=1.2, capsize=3)
    ax.set_yticks(y)
    ax.set_yticklabels(labels, fontsize=9)
    ax.set_title(title, fontsize=11)
    ax.set_xlabel("Coefficient with 95% CI", fontsize=10)
    ax.grid(axis="x", alpha=0.2)
    fig.tight_layout()
    fig.savefig(out_png, dpi=200)
    plt.close(fig)


targets = [
    ("mechanism_census1990_ipums_employment_reghdfe_v1.tex", "mechanism_census1990_ipums_employment_reghdfe_summary_v1.csv", "fig_occupational.png", "Employment and Occupation", "#0b5d7a"),
    ("mechanism_census1990_ipums_industry_reghdfe_v1.tex", "mechanism_census1990_ipums_industry_reghdfe_summary_v1.csv", "fig_industry.png", "Industry Sorting", "#7a3b0b"),
    ("mechanism_cgss_attitudes_positive_reghdfe_v1.tex", "mechanism_cgss_attitudes_positive_reghdfe_summary_v1.csv", "fig_cgss_positive.png", "CGSS Positive Attitudes", "#2e6f40"),
    ("mechanism_chip1995_edu_pooled_pref_log_reghdfe_v1.tex", "mechanism_chip1995_edu_pooled_pref_log_reghdfe_summary_v1.csv", "fig_chip_log.png", "CHIP Education Spending", "#8a2846"),
]

for tex_name, csv_name, fig_name, title, color in targets:
    rows = parse_esttab_singlecoef(RES / tex_name)
    save_csv(rows, RES / csv_name)
    coefficient_plot(rows, title, FIG / fig_name, color)
    print("built", csv_name, fig_name)
