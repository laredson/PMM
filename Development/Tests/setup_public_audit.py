"""Audit the tracked release tree without exposing file contents."""
import hashlib,json,pathlib,re,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[2]
def git(*args):return subprocess.check_output(['git','-c','safe.directory='+ROOT.as_posix(),*args],cwd=ROOT)
files=git('ls-files','-z').decode().split('\0')
failures=[];count=0;total=0
for name in filter(None,files):
    p=ROOT/name
    if not p.is_file():continue
    count+=1;total+=p.stat().st_size
    parts=pathlib.PurePosixPath(name).parts
    if any(s in parts for s in ('Workspace','.codex','TestResults','Releases','Offline')) or p.suffix.lower() in ('.pak','.ucas','.utoc','.uasset','.uexp','.ubulk','.pfx','.p12','.key','.tar','.xz'):
        failures.append((name,'private/runtime/game payload'))
    if p.stat().st_size>=100*1024*1024:failures.append((name,'over regular Git file limit'))
    if p.suffix.lower() in ('.ps1','.py','.cs','.json','.md','.yml','.yaml','.toml','.txt','.config'):
        s=p.read_text(encoding='utf-8-sig',errors='replace')
        if re.search(r'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|sk-proj-[A-Za-z0-9_-]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',s):
            failures.append((name,'credential-like payload'))
# Every shipped checksum entry must be tracked, portable and correct.
tracked=set(files);app=ROOT/'PMM';entries=0
for line in (app/'Resources/Metadata/SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():
    h,name=line.split('  ',1)
    if 'PMM/'+name not in tracked:failures.append((name,'packaged but not tracked'))
    if hashlib.sha256((app/name).read_bytes()).hexdigest()!=h:failures.append((name,'checksum mismatch'))
    entries+=1
for lang in ('es','en'):
    p=app/f'Documentation/UNREAL_SETUP.{lang}.md'
    for url in re.findall(r'\]\(([^)]+)\)',p.read_text(encoding='utf-8')):
        if '://' not in url and not (p.parent/url.split('#')[0]).exists():failures.append((p.name,'broken relative link'))
result={'trackedFiles':count,'trackedBytes':total,'packageChecksums':entries,'failures':failures}
print(json.dumps(result,indent=2))
if failures:sys.exit(1)
