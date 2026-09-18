"""Independent, synthetic UE5.1 layout vectors. No assets or Go imports."""
import base64
import hashlib
import json
import struct
from pathlib import Path


def make(kind='basic'):
    b=bytearray(); fields={}
    def u(n): b.extend(struct.pack('<I', n))
    def i(n,name=None):
        if name: fields[name]=len(b)
        b.extend(struct.pack('<i',n))
    def q(n,name=None):
        if name: fields[name]=len(b)
        b.extend(struct.pack('<q',n))
    def string(s,wide=False):
        if not s: i(0); return
        data=s.encode('utf-16-le' if wide else 'ascii')+ (b'\0\0' if wide else b'\0')
        i(-len(data)//2 if wide else len(data)); b.extend(data)
    def fname(n,num=0):i(n);i(num)
    def engine():
        b.extend(struct.pack('<HHHI',5,1,1,0));string('synthetic-layout-only')
    empty=kind=='empty';unversioned=kind=='unversioned';opaque=kind=='opaque'
    names=[] if empty else ['None','/Script/CoreUObject','Class','SyntheticObject','First','Second']
    if kind=='unicode':names[-1]='Espa\u00f1ol_\u4e2d\u6587_\U0001f30d'
    nimp=0 if empty else 2; nexp=0 if empty else (3 if kind=='multi' else 2)
    u(0x9e2a83c1);i(-8,'legacy');i(0 if unversioned else 864,'ue3');i(0 if unversioned else 522,'ue4');i(0 if unversioned else 1008,'ue5');i(0,'licensee');i(0,'customCount');i(0,'headerSize');string('/Game/Synthetic');u(0x80002200);fields['flags']=len(b)-4
    i(len(names),'nameCount');i(0,'nameOffset');i(0,'softObjectCount');i(0,'softObjectOffset');i(0,'gatherCount');i(0,'gatherOffset')
    i(nexp,'exportCount');i(0,'exportOffset');i(nimp,'importCount');i(0,'importOffset');i(0,'dependsOffset')
    i(0,'softPackageCount');i(0,'softPackageOffset');i(0,'searchableOffset');i(0,'thumbnailOffset');b.extend(bytes(range(16)))
    i(1);i(nexp);i(len(names));engine();engine();i(0,'compressionFlags');i(0,'compressedChunks');u(0x12345678);i(0,'additionalPackages')
    i(0,'assetRegistryOffset');q(0,'bulkDataStart');i(0,'worldTileOffset');i(1);i(3)
    i(nexp,'preloadCount');i(0,'preloadOffset');i(len(names),'namesReferenced');q(-1,'payloadToc')
    summary_end=len(b)
    def set32(field,value):struct.pack_into('<i',b,fields[field],value)
    name_spans=[]
    if names:
        set32('nameOffset',len(b))
        for j,s in enumerate(names):
            start=len(b);string(s,kind=='unicode' and j==5);b.extend(struct.pack('<HH',j*11,j*13));name_spans.append([start,len(b)-start])
    imports=[]
    if nimp:
        set32('importOffset',len(b))
        for j in range(nimp):
            start=len(b);fname(1);fname(2);i(0 if j==0 else -1);fname(3 if j==0 else 4);i(j==1)
            imports.append({'offset':start,'outer':0 if j==0 else -1,'name':3 if j==0 else 4})
    exports=[];payload=bytearray()
    if nexp:
        set32('exportOffset',len(b))
        for j in range(nexp):
            start=len(b);data=(b'NOT-GAME-DATA-'+str(j).encode()) if j%2==0 else b''
            i(-2);i(0);i(0);i(0);fname(4+j%2,j);u(1)
            q(len(data));q(0);i(0);i(0);i(0);i(0);u(0);i(0);i(1);i(0);i(j)
            for value in (1,0,0,0):i(value)
            assert len(b)-start==96
            exports.append({'offset':start,'payloadOffset':len(payload),'size':len(data),'name':4+j%2,'number':j,'firstDep':j});payload.extend(data)
        set32('dependsOffset',len(b))
        for j in range(nexp):i(1);i(-2)
        set32('preloadOffset',len(b))
        for j in range(nexp):i(-2)
    if opaque:
        set32('assetRegistryOffset',len(b));b.extend(b'OPAQUE-SYNTHETIC-REGISTRY')
    total=len(b);set32('headerSize',total)
    struct.pack_into('<q',b,fields['bulkDataStart'],total+len(payload))
    for entry in exports:struct.pack_into('<q',b,entry['offset']+36,total+entry['payloadOffset'])
    return dict(id=kind,header=base64.b64encode(b).decode(),data=base64.b64encode(payload).decode(),
                fields=fields,expected=dict(headerSize=total,summaryEnd=summary_end,names=names,nameSpans=name_spans,
                imports=imports,exports=exports,unversioned=unversioned,opaque=opaque,
                headerSha256=hashlib.sha256(b).hexdigest(),dataSha256=hashlib.sha256(payload).hexdigest()))


if __name__=='__main__':
    path=Path(__file__).with_name('vectors.json')
    path.write_text(json.dumps([make(k) for k in ('basic','unicode','unversioned','empty','opaque','multi')],indent=2)+'\n')
