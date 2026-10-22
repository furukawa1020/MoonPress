"""Keep raw evidence in decoded job logs without Node artifact actions."""
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import sys

native = json.loads(Path(sys.argv[1]).read_text())
http = json.loads(Path(sys.argv[2]).read_text())
record = {'schema':1,'native':native,'http':http,
          'ci':{key:os.environ.get(key) for key in ('GITHUB_REPOSITORY','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_SHA','RUNNER_OS','RUNNER_ARCH')}}
raw = (json.dumps(record,sort_keys=True,separators=(',',':'))+'\n').encode()
print('MOONPRESS_WORDPRESS_RAW_SHA256='+hashlib.sha256(raw).hexdigest())
print('MOONPRESS_WORDPRESS_RAW_GZIP_BASE64='+base64.b64encode(gzip.compress(raw,mtime=0)).decode())
lines=['| Articles | Variant | Median full response ms | p95 ms |','| --- | --- | --- | --- |']
for row in http['summary']:
    lines.append(f"| {row['count']} | {row['variant']} | {row['total_ms']['median']:.4f} | {row['total_ms']['p95']:.4f} |")
text='\n'.join(lines)+'\n\nWarm serial loopback requests using PHP development servers. Static WordPress snapshots are the cache control. Not production throughput, whole-product parity, or language-only speed. Raw records and hashes are in this job log.\n'
print(text)
if os.environ.get('GITHUB_STEP_SUMMARY'):
    with open(os.environ['GITHUB_STEP_SUMMARY'],'a') as file: file.write(text)
