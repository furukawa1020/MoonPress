#!/usr/bin/env python3
"""Published report must regenerate; corrupt evidence must not overwrite output."""
import copy
import gzip
import json
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path.cwd()
raw = root / 'benchmarks/wordpress/results/2026-10-22-capacity.json.gz'
expected = root / 'docs/wordpress-capacity-2026-10-22.md'
script = root / 'benchmarks/wordpress/capacity_report.py'
evidence = json.loads(gzip.decompress(raw.read_bytes()))
with tempfile.TemporaryDirectory(prefix='moonpress-capacity-report-') as temporary:
    temporary = pathlib.Path(temporary)
    output = temporary / 'report.md'
    subprocess.run([sys.executable, script, raw, output], check=True)
    assert output.read_bytes() == expected.read_bytes()
    def wrong_latency(data): data['http']['capacity']['groups'][0]['samples'][0]['ms'] = float('nan')
    def wrong_summary(data): data['http']['capacity']['groups'][0]['valid_rps'] += 1
    def missing_group(data): data['http']['capacity']['groups'].pop()
    def repeated_request(data): data['http']['capacity']['groups'][0]['samples'][0]['request'] = 1
    def wrong_runtime(data): data['http']['capacity']['php_runtime']['xdebug_active_modes'] = ['develop']
    def wrong_identity(data): data['http']['capacity']['groups'][0]['samples'][0]['sha256'] = '0' * 64
    for mutation in (wrong_latency,wrong_summary,missing_group,repeated_request,wrong_runtime,wrong_identity):
        data = copy.deepcopy(evidence)
        mutation(data)
        invalid = temporary / 'invalid.json.gz'
        invalid.write_bytes(gzip.compress(json.dumps(data).encode(), mtime=0))
        output.write_bytes(b'keep existing output')
        result = subprocess.run([sys.executable, script, invalid, output], capture_output=True)
        assert result.returncode != 0, mutation.__name__
        assert output.read_bytes() == b'keep existing output'
print('Capacity report passed: exact regeneration and corrupt latency, summary, coverage, request, runtime and identity refusal.')
