from pathlib import Path
import pandas as pd

PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war")
RESULT = PROJ / "result" / "table"
ASSETS = PROJ / "paper" / "assets" / "tables"


def stars(p: float) -> str:
    if p < 0.01:
        return r"\sym{***}"
    if p < 0.05:
        return r"\sym{**}"
    if p < 0.1:
        return r"\sym{*}"
    return ""


def coef_str(b: float, p: float) -> str:
    return f"{b:.4f}{stars(p)}"


def se_str(se: float) -> str:
    return f"({se:.4f})"


def write_tex(path: Path, body: str, ncols: int) -> None:
    tex = "{\n"
    tex += r"\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" + "\n"
    tex += rf"\begin{{tabular}}{{l*{{{ncols}}}{{c}}}}" + "\n"
    tex += r"\hline\hline" + "\n"
    tex += body
    tex += r"\hline\hline" + "\n"
    tex += rf"\multicolumn{{{ncols+1}}}{{l}}{{\footnotesize Standard errors in parentheses}}" + "\\\\\n"
    tex += rf"\multicolumn{{{ncols+1}}}{{l}}{{\footnotesize \sym{{*}} \(p<0.1\), \sym{{**}} \(p<0.05\), \sym{{***}} \(p<0.01\)}}" + "\\\\\n"
    tex += r"\end{tabular}" + "\n}"
    path.write_text(tex)


def build_main_cutoff() -> None:
    df = pd.read_csv(RESULT / 'main_cutoff_sweep_python_summary_v1.csv')
    cutoffs = [1940, 1946, 1947, 1950, 1956, 1958]
    waves = [1982, 1990, 2000]
    lines = []
    header0 = "            &" + "&".join([rf"\multicolumn{{1}}{{c}}{{({i})}}" for i in range(1, len(waves)+1)]) + r"\\" + "\n"
    header1 = "            &" + "&".join([rf"\multicolumn{{1}}{{c}}{{{w}}}" for w in waves]) + r"\\" + "\n"
    lines.extend([header0, header1])
    lines.append(r"\hline" + "\n")
    for c in cutoffs:
        row = [str(c)]
        se = [""]
        for w in waves:
            x = df[(df.wave == w) & (df.cutoff == c)].iloc[0]
            row.append(coef_str(x.b, x.p))
            se.append(se_str(x.se))
        lines.append("            &".join(row) + r"\\" + "\n")
        lines.append("            &".join(se) + r"\\" + "\n")
    write_tex(ASSETS / 'main_cutoff_sweep_python_summary_v1.tex', ''.join(lines), 3)


def build_preglf() -> None:
    df = pd.read_csv(RESULT / 'main_1982_pre_glf_sweep_python_summary_v1.csv')
    his = [1956, 1958, 1960]
    cutoffs = [1940, 1946]
    lines = []
    header0 = "            &" + "&".join([rf"\multicolumn{{1}}{{c}}{{({i})}}" for i in range(1, 7)]) + r"\\" + "\n"
    header1 = "            &" + "&".join([rf"\multicolumn{{3}}{{c}}{{Cutoff {c}}}" for c in cutoffs]) + r"\\" + "\n"
    header2 = "            &" + "&".join([str(h) for c in cutoffs for h in his]) + r"\\" + "\n"
    lines.extend([header0, header1, header2, r"\hline" + "\n"])
    row = ["Coef."]
    se = [""]
    for c in cutoffs:
        for hi in his:
            x = df[(df.cutoff == c) & (df.sample_hi == hi)].iloc[0]
            row.append(coef_str(x.b, x.p))
            se.append(se_str(x.se))
    lines.append("            &".join(row) + r"\\" + "\n")
    lines.append("            &".join(se) + r"\\" + "\n")
    write_tex(ASSETS / 'main_1982_pre_glf_sweep_python_summary_v1.tex', ''.join(lines), 6)


def build_gender() -> None:
    df = pd.read_csv(RESULT / 'heterogeneity_gender_cutoff_sweep_python_summary_v1.csv')
    cutoffs = [1940, 1946, 1947, 1950, 1956]
    groups = ['male', 'female']
    lines = []
    header0 = "            &" + "&".join([rf"\multicolumn{{1}}{{c}}{{({i})}}" for i in range(1, len(groups)+1)]) + r"\\" + "\n"
    header1 = "            &" + "&".join([rf"\multicolumn{{1}}{{c}}{{{g.capitalize()}}}" for g in groups]) + r"\\" + "\n"
    lines.extend([header0, header1, r"\hline" + "\n"])
    for c in cutoffs:
        row = [str(c)]
        se = [""]
        for g in groups:
            x = df[(df.cutoff == c) & (df.subgroup == g)].iloc[0]
            row.append(coef_str(x.b, x.p))
            se.append(se_str(x.se))
        lines.append("            &".join(row) + r"\\" + "\n")
        lines.append("            &".join(se) + r"\\" + "\n")
    write_tex(ASSETS / 'heterogeneity_gender_cutoff_sweep_python_summary_v1.tex', ''.join(lines), 2)


def build_baseedu() -> None:
    df = pd.read_csv(RESULT / 'heterogeneity_baseedu_cutoff_sweep_python_summary_v1.csv')
    cutoffs = [1940, 1946, 1947, 1950, 1956]
    groups = ['B1', 'B2', 'B3']
    lines = []
    header0 = "            &" + "&".join([rf"\multicolumn{{1}}{{c}}{{({i})}}" for i in range(1, len(groups)+1)]) + r"\\" + "\n"
    header1 = "            &" + "&".join([rf"\multicolumn{{1}}{{c}}{{{g}}}" for g in groups]) + r"\\" + "\n"
    lines.extend([header0, header1, r"\hline" + "\n"])
    for c in cutoffs:
        row = [str(c)]
        se = [""]
        for g in groups:
            x = df[(df.cutoff == c) & (df.group == g)].iloc[0]
            row.append(coef_str(x.b, x.p))
            se.append(se_str(x.se))
        lines.append("            &".join(row) + r"\\" + "\n")
        lines.append("            &".join(se) + r"\\" + "\n")
    write_tex(ASSETS / 'heterogeneity_baseedu_cutoff_sweep_python_summary_v1.tex', ''.join(lines), 3)


def main() -> None:
    build_main_cutoff()
    build_preglf()
    build_gender()
    build_baseedu()


if __name__ == '__main__':
    main()
