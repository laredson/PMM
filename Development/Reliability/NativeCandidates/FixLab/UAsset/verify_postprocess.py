"""Independent Python check of SYNTHETIC postProcess packets; no game tools.
This is a second implementation of the same documented, externally supplied
bounded-schema assumptions. It is not Unreal/game compatibility evidence.
"""
import base64
import hashlib
import json
import struct
from pathlib import Path
from verify_reference import inspect as read_header, Cursor


def digest(b): return hashlib.sha256(b).hexdigest()
def unpack64(b): return base64.b64decode(b, validate=True)
def i32(b,p): return struct.unpack_from('<i',b,p)[0]

def preload_offset(h):
    r=Cursor(h,28);r.i();r.string();r.u();r.raw(60+16)
    n=r.i();r.raw(n*8);r.engine();r.engine();r.raw(16+4+8+4)
    n=r.i();r.raw(n*4);r.i();return r.i()

def import_identity(header, meta, index):
    names=meta['names']
    # The existing reference reader records names as text+hash/encoding entries.
    text=lambda n:names[n]['text']
    chain=[];seen=set()
    while True:
        if index in seen or len(chain)>64: raise ValueError('cyclic import path')
        seen.add(index)
        row=meta['imports'][index]
        cp=text(row['classPackage']['index']);cn=text(row['className']['index']);name=text(row['objectName']['index'])
        if row['optional']: raise ValueError('optional import')
        outer=row['outer']
        if outer==0:
            if cp!='/Script/CoreUObject' or cn!='Package' or not name.startswith('/'):raise ValueError('root')
            return name+''.join('.'+q for q in reversed(chain))
        chain.append(name)
        if outer>0: raise ValueError('exported outer')
        index=-outer-1


