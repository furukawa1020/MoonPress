#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/before"
"$cli" audit "$tmp/out" --json > "$tmp/report"
jq -e '.schema==1 and .command=="audit" and .report.healthy and ([.report.findings[].status]|all(.=="intact"))' "$tmp/report" >/dev/null
diff -r "$tmp/out" "$tmp/before"
# Inspect several independent divergences in one complete report.
printf edited > "$tmp/out/guide.html"
rm "$tmp/out/index.html" "$tmp/out/style.css"
mkfifo "$tmp/out/style.css"
ln -s guide.html "$tmp/out/foreign-link"
printf foreign > "$tmp/out/foreign.txt"
mkdir "$tmp/out/.moonpress-stage"
cp -a "$tmp/out" "$tmp/diverged"
status=0
timeout 5 "$cli" audit "$tmp/out" --json > "$tmp/report" 2> "$tmp/error" || status=$?
test "$status" = 1; test ! -s "$tmp/error"
jq -e '(.report.healthy|not) and ([.report.findings[]|select(.path=="guide.html")][0].status=="edited") and ([.report.findings[]|select(.path=="index.html")][0].status=="missing") and ([.report.findings[]|select(.path=="style.css")][0].status=="unsafe") and ([.report.findings[]|select(.path==".moonpress-stage")][0].status=="staging") and ([.report.findings[]|select(.path=="foreign-link")][0].status=="foreign")' "$tmp/report" >/dev/null
diff -r --exclude=style.css "$tmp/out" "$tmp/diverged"
test -p "$tmp/out/style.css"
rm -rf "$tmp/out"
cp -a "$tmp/before" "$tmp/out"
rm "$tmp/out/style.css"; ln -s guide.html "$tmp/out/style.css"
status=0
"$cli" audit "$tmp/out" --json > "$tmp/report" || status=$?
test "$status" = 1
jq -e '.report.findings[]|select(.path=="style.css")|.status=="unsafe" and .actual==null' "$tmp/report" >/dev/null
rm "$tmp/out/style.css"; cp "$tmp/before/style.css" "$tmp/out/style.css"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
status=0
env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_READ=$tmp/out/guide.html" "$cli" audit "$tmp/out" --json > "$tmp/report" || status=$?
test "$status" = 1
jq -e '.report.findings[]|select(.path=="guide.html")|.status=="unreadable" and .actual==null' "$tmp/report" >/dev/null
diff -r "$tmp/before" "$tmp/out"
reject() { local code="$1" status=0; shift; "$@" > "$tmp/stdout" 2> "$tmp/error" || status=$?; test "$status" = "$code"; test ! -s "$tmp/stdout"; test -s "$tmp/error"; }
printf '{broken' > "$tmp/out/.moonpress.json"
reject 1 "$cli" audit "$tmp/out" --json
cp "$tmp/before/.moonpress.json" "$tmp/out/.moonpress.json"
rm "$tmp/out/.moonpress.json"; ln -s "$tmp/before/.moonpress.json" "$tmp/out/.moonpress.json"
reject 1 "$cli" audit "$tmp/out" --json
rm "$tmp/out/.moonpress.json"; cp "$tmp/before/.moonpress.json" "$tmp/out/.moonpress.json"
ln -s "$tmp/out" "$tmp/alias"
reject 1 "$cli" audit "$tmp/alias" --json
reject 1 "$cli" audit "$tmp/absent" --json
reject 2 "$cli" audit "$tmp/out" --include-drafts
reject 2 "$cli" audit "$tmp/out" --json --json
reject 2 "$cli" audit "$tmp/out" extra
"$cli" audit --help | grep -Fq 'complete report on stdout'
"$cli" audit "$tmp/out" | grep -Fq 'Healthy: true'
diff -r "$tmp/out" "$tmp/before"
echo 'Output audit tests passed: complete findings, integrity, unsafe paths, read faults, strict manifests, exit codes and no mutation.'
