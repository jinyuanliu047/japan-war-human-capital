from pathlib import Path

import pandas as pd

PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
RESULT = PROJ / "result/table"

src = RESULT / "mechanism_cgss_attitudes_all_reghdfejl_summary_v1.csv"
out_csv = RESULT / "mechanism_cgss_foreign_attitudes_reghdfe_summary_v1.csv"
out_tex = RESULT / "mechanism_cgss_foreign_attitudes_reghdfe_v1.tex"
out_rtf = RESULT / "mechanism_cgss_foreign_attitudes_reghdfe_v1.rtf"

keep_order = [
    ("japan_anime_freq", "Watch Japanese anime"),
    ("import_protect", "Support import limits"),
    ("nat_interest", "National interest first"),
    ("culture_protect", "Foreign culture harmful"),
    ("country_affect", "Affect to country"),
    ("eastasia_affect", "Affect to East Asia"),
    ("chinese_movie_freq", "Watch Chinese movies"),
    ("korean_drama_freq", "Watch Korean TV"),
]

df = pd.read_csv(src)
order_map = {k: i for i, (k, _v) in enumerate(keep_order)}
label_map = dict(keep_order)
df = df[df["outcome"].isin(order_map)].copy()
df["order"] = df["outcome"].map(order_map)
df["outcome_label"] = df["outcome"].map(label_map)
df = df.sort_values("order")[["outcome", "outcome_label", "b", "se", "p", "n", "n_pre", "n_post"]]
df.to_csv(out_csv, index=False)


def stars(p: float) -> str:
    if p <= 0.01:
        return "***"
    if p <= 0.05:
        return "**"
    if p <= 0.1:
        return "*"
    return ""


def fmt(x: float, digits: int = 3) -> str:
    return f"{x:.{digits}f}"


lines = []
for row in df.itertuples(index=False):
    lines.append((row.outcome_label, f"{fmt(row.b)}{stars(row.p)}", f"({fmt(row.se)})", int(row.n)))

tex = [
    "\\begin{table}[htbp]",
    "    \\centering",
    "    \\caption{CGSS Foreign-Attitude Mechanism}",
    "    \\label{tab:cgss_foreign_attitudes}",
    "    \\begin{threeparttable}",
    "    \\scriptsize",
    "    \\setlength{\\tabcolsep}{4pt}",
    "    \\renewcommand{\\arraystretch}{0.85}",
    "    \\begin{tabular}{lccc}",
    "        \\toprule",
    "        Outcome & Coefficient & S.E. & Obs. \\\\",
    "        \\midrule",
]
for label, b, se, n in lines:
    safe = label.replace("&", "\\&")
    tex.append(f"        {safe} & {b} & {se} & {n:,} \\\\")
tex += [
    "        \\bottomrule",
    "    \\end{tabular}",
    "    \\begin{tablenotes}",
    "        \\footnotesize",
    "        \\item \\textit{Notes:} Each row reports a separate regression of one foreign-attitude outcome on \\textit{Post-war cohort} $\\times$ war exposure using CGSS 2008. Controls include female, minority, urban hukou, and local hukou. County and birth-cohort fixed effects are included. Standard errors are clustered at the county level. $^{*}$, $^{**}$, and $^{***}$ denote significance at the 10\\%, 5\\%, and 1\\% levels, respectively.",
    "    \\end{tablenotes}",
    "    \\end{threeparttable}",
    "\\end{table}",
]
out_tex.write_text("\n".join(tex) + "\n", encoding="utf-8")

rtf = [
    "{\\rtf1\\ansi\\deff0",
    "{\\fonttbl{\\f0 Libertinus Serif;}}",
    "\\f0\\fs18",
    "\\b Table: CGSS Foreign-Attitude Mechanism\\b0\\par",
    "\\par",
    "Outcome\\tab Coefficient\\tab S.E.\\tab Obs.\\par",
]
for label, b, se, n in lines:
    rtf.append(f"{label}\\tab {b}\\tab {se}\\tab {n:,}\\par")
rtf += [
    "\\par Notes: Each row reports a separate regression of one foreign-attitude outcome on Post-war cohort x war exposure using CGSS 2008. Controls include female, minority, urban hukou, and local hukou. County and birth-cohort fixed effects are included. Standard errors are clustered at the county level. *, **, and *** denote significance at the 10%, 5%, and 1% levels, respectively.\\par",
    "}",
]
out_rtf.write_text("\n".join(rtf) + "\n", encoding="utf-8")

print(f"wrote {out_csv}")
print(f"wrote {out_tex}")
print(f"wrote {out_rtf}")
