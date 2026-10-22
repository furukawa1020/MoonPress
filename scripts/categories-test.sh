#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
version="$("$cli" read "$tmp/site" index.md --json | jq -r '.report.digest')"
"$cli" post-categories "$tmp/site" index.md "$version" $' Science\n月\nScience\n' --json | jq -e '.report.changed' >/dev/null
python3 - "$tmp/site/content/index.md" <<'PY'
import json,sys
from pathlib import Path
metadata=json.loads(Path(sys.argv[1]).read_text().split('---\n')[1])
assert set(metadata['categories'])=={'Science','月'}
PY
current="$("$cli" read "$tmp/site" index.md --json | jq -r '.report.digest')"
"$cli" post-categories "$tmp/site" index.md "$current" $'月\nScience' --json | jq -e '.report.changed==false' >/dev/null
if "$cli" post-categories "$tmp/site" index.md "$version" other > "$tmp/stale" 2>&1; then exit 1; fi
"$cli" post-categories "$tmp/site" index.md "$current" '' >/dev/null
grep -Fq 'Welcome' "$tmp/site/content/index.md"
echo 'Categories passed: distinct metadata, normalized native edits, no-op stability, stale refusal and clearing.'
