#!/usr/bin/env python3
"""Rebuild PMM CKL/Catalog/case-index.json from Stable + Experimental knowledge.

Uses only the Python standard library. This is a maintainer tool; the generated
catalog is shipped with the portable PMM application so Analyze never needs to
scan every knowledge document at runtime.
"""
from __future__ import annotations
import hashlib, json, sys
from pathlib import Path

repo = Path(__file__).resolve().parents[3]
app = repo / "PMM"
stable = app / "CKL" / "Stable"
experimental = app / "CKL" / "Experimental"
out = app / "CKL" / "Catalog" / "case-index.json"

def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def provider_rows(rows):
    result=[]
    for p in rows or []:
        if isinstance(p,str): result.append({"name":p,"pakSha256":""})
        elif isinstance(p,dict): result.append({"name":str(p.get("name",p.get("provider",""))),"pakSha256":str(p.get("pakSha256",p.get("sha256",""))).lower()})
    return [x for x in result if x["name"]]

def runtime_status(obj):
    st=obj.get("status",{}) if isinstance(obj,dict) else {}
    if isinstance(st,dict): return str(st.get("runtime",st.get("status","")))
    return str(st or "")

entries=[]
def add(kind, channel, obj, source, prod=False):
    asset=str(obj.get("asset",""))
    kid=str(obj.get("id",obj.get("knowledgeId","")))
    if not asset or not kid: return
    row={
      "knowledgeId":kid,"kind":kind,"channel":channel,"asset":asset,
      "providers":provider_rows(obj.get("providers",[])),"source":source,
      "runtimeStatus":runtime_status(obj)
    }
    if kind=="production-recipe": row["productionEnabled"]=bool(obj.get("production",{}).get("enabled",False))
    elif prod: row["productionEnabled"]=bool(prod)
    entries.append(row)

kb=json.loads((stable/'known-behaviors.json').read_text(encoding='utf-8-sig'))
for x in kb.get('cases',[]): add('behavior','stable',x,'Stable/known-behaviors.json')
kf=json.loads((stable/'known-fixtures.json').read_text(encoding='utf-8-sig'))
for x in kf.get('fixtures',[]): add('fixture','stable',x,'Stable/known-fixtures.json')
pr=json.loads((stable/'production-recipes.json').read_text(encoding='utf-8-sig'))
for x in pr.get('recipes',[]): add('production-recipe','stable',x,'Stable/production-recipes.json')
exp_path=experimental/'library.json'
if exp_path.exists():
    ex=json.loads(exp_path.read_text(encoding='utf-8-sig'))
    for x in ex.get('entries',[]): add(str(x.get('kind','experimental')),'experimental',x,'Experimental/library.json',x.get('productionEnabled',False))

entries.sort(key=lambda x:(x['asset'].lower(),x['kind'],x['knowledgeId'].lower()))
by_asset={}; by_provider={}
for i,e in enumerate(entries):
    by_asset.setdefault(e['asset'],[]).append(i)
    for p in e['providers']: by_provider.setdefault(p['name'].lower(),[]).append(i)
source_files=[]
for p in sorted(list(stable.glob('*.json'))+[exp_path], key=lambda x:x.as_posix().lower()):
    if p.exists():
        rel=p.relative_to(app/'CKL').as_posix()
        source_files.append({"path":rel,"sha256":sha256(p)})

doc={
 "schema":"PMM_CKL_CASE_INDEX_V1",
 "generatedFrom":"PMM/CKL Stable + Experimental local libraries",
 "sourceFiles":source_files,
 "entries":entries,
 "lookup":{"byAsset":by_asset,"byProviderNameLower":by_provider},
 "safety":"Index is discovery only. Production authorization still requires the exact validation contract of the referenced Stable production recipe. Experimental entries never authorize output."
}
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(doc,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(f"CKL_CATALOG_OK entries={len(entries)} stable={sum(e['channel']=='stable' for e in entries)} experimental={sum(e['channel']=='experimental' for e in entries)}")
