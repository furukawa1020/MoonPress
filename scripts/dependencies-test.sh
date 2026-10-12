#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" new "$tmp/site" draft 'Private draft' >/dev/null
mkdir "$tmp/site/public"
printf '\000\377asset' > "$tmp/site/public/a.pdf"
printf '%s\n' '{"base_url":"https://example.org/project/","tag_index":true,"page_size":1,"tag_page_size":1,"feed":{"title":"Feed","description":"Summary"}}' > "$tmp/site/site.json"
cp -a "$tmp/site" "$tmp/before"
"$cli" deps "$tmp/site" --json > "$tmp/graph"
"$cli" deps "$tmp/site" --json > "$tmp/repeat"
cmp "$tmp/graph" "$tmp/repeat"
jq -e '.schema==1 and .command=="deps" and (.include_drafts|not) and (.report.include_drafts|not) and ([.report.artifacts[].name]|index("draft.html")==null)' "$tmp/graph" >/dev/null
jq -e '.report.artifacts[]|select(.name=="a.pdf")|any(.dependencies[];.name=="public/a.pdf")' "$tmp/graph" >/dev/null
jq -e '.report.artifacts[]|select(.name=="guide.html")|any(.dependencies[];.name=="layouts/post.html")' "$tmp/graph" >/dev/null
jq -e '[.report.artifacts[].name]|index("rss.xml")!=null and index("sitemap.xml")!=null' "$tmp/graph" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
jq -S '.report.artifacts|sort_by(.name)|map(.dependencies|=sort_by(.name))' "$tmp/graph" > "$tmp/expected"
jq -S '.artifacts|sort_by(.name)|map(.dependencies|=sort_by(.name))' "$tmp/out/.moonpress.json" > "$tmp/actual"
cmp "$tmp/expected" "$tmp/actual"
cp -a "$tmp/out" "$tmp/out-before"
"$cli" deps "$tmp/site" --include-drafts --json > "$tmp/drafts"
jq -e '.include_drafts and .report.include_drafts and any(.report.artifacts[];.name=="draft.html")' "$tmp/drafts" >/dev/null
"$cli" build "$tmp/site" "$tmp/draft-out" --include-drafts >/dev/null
jq -S '.report.artifacts|sort_by(.name)|map(.dependencies|=sort_by(.name))' "$tmp/drafts" > "$tmp/expected"
jq -S '.artifacts|sort_by(.name)|map(.dependencies|=sort_by(.name))' "$tmp/draft-out/.moonpress.json" > "$tmp/actual"
cmp "$tmp/expected" "$tmp/actual"
"$cli" deps "$tmp/site" | grep -Fq 'direct edges; no files written'
diff -r "$tmp/site" "$tmp/before"
diff -r "$tmp/out" "$tmp/out-before"
reject() { local code="$1" status=0; shift; "$@" > "$tmp/stdout" 2> "$tmp/error" || status=$?; test "$status" = "$code"; test ! -s "$tmp/stdout"; test -s "$tmp/error"; }
reject 2 "$cli" deps "$tmp/site" --json --json
reject 2 "$cli" deps "$tmp/site" --include-drafts --include-drafts
reject 2 "$cli" deps "$tmp/site" extra
reject 2 "$cli" deps "$tmp/site" --bad
"$cli" deps --help | grep -Fq 'private draft nodes'
printf '%s\n' '[broken](missing.html)' > "$tmp/site/content/bad.md"
cp -a "$tmp/site" "$tmp/invalid"
reject 1 "$cli" deps "$tmp/site" --json
diff -r "$tmp/site" "$tmp/invalid"
diff -r "$tmp/out" "$tmp/out-before"
echo 'Dependency tests passed: fresh manifest/digest parity, assets/layouts/config/collections, drafts, determinism, validation and no mutation.'
