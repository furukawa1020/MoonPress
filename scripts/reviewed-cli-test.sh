#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
reject() { local expected="$1" code=0; shift; "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?; test "$code" = "$expected"; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
"$cli" init "$tmp/site" >/dev/null
cp -a "$tmp/site" "$tmp/before"
"$cli" review "$tmp/site" "$tmp/out" --json > "$tmp/review"
"$cli" review "$tmp/site" "$tmp/out" --json > "$tmp/repeat"
cmp "$tmp/review" "$tmp/repeat"
diff -r "$tmp/site" "$tmp/before"
test ! -e "$tmp/out"
jq -e '.schema==1 and .command=="review" and .report.schema==1 and (.report.review_id|test("^[a-f0-9]{64}$"))' "$tmp/review" >/dev/null
id="$(jq -r '.report.review_id' "$tmp/review")"
"$cli" review "$tmp/site" "$tmp/out" | grep -Fq "Review ID: $id"
"$cli" --help | grep -Fq 'build-reviewed'
for command in review build-reviewed; do
  "$cli" "$command" --help | grep -Fq "Usage: moonpress $command"
  reject 2 "$command"
  reject 2 "$command" "$tmp/site"
done
reject 2 review "$tmp/site" "$tmp/out" --json --json
reject 2 review "$tmp/site" "$tmp/out" --include-drafts --include-drafts
reject 2 build-reviewed "$tmp/site" "$tmp/out"
reject 2 build-reviewed "$tmp/site" "$tmp/out" "$id" extra
reject 2 build-reviewed "$tmp/site" "$tmp/out" "$id" --json --json
reject 2 build-reviewed "$tmp/site" "$tmp/out" "$id" --include-drafts --include-drafts
reject 1 build-reviewed "$tmp/site" "$tmp/out" invalid
reject 1 build-reviewed "$tmp/site" "$tmp/other" "$id"
reject 1 build-reviewed "$tmp/site/" "$tmp/out" "$id"
reject 1 build-reviewed "$tmp/site" "$tmp/out/" "$id"
reject 1 build-reviewed "$tmp/site" "$tmp/out" "$id" --include-drafts
test ! -e "$tmp/other"
test ! -e "$tmp/out"
printf '\nChanged after review\n' >> "$tmp/site/content/index.md"
reject 1 build-reviewed "$tmp/site" "$tmp/out" "$id" --json
grep -Fq 'Reviewed build plan changed' "$tmp/stderr"
test ! -e "$tmp/out"
"$cli" review "$tmp/site" "$tmp/out" --json > "$tmp/fresh"
id="$(jq -r '.report.review_id' "$tmp/fresh")"
"$cli" build-reviewed "$tmp/site" "$tmp/out" "$id" --json > "$tmp/build"
jq -S '.report.plan.summary' "$tmp/fresh" > "$tmp/expected"
jq -S '.report' "$tmp/build" > "$tmp/actual"
cmp "$tmp/expected" "$tmp/actual"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
reject 1 build-reviewed "$tmp/site" "$tmp/out" "$id"
diff -r "$tmp/out" "$tmp/clean"
"$cli" review "$tmp/site" "$tmp/preview" --include-drafts --json > "$tmp/drafts"
id="$(jq -r '.report.review_id' "$tmp/drafts")"
"$cli" build-reviewed "$tmp/site" "$tmp/preview" "$id" --json --include-drafts | jq -e '.include_drafts and .command=="build-reviewed"' >/dev/null
echo 'Reviewed CLI tests passed: deterministic read-only review, grammar, path/mode binding, stale rejection, exact report and clean parity.'
