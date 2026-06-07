from pathlib import Path
import pandas as pd
import pyreadstat

PROJ = Path('/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/My Drive/Projects/ongoing/japan_war')
TEMP = PROJ / 'data/temp'

CW82 = pd.read_csv(TEMP / 'countyid_1982_to_current_crosswalk_v2.csv', dtype=str)
CW82['old6'] = CW82['countyid_old6'].str.replace('.0','',regex=False).str.zfill(6)
CW82['curr6'] = CW82['countyid_curr6_final'].str.replace('.0','',regex=False).str.zfill(6)
CW82 = CW82[['old6','curr6']].dropna().drop_duplicates('old6')
MAP82 = dict(zip(CW82['old6'], CW82['curr6']))

CW00 = pd.read_csv(TEMP / 'countyid_2000_to_current_routes_v1.csv', dtype=str)
CW00['old6'] = CW00['county_old6'].str.zfill(6)
CW00['curr6'] = CW00['county_curr6'].str.zfill(6)
CW00 = CW00[['old6','curr6']].dropna().drop_duplicates('old6')
MAP00 = dict(zip(CW00['old6'], CW00['curr6']))

def append_grouped(chunks, out_csv, chunk_builder):
    acc = []
    for i, chunk in enumerate(chunks, start=1):
        df, _meta = chunk
        g = chunk_builder(df)
        if g is None or g.empty:
            continue
        acc.append(g)
        if i % 10 == 0:
            print(f'processed chunk {i}', flush=True)
    if not acc:
        raise RuntimeError(f'no data built for {out_csv}')
    out = pd.concat(acc, ignore_index=True)
    keys = ['county_curr6','birth_i','minority']
    out = out.groupby(keys, as_index=False)[['n_obs','eduy_sum','primary_sum','junior_sum','senior_sum','college_sum']].sum()
    out['eduy_mean'] = out['eduy_sum'] / out['n_obs']
    out['primary_comp'] = out['primary_sum'] / out['n_obs']
    out['junior_comp'] = out['junior_sum'] / out['n_obs']
    out['junior_high_comp'] = out['junior_comp']
    out['senior_high_comp'] = out['senior_sum'] / out['n_obs']
    out['college_comp'] = out['college_sum'] / out['n_obs']
    out = out[['county_curr6','birth_i','minority','n_obs','eduy_sum','eduy_mean','primary_comp','junior_comp','junior_high_comp','senior_high_comp','college_comp']]
    out.to_csv(out_csv, index=False)
    print(f'wrote {out_csv} rows={len(out)}', flush=True)

# 1982 from local csv if exists, else dta in chunks
src82csv = Path('/tmp/census_1982_cleaned_small.csv')
out82 = TEMP / 'micro_equiv_panel_1982_v1.csv'
if src82csv.exists():
    reader = pd.read_csv(src82csv, chunksize=300000, dtype={'countyid':'Int64','birthyr':'float','eduy':'float','ethniccn':'float'})
    def build82(df):
        df = df.dropna(subset=['countyid','birthyr','eduy']).copy()
        df['old6'] = df['countyid'].astype('Int64').astype(str).str.replace('<NA>','').str.zfill(6)
        df['county_curr6'] = df['old6'].map(MAP82)
        df = df[df['county_curr6'].notna()].copy()
        df['birth_i'] = pd.to_numeric(df['birthyr'], errors='coerce').astype('Int64')
        df['eduy'] = pd.to_numeric(df['eduy'], errors='coerce')
        df['minority'] = (pd.to_numeric(df['ethniccn'], errors='coerce') != 1).astype('Int64')
        df = df[df['birth_i'].between(1920, 1960, inclusive='both') & df['eduy'].between(0,25, inclusive='both') & (df['birth_i'] != 1939)]
        if df.empty:
            return None
        df['primary'] = (df['eduy'] >= 6).astype(int)
        df['junior'] = (df['eduy'] >= 9).astype(int)
        df['senior'] = (df['eduy'] >= 12).astype(int)
        df['college'] = (df['eduy'] >= 15).astype(int)
        g = df.groupby(['county_curr6','birth_i','minority'], as_index=False).agg(
            n_obs=('eduy','size'), eduy_sum=('eduy','sum'), primary_sum=('primary','sum'), junior_sum=('junior','sum'), senior_sum=('senior','sum'), college_sum=('college','sum')
        )
        return g
    acc=[]
    for i, df in enumerate(reader, start=1):
        g = build82(df)
        if g is not None and not g.empty:
            acc.append(g)
        if i % 5 == 0:
            print(f'1982 csv chunk {i}', flush=True)
    out = pd.concat(acc, ignore_index=True)
    out = out.groupby(['county_curr6','birth_i','minority'], as_index=False)[['n_obs','eduy_sum','primary_sum','junior_sum','senior_sum','college_sum']].sum()
    out['eduy_mean'] = out['eduy_sum'] / out['n_obs']
    out['primary_comp'] = out['primary_sum'] / out['n_obs']
    out['junior_comp'] = out['junior_sum'] / out['n_obs']
    out['junior_high_comp'] = out['junior_comp']
    out['senior_high_comp'] = out['senior_sum'] / out['n_obs']
    out['college_comp'] = out['college_sum'] / out['n_obs']
    out = out[['county_curr6','birth_i','minority','n_obs','eduy_sum','eduy_mean','primary_comp','junior_comp','junior_high_comp','senior_high_comp','college_comp']]
    out.to_csv(out82, index=False)
    print(f'wrote {out82} rows={len(out)}', flush=True)
