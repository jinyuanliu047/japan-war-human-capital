"""
IPUMS GEO3_CN{1982,1990,2000} -> current 6-digit GB county code (countyid_curr6).
v2: adds recovery layers for the ~300/wave codes name-matching missed.

Layers (within province; first hit wins):
  1982 : geo3_cn1982 authoritative crosswalk (~100%).
  1990/2000:
    L1 name_county_en   : IPUMS pinyin label == County0010 County_EN  (2010 geography)
    L2 alias_1982       : IPUMS label == 1982-crosswalk county_en_old -> curr6_final
    L3 name_cn_pinyin   : IPUMS label == pinyin(County0010 Chinese county name, suffix-stripped)
    L4 divchange        : IPUMS label == pinyin(division-changes {year} county name) -> GB code(year)
                          -> translate(year -> 2010) -> curr6  [recovers renamed/merged counties]
    L5 city_fallback    : IPUMS unit is a whole city/district -> map to the city's seat county
                          (min curr6 within the matched prefecture).  [per user instruction]

Outputs:
  data/temp/ipums_geo3_to_curr6_v2.csv          (wave, geo3_code, countyid_curr6, match_method)
  data/temp/ipums_geo3_to_curr6_unmatched_v2.csv
"""
import sys, os, re, csv, collections
from pathlib import Path
import openpyxl

PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/"
            "My Drive/Projects/ongoing/japan_war")
DIVCH = "/tmp/division-changes"
sys.path.insert(0, DIVCH); os.chdir(DIVCH)
from pypinyin import lazy_pinyin
from division_changes import translate

def norm_en(s):
    if s is None: return ""
    s = str(s).lower(); s = re.sub(r"\(.*?\)", "", s)
    return re.sub(r"[^a-z]", "", s)

SUF_CN = ["自治县","自治旗","各族自治县","左翼","右翼","左旗","右旗","中旗","前旗","后旗",
          "联合旗","自治州","地区","市辖区","特区","林区","县","市","区","旗","盟","州"]
def cn_root_py(s):
    s = re.sub(r"（.*?）|\(.*?\)", "", str(s))
    for suf in SUF_CN:
        if s.endswith(suf) and len(s) > len(suf):
            s = s[:-len(suf)]; break
    return "".join(lazy_pinyin(s)).replace("lü", "lv").replace("ü", "v")

# ---------- County0010 (2010 GB geography) ----------
wb = openpyxl.load_workbook(PROJ / "data/raw/China_Map/County0010.xlsx", read_only=True)
ws = wb["County0010"]; rows = ws.iter_rows(values_only=True); hdr = list(next(rows))
iP, iCity, iC = hdr.index("GbProv"), hdr.index("GbCity"), hdr.index("GBCounty")
iCEN, iCityEN = hdr.index("County_EN"), hdr.index("City_EN")
county_ref = collections.defaultdict(set)   # (prov2, norm county_en) -> {curr6}
city_seat  = collections.defaultdict(set)    # (prov2, norm city_en)  -> {curr6}  (whole prefecture)
curr6_set  = set()
for row in rows:
    if row[iC] is None: continue
    prov2 = f"{int(row[iP]):02d}"; curr6 = f"{int(row[iC]):06d}"; curr6_set.add(curr6)
    county_ref[(prov2, norm_en(row[iCEN]))].add(curr6)
    city_seat[(prov2, norm_en(row[iCityEN]))].add(curr6)

# ---------- County0010 Chinese county names (via countyid6_name_crosswalk) ----------
cn_ref = collections.defaultdict(set)        # (prov2, pinyin-root cn name) -> {curr6}
with open(PROJ / "data/temp/countyid6_name_crosswalk_v1.csv", encoding="utf-8-sig") as f:
    for r in csv.DictReader(f):
        curr6 = re.sub(r"\D", "", r["countyid_curr6"]).zfill(6)
        cn_ref[(curr6[:2], cn_root_py(r["county_name"]))].add(curr6)

# ---------- 1982 crosswalk alias ----------
geo3_1982 = {}; alias_1982 = collections.defaultdict(set)
with open(PROJ / "data/temp/countyid_1982_to_current_crosswalk_v2.csv") as f:
    for r in csv.DictReader(f):
        curr6 = re.sub(r"\D", "", r["countyid_curr6_final"]).zfill(6)
        g = re.sub(r"\D", "", r["geo3_cn1982"])
        if g: geo3_1982[g] = curr6
        alias_1982[(r["geo1_cn1982"].zfill(2), norm_en(r["county_en_old"]))].add(curr6)

