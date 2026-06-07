from pathlib import Path
import pandas as pd

ROOT = Path('/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war')
df = pd.read_csv(ROOT / 'result/table/xspec_fullpack_reghdfejl_summary_v1.csv')
df = df[df['module'] == 'main'].copy()
df = df[df['spec'].isin(['baseline', 'full_ctrl'])].copy()
order = ['ln_per100k','ihs_per100k','ln_raw','raw_count','share_winsor','ihs_share']
labels = {
    'ln_per100k':'Log martyr rate per 100k',
    'ihs_per100k':'IHS martyr rate per 100k',
    'ln_raw':'Log raw martyr count',
    'raw_count':'Raw martyr count',
    'share_winsor':'Winsorized martyr share',
    'ihs_share':'IHS martyr share',
}
blocks = []
for wave in [1982,1990,2000]:
    sub = df[df['wave'] == wave].copy()
    sub['xspec'] = pd.Categorical(sub['xspec'], categories=order, ordered=True)
    sub = sub.sort_values(['xspec','spec'])
    blocks.append((wave, sub))

tex = []
tex.append('{')
tex.append(r'\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}')
tex.append(r'\begin{tabular}{l*{2}{c}}')
tex.append(r'\toprule')
for i,(wave,sub) in enumerate(blocks):
    tex.append(rf'\multicolumn{{3}}{{l}}{{\textbf{{Panel {chr(65+i)}: Census {wave}}}}}\\')
    tex.append(r'& \multicolumn{1}{c}{(1) Baseline} & \multicolumn{1}{c}{(2) + Full historical controls}\\')
    tex.append(r'\cmidrule(lr){2-2}\cmidrule(lr){3-3}')
    tex.append(r'\midrule')
    for x in order:
        row = sub[sub['xspec'] == x].set_index('spec')
        b = row.loc['baseline','b'] if 'baseline' in row.index else float('nan')
        se = row.loc['baseline','se'] if 'baseline' in row.index else float('nan')
        b2 = row.loc['full_ctrl','b'] if 'full_ctrl' in row.index else float('nan')
        se2 = row.loc['full_ctrl','se'] if 'full_ctrl' in row.index else float('nan')
        p = row.loc['baseline','p'] if 'baseline' in row.index else float('nan')
        p2 = row.loc['full_ctrl','p'] if 'full_ctrl' in row.index else float('nan')
        star1 = '***' if p < 0.01 else ('**' if p < 0.05 else ('*' if p < 0.1 else ''))
        star2 = '***' if p2 < 0.01 else ('**' if p2 < 0.05 else ('*' if p2 < 0.1 else ''))
        tex.append(f"{labels[x]} & {b:.4f}{star1} & {b2:.4f}{star2}\\\\")
        tex.append(f" & ({se:.4f}) & ({se2:.4f})\\\\")
    if i < len(blocks)-1:
        tex.append(r'\midrule')
tex.append(r'\bottomrule')
tex.append(r'\end{tabular}')
tex.append('}')
out = ROOT / 'paper/assets/tables/xspec_main_summary_v1.tex'
out.write_text('\n'.join(tex))
print(out)
