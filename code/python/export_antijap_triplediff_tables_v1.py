from pathlib import Path

import pandas as pd


PROJ = Path(
    "/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/"
    "My Drive/Projects/ongoing/japan_war"
)

src = PROJ / "result/table/main_antijap_base_link_triplediff_reghdfejl_summary_v1.csv"
rtf_out = PROJ / "result/table/main_antijap_base_link_triplediff_reghdfejl_v1.rtf"
tex_out = PROJ / "result/table/main_antijap_base_link_triplediff_reghdfejl_v1.tex"

df = pd.read_csv(src)
fmt = df.copy()
for col in ["b_base", "se_base", "p_base", "b_diff", "se_diff", "p_diff"]:
    fmt[col] = fmt[col].map(lambda x: f"{x:.6f}")

tex_out.write_text(fmt.to_latex(index=False, escape=True), encoding="utf-8")

rows = []
for _, r in fmt.iterrows():
    rows.append(
        r"\trowd\cellx1200\cellx2800\cellx4400\cellx6000\cellx7600\cellx9200\cellx10800"
        f"\n\\intbl {r['wave']}\\cell {r['b_base']}\\cell {r['se_base']}\\cell {r['p_base']}\\cell {r['b_diff']}\\cell {r['se_diff']}\\cell {r['p_diff']}\\cell\\row\n"
    )

rtf = (
    r"{\rtf1\ansi" "\n"
    r"\b Anti-Japanese base link triple diff summary\b0\par" "\n"
    r"\trowd\cellx1200\cellx2800\cellx4400\cellx6000\cellx7600\cellx9200\cellx10800" "\n"
    r"\intbl wave\cell b_base\cell se_base\cell p_base\cell b_diff\cell se_diff\cell p_diff\cell\row" "\n"
    + "".join(rows)
    + "}"
)
rtf_out.write_text(rtf, encoding="utf-8")

print(rtf_out)
print(tex_out)