# ---------- division-changes year tables: (prov2, pinyin name) -> set(year GB code) ----------
def load_year(year):
    d = collections.defaultdict(set); pref = collections.defaultdict(set)
    with open(f"{DIVCH}/tables/{year}.csv", encoding="utf-8") as f:
        rd = csv.reader(f)
        for row in rd:
            if len(row) < 2 or not re.fullmatch(r"\d{6}", row[0] or ""): continue
            code, name = row[0], row[1]; prov2 = code[:2]
            if code.endswith("00"):                      # prefecture-level
                pref[(prov2, cn_root_py(name))].add(code)
            else:
                d[(prov2, cn_root_py(name))].add(code)
    return d, pref
yr_county = {1990: load_year(1990)[0], 2000: load_year(2000)[0]}
yr_pref   = {1990: load_year(1990)[1], 2000: load_year(2000)[1]}

_tcache = {}
def to_curr6(code, year):
    key = (code, year)
    if key in _tcache: return _tcache[key]
    try:
        res = [c for c in translate(code, year, 2010) if c in curr6_set]
    except Exception:
        res = []
    out = res[0] if res else (code if code in curr6_set else None)
    _tcache[key] = out; return out

# ---------- resolve ----------
out, unmatched = [], []; stats = collections.Counter()
with open(PROJ / "data/temp/ipums_geo3_labels_v2.csv") as f:
    for r in csv.DictReader(f):
        wave = int(r["wave"]); code = r["geo3_code"]; prov2 = r["prov2"]; nm = r["normname"]
        curr6 = method = None
        if wave == 1982:
            g8 = code[1:]
            if g8 in geo3_1982: curr6, method = geo3_1982[g8], "geo3_1982_authoritative"
        if curr6 is None and wave != 1982:
            key = (prov2, nm)
            if key in county_ref and len(county_ref[key]) == 1:
                curr6, method = next(iter(county_ref[key])), "name_county_en"
            elif key in alias_1982 and len(alias_1982[key]) == 1:
                curr6, method = next(iter(alias_1982[key])), "alias_1982"
            elif key in cn_ref and len(cn_ref[key]) == 1:
                curr6, method = next(iter(cn_ref[key])), "name_cn_pinyin"
            elif key in yr_county[wave] and len(yr_county[wave][key]) == 1:
                c = to_curr6(next(iter(yr_county[wave][key])), wave)
                if c: curr6, method = c, "divchange_county"
            elif key in city_seat and len(city_seat[key]) >= 1:
                curr6, method = min(city_seat[key]), "city_fallback_county0010"
            elif key in yr_pref[wave] and len(yr_pref[wave][key]) >= 1:
                c = to_curr6(min(yr_pref[wave][key])[:4] + "01", wave) or to_curr6(min(yr_pref[wave][key]), wave)
                if c: curr6, method = c, "city_fallback_divchange"
        if curr6:
            out.append((wave, code, curr6, method)); stats[(wave, method)] += 1
        else:
            unmatched.append((wave, code, prov2, r["label"], nm)); stats[(wave, "UNMATCHED")] += 1

with open(PROJ / "data/temp/ipums_geo3_to_curr6_v2.csv", "w", newline="") as f:
    w = csv.writer(f); w.writerow(["wave", "geo3_code", "countyid_curr6", "match_method"]); w.writerows(out)
with open(PROJ / "data/temp/ipums_geo3_to_curr6_unmatched_v2.csv", "w", newline="") as f:
    w = csv.writer(f); w.writerow(["wave", "geo3_code", "prov2", "label", "normname"]); w.writerows(unmatched)

for wave in (1982, 1990, 2000):
    tot = sum(v for (wv, m), v in stats.items() if wv == wave)
    matched = tot - stats[(wave, "UNMATCHED")]
    print(f"wave {wave}: total={tot} matched={matched} ({100*matched/tot:.1f}%) unmatched={stats[(wave,'UNMATCHED')]}")
    for (wv, m), v in sorted(stats.items()):
        if wv == wave and m != "UNMATCHED": print(f"    {m}: {v}")
print("wrote data/temp/ipums_geo3_to_curr6_v2.csv")
