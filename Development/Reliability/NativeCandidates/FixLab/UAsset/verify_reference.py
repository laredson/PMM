"""Independent Python summary/table reader for the six synthetic vectors.
No code from the Go reader is imported. This is a verification tool, not a
production UAsset parser, extractor, game compatibility test, or asset loader.
"""
import base64
import hashlib
import json
from pathlib import Path
import struct
import sys

class Cursor:
    def __init__(self,b,pos=0):self.b,self.p=b,pos
    def raw(self,n):
        if n<0 or self.p+n>len(self.b):raise ValueError('truncated')
        d=self.b[self.p:self.p+n];self.p+=n;return d
    def num(self,fmt):return struct.unpack('<'+fmt,self.raw(struct.calcsize('<'+fmt)))[0]
    def i(self):return self.num('i')
    def u(self):return self.num('I')
    def q(self):return self.num('q')
    def boolean(self):
        n=self.i()
        if n not in (0,1):raise ValueError('boolean')
        return bool(n)
    def string(self):
        n=self.i()
        if n==0:return '',False
        if abs(n)>8192:raise ValueError('string limit')
        wide=n<0;raw=self.raw(abs(n)*(2 if wide else 1));term=b'\0\0' if wide else b'\0'
        if not raw.endswith(term):raise ValueError('terminator')
        s=raw[:-len(term)].decode('utf-16-le' if wide else 'ascii')
        if '\0' in s:raise ValueError('embedded NUL')
        return s,wide
    def fname(self):return {'index':self.i(),'number':self.i()}
    def engine(self):return dict(Major=self.num('H'),Minor=self.num('H'),Patch=self.num('H'),Changelist=self.u(),Branch=self.string()[0])

def inspect(header,data):
    if len(header)>64<<20 or len(data)>256<<20:raise ValueError('input limit')
    r=Cursor(header)
    if r.u()!=0x9e2a83c1 or r.i()!=-8:raise ValueError('signature')
    ue3,ue4,ue5,licensee,custom=(r.i() for _ in range(5))
    if (ue4,ue5) not in ((0,0),(522,1008)) or licensee or custom:raise ValueError('profile')
    total=r.i();folder=r.string()[0];flags=r.u()
    if total!=len(header) or flags & 0x80000200 != 0x80000200:raise ValueError('header')
    names_n,names_o,soft_n,soft_o,text_n,text_o,ex_n,ex_o,im_n,im_o,depends_o,refs_n,refs_o,search_o,thumb_o=(r.i() for _ in range(15))
    if any((soft_n,text_n,refs_n,search_o,thumb_o)):raise ValueError('optional')
    if not 0<=names_n<=65536 or not 0<=ex_n+im_n<=16384:raise ValueError('count')
    guid=r.raw(16).hex();ngen=r.i()
    if not 0<=ngen<=128:raise ValueError('generations')
    gens=[{'Exports':r.i(),'Names':r.i()} for _ in range(ngen)]
    saved,compatible=r.engine(),r.engine();compression,chunks,source,additional=(r.u() for _ in range(4))
    if compression or chunks or additional:raise ValueError('compression')
    registry=r.i();bulk=r.q();world=r.i();nc=r.i()
    if not 0<=nc<=128:raise ValueError('chunks')
    ids=[r.i() for _ in range(nc)]
    preload_n,preload_o,namesref=r.i(),r.i(),r.i();toc=r.q();summary_end=r.p
    if world or toc!=-1 or not 0<=preload_n<=262144:raise ValueError('unsupported')
    r.p=names_o;names=[]
    for _ in range(names_n):
        start=r.p;s,w=r.string();lo,hi=r.num('H'),r.num('H');names.append(dict(text=s,utf16=w,hashLower=lo,hashCase=hi,offset=start,size=r.p-start))
    r.p=im_o;imports=[]
    for _ in range(im_n):
        start=r.p;cp,cn,outer,name,optional=r.fname(),r.fname(),r.i(),r.fname(),r.boolean()
        imports.append(dict(classPackage=cp,className=cn,outer=outer,objectName=name,optional=optional,offset=start,size=r.p-start))
    r.p=ex_o;exports=[]
    for _ in range(ex_n):
        start=r.p;cls,sup,template,outer=(r.i() for _ in range(4));name=r.fname();objflags=r.u();size,off=r.q(),r.q()
        forced,noclient,noserver,inherited=(r.boolean() for _ in range(4));pkgflags=r.u();notloaded,asset,public=(r.boolean() for _ in range(3));first=r.i();dc=[r.i() for _ in range(4)]
        if off<total or size<0 or off-total+size>len(data):raise ValueError('serial range')
        exports.append(dict(offset=start,size=r.p-start,serialSize=size,serialOffset=off,objectName=name,
          **{'class':cls,'super':sup,'template':template,'outer':outer},objectFlags=objflags,Forced=forced,NotForClient=noclient,NotForServer=noserver,Inherited=inherited,
          packageFlags=pkgflags,NotAlwaysLoaded=notloaded,IsAsset=asset,PublicHash=public,firstDependency=first,dependencyCounts=dc))
    for obj in imports+exports:
        for key in ('classPackage','className','objectName'):
            if key in obj and not (0<=obj[key]['index']<names_n and obj[key]['number']>=0):raise ValueError('FName')
    depends=[];r.p=depends_o
    if depends_o:
        for _ in range(ex_n):
            n=r.i()
            if not 0<=n<=262144:raise ValueError('depends')
            depends.append([r.i() for _ in range(n)])
    r.p=preload_o;preload=[r.i() for _ in range(preload_n)]
    return dict(names=names,imports=imports,exports=exports,depends=depends,preload=preload,
                headerSha256=hashlib.sha256(header).hexdigest(),exportDataSha256=hashlib.sha256(data).hexdigest(),
                summaryEnd=summary_end,registryOffset=registry,bulkDataStart=bulk,folder=folder,guid=guid,
                generations=gens,savedEngine=saved,compatibleEngine=compatible,namesReferenced=namesref,chunkIDs=ids)

