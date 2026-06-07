from pathlib import Path

import pandas as pd


PROJ = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/"
    "My Drive/Projects/ongoing/japan_war"
)

src = PROJ / "result/table/main_longmarch_korea_robustness_reghdfejl_summary_v1.csv"
rtf_out = PROJ / "result/table/main_longmarch_korea_robustness_reghdfejl_v1.rtf"
tex_out = PROJ / "result/table/main_longmarch_korea_robustness_reghdfejl_v1.tex"

df = pd.read_csv(src)

fmt = df.copy()
for col in ["b", "se", "p"]:
    fmt[col] = fmt[col].map(lambda x: f"{x:.6f}")

latex = fmt.to_latex(index=False, escape=True)
tex_out.write_text(latex, encoding="utf-8")

rows = []
for _, r in fmt.iterrows():
    rows.append(
        r"\trowd\cellx1800\cellx3600\cellx5600\cellx7600\cellx9400"
        f"\n\\intbl {r['wave']}\\cell {r['spec']}\\cell {r['b']}\\cell {r['se']}\\cell {r['p']}\\cell\\row\n"
    )

rtf = (
    r"{\rtf1\ansi" "\n"
    r"\b Longmarch/Korea robustness summary\b0\par" "\n"
    r"\trowd\cellx1800\cellx3600\cellx5600\cellx7600\cellx9400" "\n"
    r"\intbl wave\cell spec\cell b\cell se\cell p\cell\row" "\n"
    + "".join(rows)
    + "}"
)
rtf_out.write_text(rtf, encoding="utf-8")

print(src)
print(rtf_out)
print(tex_out)
