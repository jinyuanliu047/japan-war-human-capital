from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path('/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war')
TABLE = ROOT / 'result' / 'table'
FIG = ROOT / 'paper' / 'assets' / 'figures'
FIG.mkdir(parents=True, exist_ok=True)

plt.rcParams.update({
    'font.family': 'serif',
    'font.serif': ['Libertinus Serif', 'Times New Roman', 'DejaVu Serif'],
    'axes.titlesize': 11,
    'axes.labelsize': 10,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
})
COLORS = {'baseline':'#234d6d','all_five':'#c4602f'}
LABELS = {'baseline':'Baseline','all_five':'+ All five history controls','minority':'Baseline','minority_AER':'+ All five history controls'}


def stars(p):
    return '***' if p < 0.01 else '**' if p < 0.05 else '*' if p < 0.1 else ''


def coeff_plot(df, xcol, groupcol, outfile, title, xlabel='Coefficient on Post × War exposure'):
    fig, ax = plt.subplots(figsize=(8.27, 5.2))
    waves = list(dict.fromkeys(df[xcol].tolist()))
    groups = list(dict.fromkeys(df[groupcol].tolist()))
    base = np.arange(len(waves))
    offsets = np.linspace(-0.18, 0.18, len(groups)) if len(groups) > 1 else [0]
    for off, g in zip(offsets, groups):
        sub = df[df[groupcol] == g].copy()
        sub = sub.set_index(xcol).loc[waves].reset_index()
        y = sub['b'].to_numpy()
        se = sub['se'].to_numpy()
        ax.errorbar(base + off, y, yerr=1.96*se, fmt='o-', capsize=3, lw=1.8,
                    color=COLORS.get(g, None), label=LABELS.get(g, g))
        for xb, yb, p in zip(base + off, y, sub['p']):
            ax.text(xb, yb + np.sign(yb if yb != 0 else 1)*max(se)*0.8 + 0.002, stars(p), ha='center', va='bottom', fontsize=8)
    ax.axhline(0, color='black', lw=0.8, alpha=0.7)
    ax.set_xticks(base)
    ax.set_xticklabels([str(w) for w in waves])
    ax.set_xlabel('Census wave')
    ax.set_ylabel(xlabel)
    ax.set_title(title)
    ax.legend(frameon=False, ncol=min(2, len(groups)), loc='best')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    fig.savefig(outfile, dpi=300, bbox_inches='tight')
    plt.close(fig)


def grad_plot(df, outfile, title):
    fig, ax = plt.subplots(figsize=(8.27, 5.2))
    outcomes = ['primary', 'junior', 'college']
    labels = ['Primary', 'Junior', 'College']
    specs = ['baseline', 'all_five']
    base = np.arange(len(outcomes))
    offs = [-0.12, 0.12]
    for off, spec in zip(offs, specs):
        sub = df[df['spec'] == spec].copy().set_index('outcome').loc[outcomes].reset_index()
        y = sub['b'].to_numpy()
        se = sub['se'].to_numpy()
        ax.errorbar(base + off, y, yerr=1.96*se, fmt='o-', capsize=3, lw=1.8,
                    color=COLORS[spec], label=LABELS[spec])
        for xb, yb, p in zip(base + off, y, sub['p']):
            ax.text(xb, yb + np.sign(yb if yb != 0 else 1)*max(se)*0.8 + 0.0004, stars(p), ha='center', va='bottom', fontsize=8)
    ax.axhline(0, color='black', lw=0.8, alpha=0.7)
    ax.set_xticks(base)
    ax.set_xticklabels(labels)
    ax.set_ylabel('Coefficient on Post × War exposure')
    ax.set_title(title)
    ax.legend(frameon=False, loc='best')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    fig.savefig(outfile, dpi=300, bbox_inches='tight')
    plt.close(fig)

# Main eduy figures
for cutoff, fn in [('1940', 'main_micro_eduy_cutoff1940_microequiv_v1.csv'), ('1946', 'main_micro_eduy_cutoff1946_mainstyle_v1.csv')]:
    df = pd.read_csv(TABLE / fn)
    spec_col = 'spec'
    keep = ['baseline', 'all_five'] if 'all_five' in set(df[spec_col]) else ['minority', 'minority_AER']
    df = df[df[spec_col].isin(keep)].copy()
    df[spec_col] = df[spec_col].replace({'minority':'baseline','minority_AER':'all_five'})
    coeff_plot(df, 'wave', spec_col, FIG / f'fig_main_eduy_cutoff{cutoff}.png', f'Years of education: census-wave estimates (cutoff {cutoff})')

# Mean figures
for cutoff in ['1940', '1946']:
    df = pd.read_csv(TABLE / f'main_eduy_mean_cutoff{cutoff}_mainstyle_v1.csv')
    coeff_plot(df, 'wave', 'spec', FIG / f'fig_main_eduy_mean_cutoff{cutoff}.png', f'County-cohort mean years of education (cutoff {cutoff})')

# Graduation figures
for cutoff, suffix in [('1940', 'microequiv_v1'), ('1946', 'v1')]:
    for wave in [1982, 1990, 2000]:
        fn = TABLE / f'graduation_rates_{wave}_cutoff{cutoff}_{suffix}.csv'
        if not fn.exists():
            continue
        df = pd.read_csv(fn)
        if 'wave' in df.columns:
            df = df[df['wave'] == wave].copy()
        grad_plot(df, FIG / f'fig_grad_{wave}_cutoff{cutoff}.png', f'Educational completion rates in {wave} (cutoff {cutoff})')

print('built core figures')
