from pathlib import Path

BASE = Path('/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war/paper/assets/tables')

HEADER_MAP = {
    'main_micro_eduy_1990_onebyone_controls_v1.tex': [
        'Baseline', '+ SDY density $\\times$ Post', '+ Famine $\\times$ Post',
        '+ Victims $\\times$ Post', '+ Grain output $\\times$ Post', '+ Urbanization $\\times$ Post'
    ],
    'main_micro_eduy_cutoff1946_mainstyle_v1.tex': [
        '1982 baseline', '1982 + all five', '1990 baseline', '1990 + all five', '2000 baseline', '2000 + all five'
    ],
    'main_cutoff_sweep_python_summary_v1.tex': ['1982', '1990', '2000'],
    'main_1982_pre_glf_sweep_python_summary_v1.tex': ['1956', '1958', '1960', '1956', '1958', '1960'],
    'heterogeneity_gender_cutoff_sweep_python_summary_v1.tex': ['Male', 'Female'],
    'heterogeneity_baseedu_cutoff_sweep_python_summary_v1.tex': ['Low base education', 'Middle base education', 'High base education'],
    'main_individual_heterogeneity_gender_reghdfejl_v4.tex': ['1982 Male', '1982 Female', '1990 Male', '1990 Female', '2000 Male', '2000 Female'],
    'main_individual_heterogeneity_urbanrural_reghdfejl_v4.tex': ['1990 Urban', '1990 Rural', '2000 Urban', '2000 Rural'],
    'main_antijap_base_broad_heterogeneity_reghdfejl_v1.tex': ['1982 Non-base', '1982 Base', '1990 Non-base', '1990 Base', '2000 Non-base', '2000 Base'],
    'main_antijap_base_link_heterogeneity_reghdfejl_v2.tex': ['1982 Non-base', '1982 Base', '1990 Non-base', '1990 Base', '2000 Non-base', '2000 Base'],
    'main_treatcount_highlow_reghdfejl_v1.tex': ['1982 Low count', '1982 High count', '1990 Low count', '1990 High count', '2000 Low count', '2000 High count'],
    'main_ihs_ppml_reghdfejl_v1.tex': [
        '1982 OLS ln(X)', '1982 OLS ihs(X)', '1982 PPML ln(X)', '1982 PPML ihs(X)',
        '1990 OLS ln(X)', '1990 OLS ihs(X)', '1990 PPML ln(X)', '1990 PPML ihs(X)',
        '2000 OLS ln(X)', '2000 OLS ihs(X)', '2000 PPML ln(X)', '2000 PPML ihs(X)'
    ],
    'main_reloc_as_control_robustness_reghdfejl_v1.tex': [
        '1982 Baseline', '1982 + Relocation$\\times$Post', '1982 + Full controls', '1982 + Both',
        '1990 Baseline', '1990 + Relocation$\\times$Post', '1990 + Full controls', '1990 + Both',
        '2000 Baseline', '2000 + Relocation$\\times$Post', '2000 + Full controls', '2000 + Both'
    ],
    'mainspec_extended_robustness_reghdfejl_v1.tex': [
        '1982 Baseline', '1982 + History', '1982 + Conflict', '1982 + Both',
        '1990 Baseline', '1990 + History', '1990 + Conflict', '1990 + Both',
        '2000 Baseline', '2000 + History', '2000 + Conflict', '2000 + Both'
    ],
    'main_clan_earthquake_robust_fast_v1.tex': [
        '1982 Baseline', '1982 + Clan', '1982 + Earthquake', '1982 + Both',
        '1990 Baseline', '1990 + Clan', '1990 + Earthquake', '1990 + Both',
        '2000 Baseline', '2000 + Clan', '2000 + Earthquake', '2000 + Both'
    ],
    'main_majorcase_split_reghdfejl_v1.tex': [
        '1982 No massacre', '1982 No massacre + controls', '1982 Massacre', '1982 Massacre + controls',
        '1990 No massacre', '1990 No massacre + controls', '1990 Massacre', '1990 Massacre + controls',
        '2000 No massacre', '2000 No massacre + controls', '2000 Massacre', '2000 Massacre + controls'
    ],
    'mechanism_census1990_ipums_employment_reghdfe_v1.tex': [
        'In labor force', 'Employed', 'Unemployed', 'Inactive', 'White-collar', 'Professional/managerial',
        'Clerical', 'Service/sales', 'Agriculture occupation', 'Craft', 'Machine operator', 'Elementary occupation'
    ],
    'mechanism_census1990_ipums_industry_reghdfe_v1.tex': [
        'Agriculture', 'Manufacturing', 'Construction', 'Trade', 'Transport', 'Finance',
        'Public administration', 'Business/real estate', 'Education', 'Health/social', 'Other services'
    ],
    'mechanism_census2000_family_reghdfejl_v1.tex': [
        'Number of children', 'Any child', 'Two-plus children', 'Household size', 'Large household'
    ],
    'mechanism_chip1995_edu_pooled_pref_reghdfe_v2.tex': ['Education total', 'Schooling fee', 'Training cost'],
    'mechanism_chip1995_edu_pooled_pref_log_reghdfe_v1.tex': ['ln(1+Education total)', 'ln(1+Schooling fee)', 'ln(1+Training cost)'],
    'mechanism_cgss_attitudes_positive_reghdfe_v1.tex': [
        'Ambition matters',
        "Parents' education matters",
        'College only for the rich',
        'Hard work matters',
        'Attachment to hometown',
        'Connections matter',
        'Religion matters'
    ],
    'main_heterogeneity_pack_reghdfejl_v1.tex': [
        '1982 T1','1982 T2','1982 T3','1982 B1','1982 B2','1982 B3','1982 M0','1982 M1','1982 D0','1982 D1',
        '1990 T1','1990 T2','1990 T3','1990 B1','1990 B2','1990 B3','1990 M0','1990 M1','1990 D0','1990 D1',
        '2000 T1','2000 T2','2000 T3','2000 B1','2000 B2','2000 B3','2000 M0','2000 M1','2000 D0','2000 D1'
    ],
    'mechanism_cgss_attitudes_all_reghdfejl_v1.tex': [f'Attitude {i}' for i in range(1,43)],
}

