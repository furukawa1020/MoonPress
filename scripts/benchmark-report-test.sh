#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import copy,gzip,json,sys,tempfile
from pathlib import Path
sys.path.insert(0,'benchmarks/wordpress')
from report import report
raw=Path('benchmarks/wordpress/results/2026-10-22.json.gz')
data=json.loads(gzip.decompress(raw.read_bytes()))
with tempfile.TemporaryDirectory() as directory:
    directory=Path(directory)
    actual=directory/'report.md'
    report(raw,actual,'2026-10-22')
    assert actual.read_bytes()==Path('docs/wordpress-benchmark-2026-10-22.md').read_bytes()
    for case in ('timing','rss','work','repeat'):
        bad=copy.deepcopy(data)
        if case=='timing': bad['native']['summary'][0]['elapsed_ms']['median']=-999
        if case=='rss': bad['native']['summary'][0]['peak_rss_kib']['p95']=999999999
        if case=='work': bad['native']['samples'][1]['written']=99
        if case=='repeat': bad['native']['samples'][0]['repeat']=99
        archive=directory/(case+'.json.gz')
        archive.write_bytes(gzip.compress(json.dumps(bad).encode(),mtime=0))
        output=directory/(case+'.md')
        try: report(archive,output,'2026-10-22')
        except ValueError: pass
        else: raise AssertionError('Corrupted evidence accepted: '+case)
        assert not output.exists()
print('Benchmark report passed: exact regeneration and refusal of corrupted native timing, RSS, work and repeat records.')
PY
