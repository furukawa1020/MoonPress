#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" trash-list "$tmp/site" --json | jq -e '.report|length==0' >/dev/null
cp "$tmp/site/content/index.md" "$tmp/original"
version="$("$cli" read "$tmp/site" index.md --json | jq -r '.report.digest')"
"$cli" trash-post "$tmp/site" index.md "$version" --json > "$tmp/record"
id="$(jq -r '.report.id' "$tmp/record")"
record_digest="$(jq -r '.report.record_digest' "$tmp/record")"
test ! -e "$tmp/site/content/index.md"
"$cli" trash-read "$tmp/site" "$id" --json | jq -e '.report.content|contains("Welcome")' >/dev/null
"$cli" trash-restore "$tmp/site" "$id" "$record_digest" --json | jq -e '.report.changed' >/dev/null
cmp "$tmp/original" "$tmp/site/content/index.md"
"$cli" trash-list "$tmp/site" --json | jq -e '.report|length==0' >/dev/null
for cmd in trash-post trash-list trash-read trash-restore; do "$cli" "$cmd" --help | grep -Fq 'No --include-drafts'; done
if "$cli" trash-post "$tmp/site" index.md "$version" --include-drafts >/dev/null 2>&1; then exit 1; fi
echo 'Trash CLI passed: private exact round trip, review identifiers and strict grammar.'