else:
    def build82(df):
        df = df.dropna(subset=['countyid','birthyr','eduy']).copy()
        df['old6'] = pd.to_numeric(df['countyid'], errors='coerce').astype('Int64').astype(str).str.replace('<NA>','').str.zfill(6)
        df['county_curr6'] = df['old6'].map(MAP82)
        df = df[df['county_curr6'].notna()].copy()
        df['birth_i'] = pd.to_numeric(df['birthyr'], errors='coerce').astype('Int64')
        df['eduy'] = pd.to_numeric(df['eduy'], errors='coerce')
        df['minority'] = (pd.to_numeric(df['ethniccn'], errors='coerce') != 1).astype('Int64')
        df = df[df['birth_i'].between(1920, 1960, inclusive='both') & df['eduy'].between(0,25, inclusive='both') & (df['birth_i'] != 1939)]
        if df.empty:
            return None
        df['primary'] = (df['eduy'] >= 6).astype(int)
        df['junior'] = (df['eduy'] >= 9).astype(int)
        df['senior'] = (df['eduy'] >= 12).astype(int)
        df['college'] = (df['eduy'] >= 15).astype(int)
        return df.groupby(['county_curr6','birth_i','minority'], as_index=False).agg(n_obs=('eduy','size'), eduy_sum=('eduy','sum'), primary_sum=('primary','sum'), junior_sum=('junior','sum'), senior_sum=('senior','sum'), college_sum=('college','sum'))
    chunks82 = pyreadstat.read_file_in_chunks(pyreadstat.read_dta, str(TEMP / 'census_1982_cleaned.dta'), chunksize=250000, usecols=['countyid','birthyr','eduy','ethniccn'])
    append_grouped(chunks82, out82, build82)

