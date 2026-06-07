from pathlib import Path
import math
import pandas as pd
import matplotlib.pyplot as plt

PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
RESULT = PROJ / "result" / "table"
PAPER_TABLE = PROJ / "paper" / "assets" / "tables"
PAPER_FIG = PROJ / "paper" / "assets" / "figures"

PAPER_TABLE.mkdir(parents=True, exist_ok=True)
PAPER_FIG.mkdir(parents=True, exist_ok=True)


def stars(p):
    if pd.isna(p):
        return ""
    if p < 0.01:
        return "***"
    if p < 0.05:
        return "**"
    if p < 0.1:
        return "*"
    return ""


def fmt_coef(b, p):
    if pd.isna(b):
        return ""
    return f"{b:.3f}{stars(p)}"


def fmt_se(se):
    if pd.isna(se):
        return ""
    return f"({se:.3f})"


def load_row(df, panel, subgroup):
    sub = df[(df["panel"] == panel) & (df["subgroup"] == subgroup)]
    if sub.empty:
        return None
    return sub.iloc[0]


def build_table(df, wave, cutoff):
    cols = [
        ("Female", "gender", "female"),
        ("Male", "gender", "male"),
        ("Urban", "urban", "urban"),
        ("Rural", "urban", "rural"),
        ("Low", "baseedu", "B1"),
        ("Middle", "baseedu", "B2"),
        ("High", "baseedu", "B3"),
        ("Non-base", "antijap", "base0"),
        ("Base", "antijap", "base1"),
    ]
    headers = [c[0] for c in cols]
    nums = [f"({i})" for i in range(1, len(cols) + 1)]

    lines = []
    lines.append("\\begin{tabular}{l*{9}{c}}")
    lines.append("\\toprule")
    lines.append(f" & " + " & ".join(headers) + " \\\\")
    lines.append(f" & " + " & ".join(nums) + " \\\\")
    lines.append("\\midrule")
    lines.append("\\multicolumn{10}{l}{\\textbf{Panel A: Gender and Urban-Rural Heterogeneity}}\\\\")

    for label, panel, subg in [("Post-war cohort $\\times$ War exposure", "gender", "female"),
                               ("", "gender", "male")]:
        pass

    # Panel A
    coef_row = []
    se_row = []
    for _, panel, subg in cols[:4]:
        row = load_row(df, panel, subg)
        if row is None:
            coef_row.append("")
            se_row.append("")
        else:
            coef_row.append(fmt_coef(row["b"], row["p"]))
            se_row.append(fmt_se(row["se"]))
    coef_row.extend([""] * 5)
    se_row.extend([""] * 5)
    lines.append("Post-war cohort $\\times$ War exposure & " + " & ".join(coef_row) + " \\\\")
    lines.append(" & " + " & ".join(se_row) + " \\\\")
    gd_gender = load_row(df, "gender", "group_diff")
    gd_urban = load_row(df, "urban", "group_diff")
    diff_coef = ["", "", fmt_coef(gd_urban["b"], gd_urban["p"]) if gd_urban is not None else "", "",
                 "", "", "", "", ""]
    diff_se = ["", "", fmt_se(gd_urban["se"]) if gd_urban is not None else "", "",
               "", "", "", "", ""]
    if gd_gender is not None:
        diff_coef[0] = fmt_coef(gd_gender["b"], gd_gender["p"])
        diff_se[0] = fmt_se(gd_gender["se"])
    lines.append("Group diff. & " + " & ".join(diff_coef) + " \\\\")
    lines.append(" & " + " & ".join(diff_se) + " \\\\")

    lines.append("\\midrule")
    lines.append("\\multicolumn{10}{l}{\\textbf{Panel B: Base Education Terciles}}\\\\")
    coef_row = [""] * 4
    se_row = [""] * 4
    for _, panel, subg in cols[4:7]:
        row = load_row(df, panel, subg)
        coef_row.append(fmt_coef(row["b"], row["p"]) if row is not None else "")
        se_row.append(fmt_se(row["se"]) if row is not None else "")
    coef_row.extend(["", ""])
    se_row.extend(["", ""])
    lines.append("Post-war cohort $\\times$ War exposure & " + " & ".join(coef_row) + " \\\\")
    lines.append(" & " + " & ".join(se_row) + " \\\\")
    low_high = load_row(df, "baseedu", "low_high_diff")
    mid_high = load_row(df, "baseedu", "mid_high_diff")
    lines.append("Low-High diff. &  &  &  &  & " + (fmt_coef(low_high["b"], low_high["p"]) if low_high is not None else "") + " &  &  &  &  \\\\")
    lines.append(" &  &  &  &  & " + (fmt_se(low_high["se"]) if low_high is not None else "") + " &  &  &  &  \\\\")
    lines.append("Mid-High diff. &  &  &  &  &  & " + (fmt_coef(mid_high["b"], mid_high["p"]) if mid_high is not None else "") + " &  &  &  \\\\")
    lines.append(" &  &  &  &  &  & " + (fmt_se(mid_high["se"]) if mid_high is not None else "") + " &  &  &  \\\\")

    lines.append("\\midrule")
    lines.append("\\multicolumn{10}{l}{\\textbf{Panel C: Anti-Japanese Base}}\\\\")
    coef_row = [""] * 7
    se_row = [""] * 7
    for _, panel, subg in cols[7:]:
        row = load_row(df, panel, subg)
        coef_row.append(fmt_coef(row["b"], row["p"]) if row is not None else "")
        se_row.append(fmt_se(row["se"]) if row is not None else "")
    lines.append("Post-war cohort $\\times$ War exposure & " + " & ".join(coef_row) + " \\\\")
    lines.append(" & " + " & ".join(se_row) + " \\\\")
    gd_base = load_row(df, "antijap", "group_diff")
    lines.append("Group diff. &  &  &  &  &  &  &  & " + (fmt_coef(gd_base["b"], gd_base["p"]) if gd_base is not None else "") + " &  \\\\")
    lines.append(" &  &  &  &  &  &  &  & " + (fmt_se(gd_base["se"]) if gd_base is not None else "") + " &  \\\\")

    n_cells = int(df["n_cells"].max()) if not df.empty else 0
    n_counties = int(df["n_counties"].max()) if not df.empty else 0
    lines.append("\\midrule")
    lines.append("County FE & \\cmark & \\cmark & \\cmark & \\cmark & \\cmark & \\cmark & \\cmark & \\cmark & \\cmark \\\\")
    lines.append("Birth-cohort FE & \\cmark & \\cmark & \\cmark & \\cmark & \\cmark & \\cmark & \\cmark & \\cmark & \\cmark \\\\")
    lines.append(f"Wave & \\multicolumn{{9}}{{c}}{{{wave}}} \\\\")
    lines.append(f"Treatment start & \\multicolumn{{9}}{{c}}{{{cutoff}}} \\\\")
    lines.append(f"Sample cells & \\multicolumn{{9}}{{c}}{{{n_cells:,}}} \\\\")
    lines.append(f"Counties & \\multicolumn{{9}}{{c}}{{{n_counties:,}}} \\\\")
    lines.append("\\bottomrule")
    lines.append("\\end{tabular}")
    return "\n".join(lines)


