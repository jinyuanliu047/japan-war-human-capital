from pathlib import Path

PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
SRC = PROJ / "result" / "table"
DST = PROJ / "paper" / "assets" / "tables"
DST.mkdir(parents=True, exist_ok=True)

GLOBAL_REPL = {
    r"1.post#c.ln\_martyr\_per100k\_1953": "Post × War exposure",
    r"1.post#c.ihs\_martyr\_per100k\_1953": "Post × IHS war exposure",
    r"1.post#c.heritage\_any": "Post × Heritage indicator",
    r"1.post#c.ln\_heritage\_site\_count": "Post × Heritage-site count",
    r"1.post#c.ln\_memorial\_cnt": "Post × Memorial count",
    r"1.post#c.ln\_memorial\_antijp\_cnt": "Post × Anti-Japanese memorial count",
    r"1.post#1.heritage\_any#c.ln\_martyr\_per100k\_1953": "Post × Heritage × War exposure",
    r"1.post#c.ln\_heritage\_site\_count#c.ln\_martyr\_per100k\_1953": "Post × Heritage count × War exposure",
    r"Controls    ": "Individual controls",
    r"AER\_Post    ": "County history control",
    r"Hist\_Control": "County history control",
    r"County\_FE": "County FE",
    r"Cohort\_FE": "Cohort FE",
    r"Province\_FE": "Province FE",
    r"Cohort\_Income\_FE": "Cohort-Income FE",
    r"Weight     ": "Weights     ",
    r"All\_five": "All five",
    r"Cell size": "Cell size",
}

CUSTOM_HEADER_REPL = {
    "main_micro_eduy_cutoff1946_mainstyle_v1.tex": (
        r"&\multicolumn{1}{c}{eduy}&\multicolumn{1}{c}{eduy}&\multicolumn{1}{c}{eduy}&\multicolumn{1}{c}{eduy}&\multicolumn{1}{c}{eduy}&\multicolumn{1}{c}{eduy}\\",
        r"&\multicolumn{1}{c}{1982 baseline}&\multicolumn{1}{c}{1982 + all five}&\multicolumn{1}{c}{1990 baseline}&\multicolumn{1}{c}{1990 + all five}&\multicolumn{1}{c}{2000 baseline}&\multicolumn{1}{c}{2000 + all five}\\",
    ),
    "main_micro_eduy_1990_onebyone_controls_v1.tex": (
        r"&\multicolumn{1}{c}{eduy}&\multicolumn{1}{c}{eduy}&\multicolumn{1}{c}{eduy}&\multicolumn{1}{c}{eduy}&\multicolumn{1}{c}{eduy}&\multicolumn{1}{c}{eduy}\\",
        r"&\multicolumn{1}{c}{Baseline}&\multicolumn{1}{c}{+ SDY density × Post}&\multicolumn{1}{c}{+ Famine × Post}&\multicolumn{1}{c}{+ Victims × Post}&\multicolumn{1}{c}{+ Grain output × Post}&\multicolumn{1}{c}{+ Urbanization × Post}\\",
    ),
}


def sanitize_tex_text(name: str, text: str) -> str:
    if name in CUSTOM_HEADER_REPL:
        old, new = CUSTOM_HEADER_REPL[name]
        text = text.replace(old, new)

    out_lines = []
    for line in text.splitlines():
        if line.startswith(r"\def\sym#1"):
            out_lines.append(line)
            continue
        if line.startswith(r"\multicolumn") and "Standard errors in parentheses" in line:
            continue
        if line.startswith(r"\multicolumn") and r"\sym{*}" in line:
            continue
        for old, new in GLOBAL_REPL.items():
            line = line.replace(old, new)
        line = line.replace("#", r"\#")
        out_lines.append(line)
    return "\n".join(out_lines) + "\n"


INCLUDED = {
    "main_micro_eduy_cutoff1940_microequiv_v1.tex",
    "main_eduy_mean_cutoff1940_mainstyle_v1.tex",
    "graduation_rates_1982_cutoff1940_v2.tex",
    "graduation_rates_1990_cutoff1940_v2.tex",
    "graduation_rates_2000_cutoff1940_v2.tex",
    "main_micro_eduy_cutoff1946_mainstyle_v1.tex",
    "main_eduy_mean_cutoff1946_mainstyle_v1.tex",
    "graduation_rates_1982_cutoff1946_v2.tex",
    "graduation_rates_1990_cutoff1946_v2.tex",
    "graduation_rates_2000_cutoff1946_v2.tex",
    "mechanism_cgss_attitudes_positive_reghdfe_v1.tex",
    "mechanism_chip1995_edu_pooled_pref_log_reghdfe_v1.tex",
    "mechanism_census1990_ipums_employment_reghdfe_v1.tex",
    "mechanism_census1990_ipums_industry_reghdfe_v1.tex",
    "main_ihs_ppml_reghdfejl_v1.tex",
    "main_micro_eduy_1990_onebyone_controls_v1.tex",
    "main_longmarch_korea_robustness_reghdfejl_v1.tex",
    "main_cutoff_sweep_python_summary_v1.tex",
    "main_1982_pre_glf_sweep_python_summary_v1.tex",
    "heterogeneity_gender_cutoff_sweep_python_summary_v1.tex",
    "heterogeneity_baseedu_cutoff_sweep_python_summary_v1.tex",
    "main_individual_heterogeneity_gender_reghdfejl_v4.tex",
    "main_individual_heterogeneity_urbanrural_reghdfejl_v4.tex",
    "main_heterogeneity_pack_reghdfejl_v1.tex",
    "main_antijap_base_broad_heterogeneity_reghdfejl_v1.tex",
    "cgss_birthorder_heterogeneity_reghdfejl_v2.tex",
}

for p in SRC.iterdir():
    if not p.is_file() or p.name not in INCLUDED:
        continue
    target = DST / p.name
    if p.suffix == ".tex":
        target.write_text(sanitize_tex_text(p.name, p.read_text(errors="ignore")), encoding="utf-8")
    else:
        target.write_bytes(p.read_bytes())

print("sanitized tex and copied non-tex files to", DST)
