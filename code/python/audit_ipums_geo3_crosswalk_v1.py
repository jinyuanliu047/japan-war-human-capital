"""
Audit the IPUMS GEO3 -> countyid_curr6 crosswalk (v2) for likely mapping errors.

For every matched code, compare the IPUMS pinyin label against the assigned county's
own names (County0010 English + Chinese-name pinyin). Agreement = equal, or one is a
prefix of the other (handles IPUMS dropping the 县/市 suffix). Province must agree by
construction. Flags disagreements per match method, and reports many-to-one collapses.

Outputs data/temp/ipums_geo3_crosswalk_audit_v1.csv (every match with an agree flag).
"""
import re, csv, collections
from pathlib import Path
import openpyxl

PROJ = Path("/Users/jinyuanliu/Library/CloudStorage/GoogleDrive-robert.j.liu047@gmail.com/"
            "My Drive/Projects/ongoing/japan_war")
import sys
sys.path.insert(0, "/tmp/division-changes")
from pypinyin import lazy_pinyin

def norm(s):
    if s is None: return ""
    s = str(s).lower(); s = re.sub(r"\(.*?\)", "", s)
    return re.sub(r"[^a-z]", "", s)
SUF = ["自治县","自治旗","各族自治县","左翼","右翼","左旗","右旗","中旗","前旗","后旗",
       "联合旗","自治州","地区","市辖区","特区","林区","县","市","区","旗","盟","州"]
def cn_root(s):
    s = re.sub(r"（.*?）|\(.*?\)", "", str(s))
    for suf in SUF:
        if s.endswith(suf) and len(s) > len(suf): s = s[:-len(suf)]; break
    return "".join(lazy_pinyin(s)).replace("lü","lv").replace("ü","v")

# curr6 -> set of acceptable name roots (english + chinese pinyin), and prov2
names = collections.defaultdict(set); prov_of = {}
wb = openpyxl.load_workbook(PROJ/"data/raw/China_Map/County0010.xlsx", read_only=True)
ws = wb["County0010"]; rows = ws.iter_rows(values_only=True); h = list(next(rows))
iP,iC,iCEN,iCityEN = h.index("GbProv"),h.index("GBCounty"),h.index("County_EN"),h.index("City_EN")
for r in rows:
    if r[iC] is None: continue
    c=f"{int(r[iC]):06d}"; prov_of[c]=f"{int(r[iP]):02d}"
    names[c].add(norm(r[iCEN])); names[c].add(norm(r[iCityEN]))
with open(PROJ/"data/temp/countyid6_name_crosswalk_v1.csv", encoding="utf-8-sig") as f:
    for r in csv.DictReader(f):
        c=re.sub(r"\D","",r["countyid_curr6"]).zfill(6)
        names[c].add(cn_root(r["county_name"])); prov_of.setdefault(c,c[:2])

labels={}
with open(PROJ/"data/temp/ipums_geo3_labels_v2.csv") as f:
    for r in csv.DictReader(f): labels[(int(r["wave"]),r["geo3_code"])]=(r["prov2"],r["normname"],r["label"])

def agree(a,b):
    if not a or not b: return False
    return a==b or a.startswith(b) or b.startswith(a)

rows_out=[]; by_method=collections.Counter(); mism=collections.Counter()
prov_bad=0; many=collections.defaultdict(lambda: collections.Counter())
with open(PROJ/"data/temp/ipums_geo3_to_curr6_v2.csv") as f:
    for r in csv.DictReader(f):
        wave=int(r["wave"]); geo3=r["geo3_code"]; curr6=r["countyid_curr6"].zfill(6); m=r["match_method"]
        prov2,nm,label=labels.get((wave,geo3),("","",""))
        nameset=names.get(curr6,set())
        ok=any(agree(nm,x) for x in nameset)
        provok=(prov_of.get(curr6,curr6[:2])==prov2)
        by_method[m]+=1
        if not ok: mism[m]+=1
        if not provok: prov_bad+=1
        many[wave][curr6]+=1
        rows_out.append((wave,geo3,label,nm,curr6,m,int(ok),int(provok)))

with open(PROJ/"data/temp/ipums_geo3_crosswalk_audit_v1.csv","w",newline="") as f:
    w=csv.writer(f); w.writerow(["wave","geo3","label","ipums_norm","curr6","method","name_agree","prov_agree"])
    w.writerows(rows_out)

print("=== name agreement by method (mismatch / total) ===")
for m in sorted(by_method):
    print(f"  {m:28s} {by_method[m]-mism[m]:5d}/{by_method[m]:<5d} agree   ({mism[m]} disagree)")
print(f"\nprovince disagreements (should be 0): {prov_bad}")
print("\n=== sample NAME-DISAGREE matches (potential errors) ===")
shown=0
for wv,g,label,nm,c,m,ok,pk in rows_out:
    if not ok and m!="city_fallback_county0010" and shown<35:
        cands="|".join(sorted(names.get(c,set()))[:4])
        print(f"  w{wv} {label!r:24s}-> {c} [{m}]  county-names: {cands}"); shown+=1
print("\n=== many IPUMS codes -> one curr6 (top collapses per wave) ===")
for wv in (1982,1990,2000):
    top=many[wv].most_common(5)
    print(f"  wave {wv}: "+", ".join(f"{c}:{n}" for c,n in top))