GLOBAL_REPL = {
    '1.post\\#c.ln\_martyr\_per100k\_1953': 'Post $\\times$ War exposure',
    '1.post\\#c.ihs\_martyr\_per100k\_1953': 'Post $\\times$ War exposure',
    'post\_ln': 'Post $\\times$ War exposure',
    'Controls': 'Individual controls',
    'County\_FE': 'County FE',
    'Cohort\_FE': 'Cohort FE',
    'Geo2\_FE': 'Prefecture FE',
    'Pref\_FE': 'Prefecture FE',
    'N\_counties': 'Counties',
    'N\_sample': 'Sample cells',
    'N\_pre': 'Pre-period cells',
    'N\_post': 'Post-period cells',
    'FullControls': 'Full controls',
    'RelocPostCtrl': 'Relocation $\\times$ Post control',
    'BaseBroad': 'Broad base indicator',
    'BaseLink': 'Strict base indicator',
    'AER\_Post': 'County history control',
    'Conflict\_Post': 'Conflict control',
    'adj. \(R\^\{2\}\)': 'Adj. $R^2$',
    '\(R\^\{2\}\)': '$R^2$',
}

Y_ROW_MAP = {
    'eduy\_mean': 'Years of education',
    'eduy': 'Years of education',
}

SUMMARY_REPL = {
    'main_longmarch_korea_robustness_reghdfejl_v1.tex': {
        'wave & spec & b & se & p': 'Census year & Specification & Coef. & S.E. & P-value'
    },
    'main_antijap_base_link_triplediff_reghdfejl_v1.tex': {
        'wave & b\_base & se\_base & p\_base & b\_diff & se\_diff & p\_diff & n': 'Census year & Base=0 coef. & Base=0 S.E. & Base=0 P-value & Triple-diff coef. & Triple-diff S.E. & Triple-diff P-value & Sample cells'
    },
}


def replace_header_lines(text: str, cols: list[str]) -> str:
    lines = text.splitlines()
    idxs = [i for i,l in enumerate(lines) if '\\multicolumn{1}{c}{(1)}' in l]
    if not idxs:
        return text
    i = idxs[0]
    second = '            &' + '&'.join([f'\\multicolumn{{1}}{{c}}{{{c}}}' for c in cols]) + r'\\'
    # keep first numbering row; replace next row if it is another multicolumn header line
    if i + 1 < len(lines) and '\\multicolumn{1}{c}' in lines[i+1]:
        lines[i+1] = second
    else:
        lines.insert(i+1, second)
    return '\n'.join(lines) + '\n'

for path in BASE.glob('*.tex'):
    text = path.read_text()
    if path.name in HEADER_MAP:
        text = replace_header_lines(text, HEADER_MAP[path.name])
    for a,b in GLOBAL_REPL.items():
        text = text.replace(a,b)
    if path.name in SUMMARY_REPL:
        for a,b in SUMMARY_REPL[path.name].items():
            text = text.replace(a,b)
    for a,b in Y_ROW_MAP.items():
        text = text.replace('}{'+a+'}', '}{'+b+'}')
    path.write_text(text)
    print(path.name)
