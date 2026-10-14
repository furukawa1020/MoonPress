#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '<link href="style.css"><a href="index.html">Home</a>{{content}}' > "$tmp/site/layout.html"
printf 'body{}' > "$tmp/site/style.css"
printf 'asset' > "$tmp/site/public/a.svg"
printf '%s\n' '{"base_url":"https://example.org/demo/","redirects":{"old.html":"月.html"}}' > "$tmp/site/site.json"
printf '%s\n' '# Home' '[target](/demo/%E6%9C%88.html?x=1#mp-target)' '[target](/demo/%E6%9C%88.html?x=1#mp-target)' '![image](a.svg)' '[self](#mp-home)' '`[code](absent.html)`' '[external](https://example.org)' > "$tmp/site/content/index.md"
printf '%s\n' '---' '{"slug":"月","listed":false}' '---' '# Target' > "$tmp/site/content/target.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' '[target](月.html)' > "$tmp/site/content/draft.md"
cp -a "$tmp/site" "$tmp/before"
"$cli" references "$tmp/site" --json > "$tmp/graph"
"$cli" references "$tmp/site" --json > "$tmp/repeat"
cmp "$tmp/graph" "$tmp/repeat"
jq -e '.schema==1 and .command=="references" and (.include_drafts|not) and .report.pages==2 and all(.report.references[];.url!="absent.html" and .source!="content/draft.md")' "$tmp/graph" >/dev/null
"$cli" backlinks "$tmp/site" 月.html --json > "$tmp/query"
jq -e '.command=="backlinks" and .report.route.source=="content/target.md" and (.report.incoming|length)==2 and any(.report.incoming[];.kind=="redirect") and any(.report.incoming[];.fragment=="mp-target")' "$tmp/query" >/dev/null
jq -S '[.report.references[]|select(.target=="月.html")]' "$tmp/graph" > "$tmp/expected"
jq -S '.report.incoming' "$tmp/query" > "$tmp/actual"
cmp "$tmp/expected" "$tmp/actual"
"$cli" backlinks "$tmp/site" a.svg | grep -Fq 'markdown-image'
"$cli" references "$tmp/site" | grep -Fq 'no files written'
"$cli" backlinks "$tmp/site" .nojekyll --json | jq -e '(.report.incoming|length)==0' >/dev/null
"$cli" backlinks "$tmp/site" 月.html --json --include-drafts | jq -e '.include_drafts and any(.report.incoming[];.source=="content/draft.md")' >/dev/null
"$cli" references "$tmp/site" --include-drafts --json | jq -e '.report.pages==3' >/dev/null
diff -r "$tmp/before" "$tmp/site"
test ! -e "$tmp/site/.moonpress-build"
reject() { local expected="$1" code=0; shift; "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?; test "$code" = "$expected"; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
for command in references backlinks; do
  "$cli" "$command" --help | grep -Fq "Usage: moonpress $command"
  reject 2 "$command"
  grep -Fq "Usage: moonpress $command" "$tmp/stderr"
done
reject 2 references "$tmp/site" extra
reject 2 references "$tmp/site" --json --json
reject 2 references "$tmp/site" --include-drafts --include-drafts
reject 2 backlinks "$tmp/site"
reject 2 backlinks "$tmp/site" 月.html --json --json
reject 2 backlinks "$tmp/site" 月.html --include-drafts --include-drafts
reject 1 backlinks "$tmp/site" '%E6%9C%88.html'
reject 1 backlinks "$tmp/site" missing.html
grep -Fq 'Unknown output filename' "$tmp/stderr"
diff -r "$tmp/before" "$tmp/site"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
jq -S '[.report.routes[].name]|sort' "$tmp/graph" > "$tmp/routes"
jq -S '[.artifacts[].name]|sort' "$tmp/out/.moonpress.json" > "$tmp/built"
cmp "$tmp/routes" "$tmp/built"
printf '\n[broken](missing.html)\n' >> "$tmp/site/content/index.md"
reject 1 references "$tmp/site" --json
grep -Fq 'broken internal link' "$tmp/stderr"
reject 1 backlinks "$tmp/site" 月.html --json
echo 'Reference CLI tests passed: graph/query parity, Unicode/slug/fragment evidence, assets, redirects, scopes, strict grammar, read-only behavior and build validation.'