def build_rtf(df, wave, cutoff):
    rows = []
    rows.append(r"{\rtf1\ansi")
    rows.append(rf"\b Formal heterogeneity, wave {wave}, cutoff {cutoff}\b0\par")
    for _, row in df.iterrows():
        rows.append(
            f"{row['panel']} | {row['subgroup']} | {row['b']:.4f} | {row['se']:.4f} | {row['p']:.4g}\\par"
        )
    rows.append("}")
    return "\n".join(rows)


def build_figure(df, wave, cutoff):
    plot_df = df[df["subgroup"].isin(["female", "male", "urban", "rural", "B1", "B2", "B3", "base0", "base1"])].copy()
    plot_df["label"] = plot_df["panel"] + ":" + plot_df["subgroup"]
    plot_df = plot_df.reset_index(drop=True)
    fig, ax = plt.subplots(figsize=(8.3, 6.2))
    y = range(len(plot_df))
    ax.errorbar(plot_df["b"], y, xerr=1.96 * plot_df["se"], fmt="o", color="#9a3412", ecolor="#c2410c", capsize=3)
    ax.axvline(0, color="black", lw=0.8)
    ax.set_yticks(list(y))
    ax.set_yticklabels(plot_df["label"])
    ax.set_xlabel("Coefficient on Post-war cohort × War exposure")
    ax.set_title(f"Heterogeneity, wave {wave}, cutoff {cutoff}")
    fig.tight_layout()
    out = PAPER_FIG / f"fig_heterogeneity_{wave}_cutoff{cutoff}.png"
    fig.savefig(out, dpi=220)
    plt.close(fig)


for cutoff in [1940, 1946]:
    for wave in [1982, 1990, 2000]:
        csv_path = RESULT / f"heterogeneity_{wave}_cutoff{cutoff}_formal_v1.csv"
        if not csv_path.exists():
            continue
        df = pd.read_csv(csv_path)
        tex = build_table(df, wave, cutoff)
        (RESULT / f"heterogeneity_{wave}_cutoff{cutoff}_formal_v1.tex").write_text(tex)
        (RESULT / f"heterogeneity_{wave}_cutoff{cutoff}_formal_v1.rtf").write_text(build_rtf(df, wave, cutoff))
        (PAPER_TABLE / f"heterogeneity_{wave}_cutoff{cutoff}_formal_v1.tex").write_text(tex)
        build_figure(df, wave, cutoff)

