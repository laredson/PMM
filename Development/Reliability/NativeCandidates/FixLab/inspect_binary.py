#!/usr/bin/env python3
"""Build a LOCAL metadata reader; inspect, never execute, the pinned FixLab EXE."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

PIN = '8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe'
GO = 'go1.23.2'


def digest(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', required=True, type=Path)
    args = ap.parse_args()
    here = Path(__file__).resolve().parent
    root, out = here.parents[3], args.out.resolve()
    try:
        if out.exists() or out == root or root in out.parents:
            raise ValueError('Output must be NEW and outside the repository')
        original = root/'PMM/Engine/PMMFixLab.exe'
        if original.is_symlink() or digest(original) != PIN:
            raise ValueError('Original FixLab pin mismatch')
        src = here/'tools/fixlab_meta.go'
        if src.is_symlink():
            raise ValueError('Reader source symlink rejected')
        source_sha = digest(src)
        go = shutil.which('go')
        if not go:
            raise ValueError('Go 1.23.2 is required; not downloaded by this tool')
        env = dict(os.environ, GOTOOLCHAIN='local', GOPROXY='off', GOSUMDB='off',
                   GOENV='off', GOWORK='off', GOFLAGS='', GOEXPERIMENT='', CGO_ENABLED='0')
        log = []

        def run(argv, cwd):
            p = subprocess.run([str(x) for x in argv], cwd=cwd, env=env,
                               capture_output=True, text=True, encoding='utf-8',
                               errors='strict', timeout=60, check=False)
            def clean(s):
                return s.replace(str(root), '<REPO>').replace(str(out), '<OUT>').replace(go, 'go')
            log.append({'command': [clean(str(x)) for x in argv], 'exitCode': p.returncode,
                        'stderr': clean(p.stderr)})
            if p.returncode:
                raise ValueError('Reader command failed: ' + clean(p.stderr))
            return p.stdout

        if run([go, 'version'], here).split()[2] != GO:
            raise ValueError('Expected Go 1.23.2')
        host_os, host_arch = run([go, 'env', 'GOHOSTOS', 'GOHOSTARCH'], here).split()
        env.update(GOOS=host_os, GOARCH=host_arch)
        out.mkdir(parents=True, exist_ok=False)
        target_source = out/'fixlab_meta.go'
        shutil.copyfile(src, target_source)
        reader = out/('fixlab-meta.exe' if host_os == 'windows' else 'fixlab-meta')
        run([go, 'build', '-trimpath', '-buildvcs=false', '-o', reader, target_source], out)
        report = json.loads(run([reader, original], out))
        if digest(original) != PIN or digest(src) != source_sha or report['sha256'] != PIN:
            raise ValueError('Input changed during inspection')
        (out/'original-go.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
        (out/'inspection-recipe.json').write_text(json.dumps({
            'schema': 'PMM_FIXLAB_INSPECTION_RECIPE_V1', 'goVersion': GO,
            'readerSourceSha256': source_sha, 'readerSha256': digest(reader),
            'originalSha256': PIN, 'commands': log,
            'originalExecuted': False, 'engineBuilt': False, 'sourceRecovered': False,
            'note': 'Only our metadata reader was compiled/executed. No FixLab candidate exists yet.'
        }, indent=2)+'\n', encoding='utf-8')
        (out/'COMPLETE.txt').write_text('METADATA INSPECTION ONLY. No FixLab build or runtime acceptance.\n')
        print(json.dumps({'status': 'METADATA_READ', 'sourceRecovered': False,
                          'functionCount': len(report['applicationFunctions'])}, indent=2))
        return 0
    except (OSError, ValueError, KeyError, IndexError, UnicodeError, subprocess.SubprocessError) as exc:
        print('Inspection failed: '+str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
