#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" recovery-plan "$tmp/absent" --json > "$tmp/report"
jq -e '.schema == 1 and .command == "recovery-plan" and .include_drafts == false and .report == {action:"absent",restored:0,removed:0}' "$tmp/report" >/dev/null
test ! -e "$tmp/absent"
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" recovery-plan "$tmp/out" > "$tmp/text"
grep -q 'no files changed' "$tmp/text"
"$cli" recovery-plan "$tmp/out" --json | jq -e '.report.action == "clean"' >/dev/null
for flag in --help -h; do
  "$cli" recovery-plan "$flag" | grep -q 'Usage: moonpress recovery-plan'
done
for args in 'recovery-plan' 'recovery-plan --json' 'recovery-plan x --include-drafts' 'recovery-plan x --json --json' 'recovery-plan x extra'; do
  status=0
  "$cli" $args > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" -eq 2
  test ! -s "$tmp/stdout"
done
mkdir "$tmp/out/.moonpress-stage"
status=0
"$cli" recovery-plan "$tmp/out" --json > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
test "$status" -eq 1
test ! -s "$tmp/stdout"
grep -q 'complete regular publication journal' "$tmp/stderr"
test -d "$tmp/out/.moonpress-stage"
echo 'Recovery plan CLI tests passed.'
