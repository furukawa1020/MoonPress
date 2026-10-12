#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" new "$tmp/site" private 'Private draft' >/dev/null
mkdir "$tmp/site/public"
printf bytes > "$tmp/site/public/a.pdf"
printf '%s\n' '{"base_url":"https://example.org/project/","tag_index":true}' > "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/site" "$tmp/before"
cp -a "$tmp/out" "$tmp/out-before"
query() { "$cli" impact "$tmp/site" "$1" --json > "$tmp/report"; }
query content/guide.md
jq -e '.schema==1 and .command=="impact" and .report.requested==["content/guide.md"] and .report.unknown==[] and ([.report.outputs[].name]==["guide.html"])' "$tmp/report" >/dev/null
query public/a.pdf
jq -e '.report.unknown==[] and ([.report.outputs[].name]==["a.pdf"]) and .report.outputs[0].dependencies==["public/a.pdf"]' "$tmp/report" >/dev/null
query layouts/post.html
jq -e 'any(.report.outputs[];.name=="guide.html") and .report.unknown==[]' "$tmp/report" >/dev/null
query site.json/base_url
jq -e 'any(.report.outputs[];.name=="sitemap.xml") and .report.unknown==[]' "$tmp/report" >/dev/null
query content/private.md
jq -e '.report.unknown==["content/private.md"] and .report.outputs==[] and (.report.include_drafts|not)' "$tmp/report" >/dev/null
"$cli" impact "$tmp/site" content/private.md --json --include-drafts > "$tmp/report"
jq -e '.include_drafts and .report.include_drafts and .report.unknown==[] and any(.report.outputs[];.name=="private.html")' "$tmp/report" >/dev/null
query not-a-key
jq -e '.report.unknown==["not-a-key"] and .report.outputs==[]' "$tmp/report" >/dev/null
"$cli" impact "$tmp/site" not-a-key | grep -Fq 'UNKNOWN "not-a-key"'
query compiler
cp "$tmp/report" "$tmp/repeat"
query compiler
cmp "$tmp/report" "$tmp/repeat"
"$cli" deps "$tmp/site" --json > "$tmp/graph"
jq -S '[.report.artifacts[]|select(any(.dependencies[];.name=="compiler"))|{name,digest,dependencies:["compiler"]}]' "$tmp/graph" > "$tmp/expected"
jq -S '.report.outputs' "$tmp/report" > "$tmp/actual"
cmp "$tmp/expected" "$tmp/actual"
diff -r "$tmp/site" "$tmp/before"
diff -r "$tmp/out" "$tmp/out-before"
reject() { local code="$1" status=0; shift; "$@" > "$tmp/stdout" 2> "$tmp/error" || status=$?; test "$status" = "$code"; test ! -s "$tmp/stdout"; test -s "$tmp/error"; }
reject 1 "$cli" impact "$tmp/site" '' --json
reject 2 "$cli" impact "$tmp/site"
reject 2 "$cli" impact "$tmp/site" compiler --json --json
reject 2 "$cli" impact "$tmp/site" compiler --include-drafts --include-drafts
reject 2 "$cli" impact "$tmp/site" compiler extra
reject 2 "$cli" impact "$tmp/site" compiler --bad
"$cli" impact --help | grep -Fq 'private draft nodes'
printf '%s\n' '[broken](absent.html)' > "$tmp/site/content/bad.md"
cp -a "$tmp/site" "$tmp/invalid"
reject 1 "$cli" impact "$tmp/site" compiler --json
diff -r "$tmp/site" "$tmp/invalid"
diff -r "$tmp/out" "$tmp/out-before"
echo 'Impact tests passed: exact article/layout/asset/config keys, drafts, unknowns, graph parity, determinism, arguments and no mutation.'
