import json
from pathlib import Path
repo=Path(__file__).resolve().parents[2]
inputs=json.loads((repo/'Development/TestResults/datatable132-validation-inputs.json').read_text(encoding='utf-8-sig'))
data={k:json.loads(Path(v).read_text(encoding='utf-8-sig')) for k,v in inputs.items()}
historical=data['Historical']['rows'];base=data['Vanilla']['rows'];out=data['Output']['rows'];providers=[v['rows'] for k,v in data.items() if k not in ('Vanilla','Output','Historical')]
assert len(out)==len(base)==753
changed=preserved_true=checked=0
for i,(current,merged) in enumerate(zip(base,out)):
    assert current['id']==merged['id']
    expected={p['name']:p for p in current['properties']};actual={p['name']:p for p in merged['properties']}
    assert expected.keys()==actual.keys()
    old={p['name']:p for p in historical[i]['properties']}
    mods=[{p['name']:p for p in rows[i]['properties']} for rows in providers]
    for name,prop in expected.items():
        desired=prop['value']
        if name=='IsUncapturable':
            assert all(name not in mod for mod in mods)
            preserved_true+=bool(desired)
        else:
            deltas=[mod[name]['value'] for mod in mods if mod[name]['value']!=old[name]['value']]
            if deltas:
                unique={json.dumps(v,sort_keys=True) for v in deltas}
                if len(unique)==1:desired=deltas[0]
                else:
                    assert current['id']=='Boar' and name=='WorkSuitability_MonsterFarm' and set(deltas)=={1,10}
                    desired=10
        assert actual[name]['value']==desired,(i,current['id'],name,actual[name]['value'],desired)
        assert actual[name]['type']==prop['type']
        changed+=desired!=prop['value'];checked+=1
assert preserved_true==103
report={'rows':len(out),'propertiesChecked':checked,'changedProperties':changed,'currentUncapturableTruePreserved':preserved_true,'runtimeTested':False}
(repo/'Development/TestResults/datatable132-validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS DataTable 1.0.4:',json.dumps(report))