def property_offset(data, start, size, schema):
    end=start+size;pos=start;logical=0;slots=[];mask_bits=0
    version=schema.get('schema')
    if version not in ('PMM_FIXED_UNVERSIONED_SCHEMA_V1','PMM_FIXED_UNVERSIONED_SCHEMA_V2'):raise ValueError('schema version')
    if size<2 or start<0 or end>len(data):raise ValueError('export range')
    for _ in range(1024):
        if pos+2>end: raise ValueError('truncated fragment')
        word=struct.unpack_from('<H',data,pos)[0];pos+=2
        logical+=word&127;n=word>>9;masked=bool(word&128)
        if logical+n>len(schema['fields']):raise ValueError('schema range')
        for j in range(n):
            slots.append((logical+j,mask_bits if masked else None))
            if masked:mask_bits+=1
        logical+=n
        if word&256:break
    else:raise ValueError('fragment limit')
    mask_len=(1 if mask_bits<=8 else 2 if mask_bits<=16 else ((mask_bits+31)//32)*4) if mask_bits else 0
    if pos+mask_len>end:raise ValueError('mask range')
    mask=int.from_bytes(data[pos:pos+mask_len],'little');pos+=mask_len
    if mask>>mask_bits:raise ValueError('mask padding')
    widths={'BoolProperty':1,'ByteProperty':1,'IntProperty':4,'UInt32Property':4,'FloatProperty':4,'Int64Property':8,'DoubleProperty':8,'NameProperty':8,'ObjectProperty':4,'ClassProperty':4}
    targets=[]
    for index,bit in slots:
        f=schema['fields'][index];typ=f['type']
        zero=bit is not None and (mask>>bit)&1
        if f['name']=='PostProcessAnimBlueprint':
            if typ!='ClassProperty' or zero:raise ValueError('target not explicit class reference')
            targets.append((pos,index))
        if not zero:
            if typ=='ArrayProperty':
                inner=f.get('innerType')
                if version!='PMM_FIXED_UNVERSIONED_SCHEMA_V2' or inner not in widths:raise ValueError('unsupported array serializer')
                if pos+4>end:raise ValueError('truncated array count')
                count=i32(data,pos)
                if count<0 or count>1<<20:raise ValueError('array count')
                pos+=4+count*widths[inner]
            else:
                if f.get('innerType') is not None or typ not in widths:raise ValueError('unsupported scalar serializer')
                pos+=widths[typ]
        if pos>end:raise ValueError('truncated value')
    if len(targets)!=1:raise ValueError('target count')
    return targets[0],pos


def verify(packet):
    v=packet['Input'];req=v['Request'];rep=packet['Report']
    h=unpack64(v['Header']);x=unpack64(v['Data']);schema_bytes=unpack64(req['schema'])
    if [digest(h),digest(x),digest(schema_bytes)]!=[req['headerSha256'],req['exportSha256'],req['schemaSha256']]:raise ValueError('input pins')
    m=read_header(h,x);s=json.loads(schema_bytes)
    if s['classPath']!='/Script/Engine.SkeletalMesh':raise ValueError('class schema')
    ex=m['exports'][req['exportIndex']];start=ex['serialOffset']-len(h)
    (at,schema_index),prefix_end=property_offset(x,start,ex['serialSize'],s)
    if at!=req['expectedSerializedOffset']:raise ValueError('derived offset mismatch')
    def find(spec):
        rows=[]
        for k,row in enumerate(m['imports']):
            if import_identity(h,m,k)!=spec['path']:continue
            names=m['names']
            if names[row['classPackage']['index']]['text']!=spec['classPackage'] or names[row['className']['index']]['text']!=spec['className']:raise ValueError('import class')
            rows.append(-k-1)
        if len(rows)!=1:raise ValueError('import identity')
        return rows[0]
    stale,safe=find(req['stale']),find(req['safe'])
    if import_identity(h,m,-ex['class']-1)!=s['classPath']:raise ValueError('export class')
    if i32(x,at)!=stale or m['preload'].count(stale)!=1:raise ValueError('previous value')
    row=req['preloadIndex'];group=req['dependencyGroup']
    first=ex['firstDependency']+sum(ex['dependencyCounts'][:group]);count=ex['dependencyCounts'][group]
    if not(first<=row<first+count) or m['preload'][row]!=stale:raise ValueError('dependency scope')
    dep=preload_offset(h)+4*row
    want_h=bytearray(h);want_x=bytearray(x)
    struct.pack_into('<i',want_h,dep,safe);struct.pack_into('<i',want_x,at,0)
    actual_h=unpack64(packet['ResultHeader']);actual_x=unpack64(packet['ResultData'])
    if bytes(want_h)!=actual_h or bytes(want_x)!=actual_x:raise ValueError('unexpected changed bytes')
    if actual_h!=unpack64(v['ExpectedHeader']) or actual_x!=unpack64(v['ExpectedData']):raise ValueError('fixture expectation')
    if digest(actual_h)!=req['resultHeaderSha256'] or digest(actual_x)!=req['resultExportSha256']:raise ValueError('output pins')
    after=read_header(actual_h,actual_x)
    if after['preload'][row]!=safe or i32(actual_x,at)!=0:raise ValueError('post condition')
    if rep['parsedPrefixEnd']!=prefix_end or rep['schemaIndex']!=schema_index or rep['exportRelativeOffset']!=at-start:raise ValueError('report coordinates')
    if rep['functionalParityVerified']:raise ValueError('false parity claim')
    return dict(fixture=v['id'],headerSha256=digest(actual_h),exportSha256=digest(actual_x),propertyUexpOffset=at,preloadHeaderOffset=dep,allBytesCompared=True)


def main():
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('packets',type=Path);a=p.parse_args()
    paths=sorted(a.packets.glob('*.json'))
    if len(paths)!=8:raise ValueError('expected eight synthetic packets')
    rows=[verify(json.loads(q.read_text(encoding='utf-8'))) for q in paths]
    print(json.dumps(dict(schema='PMM_POSTPROCESS_INDEPENDENT_V1',fixtures=rows,allCompared=True,syntheticOnly=True,gameAssetsRead=False,engineCompatibilityVerified=False),indent=2))
if __name__=='__main__':main()