def compare(go_dir):
    vectors=json.loads(Path(__file__).with_name('testdata').joinpath('vectors.json').read_text(encoding='utf-8'));rows=[]
    for v in vectors:
        ref=inspect(base64.b64decode(v['header']),base64.b64decode(v['data']))
        actual=json.loads((Path(go_dir)/(v['id']+'.json')).read_text(encoding='utf-8'))
        for key in ('names','imports','exports','depends','preload'):
            if (actual[key] or [])!=ref[key]:raise ValueError(v['id']+' '+key+' mismatch')
        for key in ('headerSha256','exportDataSha256'):
            if actual[key]!=ref[key]:raise ValueError(v['id']+' '+key+' mismatch')
        if actual['sections'][0]['size']!=ref['summaryEnd']:raise ValueError('summary end')
        for g,p in [('AssetRegistryOffset','registryOffset'),('BulkDataStart','bulkDataStart'),('Folder','folder'),('GUID','guid'),('Generations','generations'),('SavedEngine','savedEngine'),('CompatibleEngine','compatibleEngine'),('NamesReferenced','namesReferenced'),('ChunkIDs','chunkIDs')]:
            if actual['summary'][g]!=ref[p]:raise ValueError(v['id']+' summary '+g+' mismatch')
        rows.append({'fixture':v['id'],'headerSha256':ref['headerSha256'],'names':len(ref['names']),'imports':len(ref['imports']),'exports':len(ref['exports'])})
    return {'schema':'PMM_UASSET_INDEPENDENT_READ_V1','method':'Python cursor/struct parser of synthetic fixtures vs Go output',
            'fixtureCount':len(rows),'fixtures':rows,'allCompared':True,'gameAssetsRead':False,'originalExecuted':False,
            'compatibilityWithUnrealVerified':False,'limit':'Shared format assumptions; not an independent Unreal writer or actual game sample.'}

if __name__=='__main__':
    try:
        if len(sys.argv)!=2:raise ValueError('usage: verify_reference.py <Go synthetic output directory>')
        print(json.dumps(compare(sys.argv[1]),indent=2))
    except (OSError,ValueError,KeyError,struct.error) as e:
        print(str(e),file=sys.stderr);sys.exit(2)