# 1990 from local csv if exists else raw chunks
src90csv = Path('/tmp/census1990_raw_small.csv')
out90 = TEMP / 'micro_equiv_panel_1990_v1.csv'
if src90csv.exists():
    reader = pd.read_csv(src90csv, chunksize=500000, dtype={'county':'Int64','age_c':'float','age':'float','educ':'float','race':'float'})
    acc=[]
    for i, df in enumerate(reader, start=1):
        df = df.dropna(subset=['county','age_c','age','educ']).copy()
        df['county_curr6'] = df['county'].astype('Int64').astype(str).str.replace('<NA>','').str.zfill(6)
        df['birth_i'] = 1000 + pd.to_numeric(df['age_c'], errors='coerce')*100 + pd.to_numeric(df['age'], errors='coerce')
        df['eduy'] = pd.NA
        df.loc[df['educ']==1, 'eduy'] = 0
        df.loc[df['educ']==2, 'eduy'] = 6
        df.loc[df['educ']==3, 'eduy'] = 9
        df.loc[df['educ'].isin([4,5]), 'eduy'] = 12
        df.loc[df['educ']==6, 'eduy'] = 15
        df.loc[df['educ']==7, 'eduy'] = 16
        df['eduy'] = pd.to_numeric(df['eduy'], errors='coerce')
        df['minority'] = (pd.to_numeric(df['race'], errors='coerce') != 1).astype('Int64')
        df = df[df['birth_i'].between(1920, 1968, inclusive='both') & df['eduy'].between(0,25, inclusive='both') & (df['birth_i'] != 1939)]
        if not df.empty:
            df['primary'] = (df['eduy'] >= 6).astype(int)
            df['junior'] = (df['eduy'] >= 9).astype(int)
            df['senior'] = (df['eduy'] >= 12).astype(int)
            df['college'] = (df['eduy'] >= 15).astype(int)
            g = df.groupby(['county_curr6','birth_i','minority'], as_index=False).agg(n_obs=('eduy','size'), eduy_sum=('eduy','sum'), primary_sum=('primary','sum'), junior_sum=('junior','sum'), senior_sum=('senior','sum'), college_sum=('college','sum'))
            acc.append(g)
        if i % 5 == 0:
            print(f'1990 csv chunk {i}', flush=True)
    out = pd.concat(acc, ignore_index=True)
    out = out.groupby(['county_curr6','birth_i','minority'], as_index=False)[['n_obs','eduy_sum','primary_sum','junior_sum','senior_sum','college_sum']].sum()
    out['eduy_mean'] = out['eduy_sum'] / out['n_obs']
    out['primary_comp'] = out['primary_sum'] / out['n_obs']
    out['junior_comp'] = out['junior_sum'] / out['n_obs']
    out['junior_high_comp'] = out['junior_comp']
    out['senior_high_comp'] = out['senior_sum'] / out['n_obs']
    out['college_comp'] = out['college_sum'] / out['n_obs']
    out = out[['county_curr6','birth_i','minority','n_obs','eduy_sum','eduy_mean','primary_comp','junior_comp','junior_high_comp','senior_high_comp','college_comp']]
    out.to_csv(out90, index=False)
    print(f'wrote {out90} rows={len(out)}', flush=True)
else:
    def build90(df):
        df = df.dropna(subset=['county','age_c','age','educ']).copy()
        df['county_curr6'] = pd.to_numeric(df['county'], errors='coerce').astype('Int64').astype(str).str.replace('<NA>','').str.zfill(6)
        df['birth_i'] = 1000 + pd.to_numeric(df['age_c'], errors='coerce')*100 + pd.to_numeric(df['age'], errors='coerce')
        df['eduy'] = pd.NA
        df.loc[df['educ']==1, 'eduy'] = 0
        df.loc[df['educ']==2, 'eduy'] = 6
        df.loc[df['educ']==3, 'eduy'] = 9
        df.loc[df['educ'].isin([4,5]), 'eduy'] = 12
        df.loc[df['educ']==6, 'eduy'] = 15
        df.loc[df['educ']==7, 'eduy'] = 16
        df['eduy'] = pd.to_numeric(df['eduy'], errors='coerce')
        df['minority'] = (pd.to_numeric(df['race'], errors='coerce') != 1).astype('Int64')
        df = df[df['birth_i'].between(1920, 1968, inclusive='both') & df['eduy'].between(0,25, inclusive='both') & (df['birth_i'] != 1939)]
        if df.empty:
            return None
        df['primary'] = (df['eduy'] >= 6).astype(int)
        df['junior'] = (df['eduy'] >= 9).astype(int)
        df['senior'] = (df['eduy'] >= 12).astype(int)
        df['college'] = (df['eduy'] >= 15).astype(int)
        return df.groupby(['county_curr6','birth_i','minority'], as_index=False).agg(n_obs=('eduy','size'), eduy_sum=('eduy','sum'), primary_sum=('primary','sum'), junior_sum=('junior','sum'), senior_sum=('senior','sum'), college_sum=('college','sum'))
    chunks90 = pyreadstat.read_file_in_chunks(pyreadstat.read_dta, str(PROJ / 'data/raw/census/census1990.dta'), chunksize=500000, usecols=['county','age_c','age','educ','race'])
    append_grouped(chunks90, out90, build90)

