#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
import pandas as pd

BASE = Path('/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war')
TABLE = BASE / 'result' / 'table' / 'xy_education_sweep_reghdfejl_summary_v3.csv'
FIG = BASE / 'result' / 'figure'

X_ORDER = ['ln_per100k', 'ihs_per100k', 'ln_raw', 'raw_count', 'share_winsor', 'ihs_share']
X_LABEL = {
    'ln_per100k': 'Log martyrs per 100k',
    'ihs_per100k': 'IHS martyrs per 100k',
    'ln_raw': 'Log raw martyr count',
    'raw_count': 'Raw martyr count',
    'share_winsor': 'Winsorized share',
    'ihs_share': 'IHS share',
}
Y_ORDER = ['eduy_mean', 'pri_comp', 'mid_comp']
Y_LABEL = {'eduy_mean': 'Years of education', 'pri_comp': 'Primary completion', 'mid_comp': 'Middle-school completion'}
WAVE_ORDER = ['1982', '1990', '2000']
COLORS = {'1982': '#1F4E79', '1990': '#B45F06', '2000': '#2E6B4A'}


def style() -> None:
    plt.rcParams.update({
        'figure.facecolor': 'white',
        'axes.facecolor': 'white',
        'axes.grid': True,
        'grid.color': '#DDDDDD',
        'grid.linewidth': 0.6,
        'grid.alpha': 0.6,
        'axes.spines.top': False,
        'axes.spines.right': False,
        'font.family': 'serif',
        'font.serif': ['Times New Roman', 'Songti SC', 'Noto Serif CJK SC', 'DejaVu Serif'],
        'font.size': 11,
        'axes.unicode_minus': False,
    })


def main() -> None:
    style()
    FIG.mkdir(parents=True, exist_ok=True)
    df = pd.read_csv(TABLE, dtype={'wave': str})

    coeff = df[(df['yvar'] == 'eduy_mean') & (df['status'] == 'ok')].copy()
    coeff['xspec'] = pd.Categorical(coeff['xspec'], categories=X_ORDER, ordered=True)
    coeff['spec'] = pd.Categorical(coeff['spec'], categories=['wt_base', 'wt_fullctrl'], ordered=True)
    coeff = coeff.sort_values(['spec', 'xspec', 'wave'])
    coeff['lb'] = coeff['b'] - 1.96 * coeff['se']
    coeff['ub'] = coeff['b'] + 1.96 * coeff['se']

    fig, axes = plt.subplots(1, 2, figsize=(15.6, 8.2), gridspec_kw={'width_ratios': [1.55, 1.0]})

    ax = axes[0]
    base_y = np.arange(len(X_ORDER))[::-1]
    offsets = {'1982': -0.22, '1990': 0.0, '2000': 0.22}

    for spec_i, spec in enumerate(['wt_base', 'wt_fullctrl']):
        xshift = spec_i * 0.5
        for wave in WAVE_ORDER:
            sub = coeff[(coeff['spec'] == spec) & (coeff['wave'] == wave)].copy()
            sub = sub.set_index('xspec').reindex(X_ORDER).reset_index()
            ys = base_y + offsets[wave] - xshift * 7.5
            ax.errorbar(
                sub['b'],
                ys,
                xerr=1.96 * sub['se'],
                fmt='o',
                color=COLORS[wave],
                ecolor=COLORS[wave],
                elinewidth=1.1,
                capsize=2.4,
                markersize=4.8,
                alpha=0.98 if spec == 'wt_fullctrl' else 0.52,
                label=f'{wave}, {"full controls" if spec == "wt_fullctrl" else "baseline"}' if spec_i == 0 else None,
                zorder=3 if spec == 'wt_fullctrl' else 2,
            )

    ax.axvline(0, color='#555555', linestyle=(0, (4, 3)), linewidth=1.0)
    ax.set_yticks(base_y - 1.8)
    ax.set_yticklabels([X_LABEL[x] for x in X_ORDER])
    ax.set_xlabel('Coefficient on post × treatment')
    ax.set_title('A. Education outcome with alternative treatment measures', loc='left', fontweight='bold')
    ax.text(0.0, 1.01, 'Transparent markers = baseline; solid markers = full-control specification.', transform=ax.transAxes, ha='left', va='bottom', fontsize=9.4, color='#555555')
    handles = [
        plt.Line2D([0], [0], color=COLORS[w], marker='o', linestyle='None', markersize=5, label=w)
        for w in WAVE_ORDER
    ]
    ax.legend(handles=handles, title='Census wave', frameon=False, loc='lower right')

    ax2 = axes[1]
    status = df.copy()
    status['xspec'] = pd.Categorical(status['xspec'], categories=X_ORDER, ordered=True)
    status['yvar'] = pd.Categorical(status['yvar'], categories=Y_ORDER, ordered=True)
    status['status_num'] = status['status'].map({'ok': 1, 'postonly_unavailable': 0})
    mat = status.groupby(['yvar', 'xspec'])['status_num'].max().unstack().reindex(index=Y_ORDER, columns=X_ORDER)
    arr = mat.to_numpy(dtype=float)
    cmap = plt.matplotlib.colors.ListedColormap(['#F3E8D9', '#6E9F72'])
    ax2.imshow(arr, cmap=cmap, aspect='auto', vmin=0, vmax=1)
    ax2.set_xticks(np.arange(len(X_ORDER)))
    ax2.set_xticklabels([X_LABEL[x].replace(' martyrs', '\nmartyrs').replace(' count', '\ncount') for x in X_ORDER], rotation=0, fontsize=9)
    ax2.set_yticks(np.arange(len(Y_ORDER)))
    ax2.set_yticklabels([Y_LABEL[y] for y in Y_ORDER])
    ax2.set_title('B. Availability of DID-ready Y × X combinations', loc='left', fontweight='bold')
    ax2.grid(False)
    for i in range(len(Y_ORDER)):
        for j in range(len(X_ORDER)):
            txt = 'OK' if arr[i, j] == 1 else 'N/A'
            ax2.text(j, i, txt, ha='center', va='center', fontsize=9.5, color='#1F1F1F')
    patches = [
        mpatches.Patch(color='#6E9F72', label='DID-ready'),
        mpatches.Patch(color='#F3E8D9', label='Post-only, not used in DID'),
    ]
    ax2.legend(handles=patches, frameon=False, loc='lower left', bbox_to_anchor=(0.0, -0.18), ncol=1)

    fig.suptitle('Treatment and outcome sweep for the education block', x=0.01, ha='left', fontsize=15, fontweight='bold')
    fig.text(0.01, 0.01, 'The current harmonized DID panel supports the full treatment sweep for years of education. Completion outcomes are available only for post-war cohorts and therefore are not used in the DID specifications.', fontsize=9.7, color='#4D4D4D')
    fig.tight_layout(rect=[0, 0.05, 1, 0.95])

    out = FIG / 'xy_education_sweep_v1.png'
    fig.savefig(out, dpi=320)
    fig.savefig(out.with_suffix('.pdf'))
    print(out)


if __name__ == '__main__':
    main()
