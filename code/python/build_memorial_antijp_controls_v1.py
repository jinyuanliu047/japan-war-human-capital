#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import math
import re
from pathlib import Path

import numpy as np
import pandas as pd

MOD_PATH = Path('code/python/build_county_extended_controls_v1.py').resolve()
spec = importlib.util.spec_from_file_location('extctrl', MOD_PATH)
mod = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(mod)

PROJ = Path(mod.PROJ)

KW = [
    '抗日','抗战','侵华日军','日寇','日军','日本侵略','十四年抗战',
    '八路军','新四军','东北抗联','百团大战','淞沪','卢沟桥','台儿庄','南京保卫战','七七事变'
]
KW_RE = re.compile('|'.join(map(re.escape, KW)))
YR_RE = re.compile(r'(19[3-4][0-9])')


def normalize_build_year(x: object) -> float:
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return np.nan
    s = str(x)
    m = re.search(r'(19\d{2}|20\d{2})', s)
    if m:
        return float(m.group(1))
    return np.nan


def text_has_antijp(row: pd.Series) -> bool:
    txt = str(row.get('mmdwName','')) + ' ' + str(row.get('mmdwUnitDesc','')) + ' ' + str(row.get('mmdwAddress',''))
    return KW_RE.search(txt) is not None


def text_has_war_year(row: pd.Series) -> bool:
    txt = str(row.get('mmdwName','')) + ' ' + str(row.get('mmdwUnitDesc',''))
    yrs = [int(x) for x in YR_RE.findall(txt)]
    if not yrs:
        return False
    return any(1931 <= y <= 1945 for y in yrs)


def main() -> None:
    county = mod.build_county_dict()

    raw = mod.fetch_memorial_rows()
    # refetch with full fields by direct API pages
    # fetch_memorial_rows may already include extra columns from API before subsetting in old script
    # here we keep all available fields from newly fetched payload
    import requests
    first = requests.post(mod.MEMORIAL_API, headers=mod.HEADERS, data={'pageNum':1,'pageSize':100}, timeout=30).json()
    rows = list(first.get('rows',[]))
    total = int(first.get('total',0))
    pages = max(1, math.ceil(total/100))
    for p in range(2,pages+1):
        j = requests.post(mod.MEMORIAL_API, headers=mod.HEADERS, data={'pageNum':p,'pageSize':100}, timeout=30).json()
        rows.extend(j.get('rows',[]))
    full = pd.DataFrame(rows)
    if full.empty:
        raise SystemExit('No memorial rows fetched')

    full['mmdwUnitDesc'] = full.get('mmdwUnitDesc','')
    full['mmdwBuildDate'] = full.get('mmdwBuildDate','')
    full['antijp_kw'] = full.apply(text_has_antijp, axis=1).astype(int)
    full['antijp_year_text'] = full.apply(text_has_war_year, axis=1).astype(int)
    full['build_year'] = full['mmdwBuildDate'].map(normalize_build_year)
    full['antijp_flag'] = ((full['antijp_kw']==1) | (full['antijp_year_text']==1)).astype(int)

    keep_cols = [
        'mmdwGuid','mmdwName','mmdwLevelId','mmdwLevel','mmdwShengId','mmdwSheng','mmdwShiId','mmdwShi',
        'mmdwXianId','mmdwXian','mmdwAddress','mmdwUnitDesc','mmdwBuildDate','build_year',
        'antijp_kw','antijp_year_text','antijp_flag'
    ]
    for c in keep_cols:
        if c not in full.columns:
            full[c] = ''
    full = full[keep_cols].copy()

    anti = full[full['antijp_flag']==1].copy()

    mapped_all, county_all = mod.resolve_memorial_counties(full, county)
    mapped_anti, county_anti = mod.resolve_memorial_counties(anti, county)

    county_anti = county_anti.rename(columns={
        'memorial_cnt_total':'memorial_antijp_cnt_total',
        'memorial_cnt_national':'memorial_antijp_cnt_national',
        'memorial_cnt_prov':'memorial_antijp_cnt_prov',
        'memorial_cnt_city':'memorial_antijp_cnt_city',
        'memorial_cnt_county':'memorial_antijp_cnt_county',
        'memorial_cnt_undetermined':'memorial_antijp_cnt_undetermined',
    })

    base_ctrl = pd.read_csv(PROJ/'data/temp/county_controls_full_v1.csv', dtype={'countyid_curr6':str})
    out = base_ctrl.merge(county_anti, on='countyid_curr6', how='left')
    for c in [x for x in out.columns if x.startswith('memorial_antijp_cnt_')]:
        out[c] = out[c].fillna(0.0)
    out['ln_memorial_antijp_cnt'] = np.log1p(out['memorial_antijp_cnt_total'])

    (PROJ/'data/scrape/chinamartyrs_outputs').mkdir(parents=True, exist_ok=True)
    full.to_csv(PROJ/'data/scrape/chinamartyrs_outputs/memorial_facilities_full_with_desc_v2.csv', index=False, encoding='utf-8-sig')
    anti.to_csv(PROJ/'data/scrape/chinamartyrs_outputs/memorial_facilities_antijp_full_v1.csv', index=False, encoding='utf-8-sig')
    mapped_anti.to_csv(PROJ/'data/scrape/chinamartyrs_outputs/memorial_facilities_antijp_county_level_v1.csv', index=False, encoding='utf-8-sig')
    county_anti.to_csv(PROJ/'data/scrape/chinamartyrs_outputs/memorial_facilities_antijp_county_counts_v1.csv', index=False, encoding='utf-8-sig')

    out.to_csv(PROJ/'data/temp/county_controls_full_antijp_v1.csv', index=False, encoding='utf-8-sig')
    out.to_stata(PROJ/'data/temp/county_controls_full_antijp_v1.dta', write_index=False, version=118)

    print('memorial total',len(full),'antijp',len(anti))
    print('counties with antijp memorial', int((out['memorial_antijp_cnt_total']>0).sum()))


if __name__ == '__main__':
    main()