# 2000 from local csv if exists else raw chunks
src00csv = Path('/tmp/census2000_raw_small.csv')
out00 = TEMP / 'micro_equiv_panel_2000_v1.csv'
if src00csv.exists():
    reader = pd.read_csv(src00csv, chunksize=500000, dtype={'uid':'Int64','birthyr':'float','eduyr':'float','race':'float'})
    acc=[]
    for i, df in enumerate(reader, start=1):
        df = df.dropna(subset=['uid','birthyr','eduyr']).copy()
        df['old6'] = df['uid'].astype('Int64').astype(str).str.replace('<NA>','').str.zfill(6)
        df['county_curr6'] = df['old6'].map(MAP00)
        df = df[df['county_curr6'].notna()].copy()
        df['birth_i'] = pd.to_numeric(df['birthyr'], errors='coerce').astype('Int64')
        df['eduy'] = pd.to_numeric(df['eduyr'], errors='coerce')
        df['minority'] = (pd.to_numeric(df['race'], errors='coerce') != 1).astype('Int64')
        df = df[df['birth_i'].between(1920, 1978, inclusive='both') & df['eduy'].between(0,25, inclusive='both') & (df['birth_i'] != 1939)]
        if not df.empty:
            df['primary'] = (df['eduy'] >= 6).astype(int)
            df['junior'] = (df['eduy'] >= 9).astype(int)
            df['senior'] = (df['eduy'] >= 12).astype(int)
            df['college'] = (df['eduy'] >= 15).astype(int)
            g = df.groupby(['county_curr6','birth_i','minority'], as_index=False).agg(
                n_obs=('eduy','size'),
                eduy_sum=('eduy','sum'),
                primary_sum=('primary','sum'),
                junior_sum=('junior','sum'),
                senior_sum=('senior','sum'),
                college_sum=('college','sum')
            )
            acc.append(g)
        if i % 5 == 0:
            print(f'2000 csv chunk {i}', flush=True)
    out = pd.concat(acc, ignore_index=True)
    out = out.groupby(['county_curr6','birth_i','minority'], as_index=False)[['n_obs','eduy_sum','primary_sum','junior_sum','senior_sum','college_sum']].sum()
    out['eduy_mean'] = out['eduy_sum'] / out['n_obs']
    out['primary_comp'] = out['primary_sum'] / out['n_obs']
    out['junior_comp'] = out['junior_sum'] / out['n_obs']
    out['junior_high_comp'] = out['junior_comp']
    out['senior_high_comp'] = out['senior_sum'] / out['n_obs']
    out['college_comp'] = out['college_sum'] / out['n_obs']
    out = out[['county_curr6','birth_i','minority','n_obs','eduy_sum','eduy_mean','primary_comp','junior_comp','junior_high_comp','senior_high_comp','college_comp']]
    out.to_csv(out00, index=False)
    print(f'wrote {out00} rows={len(out)}', flush=True)
else:
    def build00(df):
        df = df.dropna(subset=['uid','birthyr','eduyr']).copy()
        df['old6'] = pd.to_numeric(df['uid'], errors='coerce').astype('Int64').astype(str).str.replace('<NA>','').str.zfill(6)
        df['county_curr6'] = df['old6'].map(MAP00)
        df = df[df['county_curr6'].notna()].copy()
        df['birth_i'] = pd.to_numeric(df['birthyr'], errors='coerce').astype('Int64')
        df['eduy'] = pd.to_numeric(df['eduyr'], errors='coerce')
        df['minority'] = (pd.to_numeric(df['race'], errors='coerce') != 1).astype('Int64')
        df = df[df['birth_i'].between(1920, 1978, inclusive='both') & df['eduy'].between(0,25, inclusive='both') & (df['birth_i'] != 1939)]
        if df.empty:
            return None
        df['primary'] = (df['eduy'] >= 6).astype(int)
        df['junior'] = (df['eduy'] >= 9).astype(int)
        df['senior'] = (df['eduy'] >= 12).astype(int)
        df['college'] = (df['eduy'] >= 15).astype(int)
        return df.groupby(['county_curr6','birth_i','minority'], as_index=False).agg(
            n_obs=('eduy','size'),
            eduy_sum=('eduy','sum'),
            primary_sum=('primary','sum'),
            junior_sum=('junior','sum'),
            senior_sum=('senior','sum'),
            college_sum=('college','sum')
        )
    chunks00 = pyreadstat.read_file_in_chunks(
        pyreadstat.read_dta,
        str(PROJ / 'data/raw/census/census2000.dta'),
        chunksize=500000,
        usecols=['uid','birthyr','eduyr','race']
    )
    append_grouped(chunks00, out00, build00)

print('done all', flush=True)
