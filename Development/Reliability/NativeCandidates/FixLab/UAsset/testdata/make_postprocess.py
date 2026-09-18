"""Artificial scalar-schema packages, NOT extracted from a game or a mod.
No Go imports. The two expected four-byte edits are authored separately here.
"""
import base64
import hashlib
import json
import struct
import zlib
from pathlib import Path
from make_fixtures import make


def sha(b): return hashlib.sha256(b).hexdigest()
def b64(b): return base64.b64encode(b).decode('ascii')
def jsonb(v): return (json.dumps(v, indent=2)+'\n').encode('ascii')
def make_case(kind='basic'):
    old = make('basic')
    header = bytearray(base64.b64decode(old['header'])[:old['expected']['summaryEnd']])
    fields = old['fields']
    def i(v): header.extend(struct.pack('<i', v))
    def q(v): header.extend(struct.pack('<q', v))
    def f(n): i(n); i(0)
    def marker(k,v): struct.pack_into('<i',header,fields[k],v)
    names=['None','/Script/CoreUObject','Package','Class','/Script/Engine','SkeletalMesh',
           '/Game/Synthetic/Anim','AnimBlueprintGeneratedClass','ABP_Gura_C',
           '/Game/Synthetic/Body','Body','MeshFixture','ExtraFixture']
    if kind=='unicode':names.append('OnlySynthetic_\u4e2d\U0001f30d')
    marker('nameCount',len(names));marker('namesReferenced',len(names));marker('nameOffset',len(header))
    for j,n in enumerate(names):
        wide=not n.isascii();d=n.encode('utf-16-le' if wide else 'ascii')+(b'\0\0' if wide else b'\0')
        i(-len(d)//2 if wide else len(d));header.extend(d);header.extend(struct.pack('<HH',j*11,j*13))
    imports=[];marker('importCount',6);marker('importOffset',len(header))
    for cp,cn,outer,name in ((1,2,0,4),(1,3,-1,5),(1,2,0,6),(4,7,-3,8),(1,2,0,9),(1,3,-5,10)):
        imports.append(len(header));f(cp);f(cn);i(outer);f(name);i(0)
    # Two exports; the selected export starts six bytes into .uexp. For basic,
    # fragment(2) + 28 int32 values(112) yields the checked absolute offset 120.
    props=[dict(name=f'Pad{j:02}',type='IntProperty') for j in range(28)]+[dict(name='PostProcessAnimBlueprint',type='ClassProperty')]
    slots=list(range(len(props)));zeros=set()
    if kind=='mixed':
        props=[dict(name='Flag',type='BoolProperty'),dict(name='ByteValue',type='ByteProperty'),dict(name='FloatValue',type='FloatProperty'),dict(name='LongValue',type='Int64Property'),dict(name='NameValue',type='NameProperty'),dict(name='ObjectValue',type='ObjectProperty'),dict(name='PostProcessAnimBlueprint',type='ClassProperty')]
        slots=list(range(len(props)))
    if kind=='masked':zeros={0,3,25}
    if kind=='skipped':slots=list(range(2,len(props)))
    mask=bytearray()
    if zeros:mask=bytearray(((len(slots)+31)//32)*4 if len(slots)>16 else (2 if len(slots)>8 else 1))
    prefix=bytearray(struct.pack('<H',(slots[0] if slots else 0)|(128 if zeros else 0)|256|(len(slots)<<9)))
    for idx,j in enumerate(slots):
        if j in zeros:mask[idx//8]|=1<<(idx%8)
    prefix.extend(mask);target=None
    for j in slots:
        if j in zeros:continue
        t=props[j]['type']
        if props[j]['name']=='PostProcessAnimBlueprint':target=6+len(prefix);prefix.extend(struct.pack('<i',-4))
        elif t=='BoolProperty':prefix.extend(b'\1')
        elif t=='ByteProperty':prefix.extend(b'\x42')
        elif t=='Int64Property':prefix.extend(struct.pack('<q',99))
        elif t=='NameProperty':prefix.extend(struct.pack('<ii',11,0))
        elif t=='ObjectProperty':prefix.extend(struct.pack('<i',-2))
        elif t=='FloatProperty':prefix.extend(struct.pack('<f',1.25))
        else:prefix.extend(struct.pack('<i',j+100))
    prefix_end=6+len(prefix)
    tail=b'UNKNOWN-NATIVE-TAIL'
    if kind=='decoy':tail+=struct.pack('<i',-4)+b'-DO-NOT-REPLACE'
    data=bytearray(b'BEFORE'+prefix+tail+b'UNREFERENCED-TAIL')
    marker('exportCount',2);marker('exportOffset',len(header));exports=[]
    for j,off,size in ((0,0,6),(1,6,len(prefix)+len(tail))):
        exports.append(len(header));i(-2);i(0);i(0);i(0);f(12 if j==0 else 11);i(1);q(size);q(off)
        for _ in range(4):i(0)
        i(0);i(0);i(1);i(0);i(j)
        for c in ((1,0,0,0) if j==0 else (0,1,0,0)):i(c)
        assert len(header)-exports[-1]==96
    marker('dependsOffset',len(header));i(0);i(0)
    marker('preloadCount',2);marker('preloadOffset',len(header));i(-2);i(-4)
    if kind in ('opaque','decoy'):
        marker('assetRegistryOffset',len(header));header.extend(b'OPAQUE-REGISTRY-BYTES')
    marker('headerSize',len(header))
    struct.pack_into('<q',header,fields['bulkDataStart'],len(header)+len(data))
    for j,e in enumerate(exports):struct.pack_into('<q',header,e+36,len(header)+(6 if j else 0))
    # Deliberately leave the original generation field values: these are test
    # packages, and the reader treats generations as historical data.
    schema=jsonb(dict(schema='PMM_FIXED_UNVERSIONED_SCHEMA_V1',profile='cooked-ue4-522-ue5-1008',classPath='/Script/Engine.SkeletalMesh',fields=props))
    result_header=bytearray(header);result_data=bytearray(data)
    dep=fields['preloadOffset'];dep=struct.unpack_from('<i',header,dep)[0]+4
    struct.pack_into('<i',result_header,dep,-6);struct.pack_into('<i',result_data,target,0)
    req=dict(headerSha256=sha(header),exportSha256=sha(data),resultHeaderSha256=sha(result_header),resultExportSha256=sha(result_data),schema=b64(schema),schemaSha256=sha(schema),exportIndex=1,exportObject='MeshFixture',stale=dict(path='/Game/Synthetic/Anim.ABP_Gura_C',classPackage='/Script/Engine',className='AnimBlueprintGeneratedClass'),safe=dict(path='/Game/Synthetic/Body.Body',classPackage='/Script/CoreUObject',className='Class'),preloadIndex=1,dependencyGroup=1,expectedSerializedOffset=target)
    return dict(id=kind,header=b64(header),data=b64(data),request=req,expectedHeader=b64(result_header),expectedData=b64(result_data),positions=dict(imports=imports,exports=exports,preload=dep,property=target,prefixEnd=prefix_end,fields=fields))


def all_cases():return [make_case(k) for k in ('basic','masked','skipped','mixed','unicode','opaque','decoy')]
def encoded_cases():
    raw=jsonb(all_cases())
    return dict(schema='PMM_SYNTHETIC_FIXTURE_ZLIB_V1',decodedBytes=len(raw),decodedSha256=sha(raw),content=b64(zlib.compress(raw,9)))
if __name__=='__main__':Path(__file__).with_name('postprocess-vectors.json').write_bytes(jsonb(encoded_cases()))
