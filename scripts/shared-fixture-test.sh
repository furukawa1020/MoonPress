#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
python3 benchmarks/wordpress/fixture.py "$tmp/a" 10 > "$tmp/a-manifest"
python3 benchmarks/wordpress/fixture.py "$tmp/b" 10 > "$tmp/b-manifest"
diff -r "$tmp/a" "$tmp/b"
_build/native/release/build/cmd/main/main.exe build "$tmp/a/site" "$tmp/out" >/dev/null
python3 - "$tmp/a/dataset.json" "$tmp/out" <<'PY'
import importlib.util,json,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture','benchmarks/wordpress/fixture.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
for article in json.loads(Path(sys.argv[1]).read_text())['articles']:
    module.verify_html((Path(sys.argv[2])/(article['slug']+'.html')).read_bytes(),article)
try: module.verify_html(b'<main><h1>Wrong</h1></main>',article)
except ValueError: pass
else: raise AssertionError('Mismatch must fail')
PY
echo 'Shared fixture passed: deterministic corpus hashes and exact rendered article text, mismatch refusal.'
