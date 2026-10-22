#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" history "$tmp/site" index.md --json | jq -e '.report|length==0' >/dev/null
"$cli" history-enable "$tmp/site" --json | jq -e '.report == true' >/dev/null
"$cli" history-enable "$tmp/site" --json | jq -e '.report == false' >/dev/null
version="$("$cli" read "$tmp/site" index.md --json | jq -r '.report.digest')"
id="$("$cli" checkpoint "$tmp/site" index.md "$version" --json | jq -r '.report.id')"
"$cli" revision "$tmp/site" "$id" --json | jq -e '.report.content | contains("Welcome")' >/dev/null
printf '# Changed\n' > "$tmp/replacement"
"$cli" save "$tmp/site" index.md "$version" "$tmp/replacement" >/dev/null
current="$("$cli" read "$tmp/site" index.md --json | jq -r '.report.digest')"
if "$cli" restore-revision "$tmp/site" index.md "$version" "$id" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
test ! -s "$tmp/stdout"
"$cli" restore-revision "$tmp/site" index.md "$current" "$id" --json | jq -e '.report.changed' >/dev/null
"$cli" read "$tmp/site" index.md --json | jq -e '.report.content | contains("Welcome")' >/dev/null
for cmd in history-enable history checkpoint revision restore-revision; do "$cli" "$cmd" --help | grep -Fq 'No --include-drafts'; done
if "$cli" history "$tmp/site" index.md --include-drafts >/dev/null 2>&1; then exit 1; fi
echo 'History CLI passed: opt-in, checkpoints, exact reads, guarded restoration and strict arguments.'
