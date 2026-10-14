#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/layouts" "$tmp/site/public"
printf '{{content}}' > "$tmp/site/layout.html"
printf '<img src="a.svg">{{content}}' > "$tmp/site/layouts/post.html"
printf 'body{}' > "$tmp/site/style.css"
printf '<svg/>' > "$tmp/site/public/a.svg"
printf '%s\n' '# Home' '[target](old.html#custom)' '[self](#mp-home)' '![asset](a.svg#opaque)' > "$tmp/site/content/index.md"
printf '%s\n' '---' '{"slug":"old","layout":"post.html","listed":false}' '---' '# Target' > "$tmp/site/content/target.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' '[target](old.html)' > "$tmp/site/content/draft.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" backlinks "$tmp/site" old.html --json > "$tmp/before-query"
jq -e 'any(.report.incoming[];.source=="content/index.md") and any(.report.outgoing[];.source=="layouts/post.html" and .target=="a.svg")' "$tmp/before-query" >/dev/null
cp -a "$tmp/out" "$tmp/before-out"
reject() { local code=0; "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?; test "$code" = 1; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
# A changed slug breaks existing references before publication.
sed -i 's/"old"/"new"/' "$tmp/site/content/target.md"
cp -a "$tmp/site" "$tmp/invalid-before"
reject references "$tmp/site" --json
grep -Fq 'broken internal link: old.html' "$tmp/stderr"
reject build "$tmp/site" "$tmp/out"
diff -r "$tmp/before-out" "$tmp/out"
diff -r "$tmp/invalid-before" "$tmp/site"
# A configured old URL preserves the route and exposes the terminal edge.
printf '%s\n' '{"redirects":{"old.html":"new.html"}}' > "$tmp/site/site.json"
"$cli" references "$tmp/site" --json > "$tmp/redirects"
"$cli" backlinks "$tmp/site" new.html --json | jq -e 'any(.report.incoming[];.output=="old.html" and .kind=="redirect")' >/dev/null
"$cli" backlinks "$tmp/site" old.html --json | jq -e '.report.route.kind=="redirect" and any(.report.incoming[];.source=="content/index.md") and (.report.outgoing|length)==1 and .report.outgoing[0].target=="new.html"' >/dev/null
jq -e 'all(.report.references[];(.output!="old.html" or .kind=="redirect"))' "$tmp/redirects" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
# Layout selection changes evidence; unused layout links are excluded.
sed -i 's/,"layout":"post.html"//' "$tmp/site/content/target.md"
"$cli" references "$tmp/site" --json > "$tmp/default-layout"
jq -e 'all(.report.references[];.source!="layouts/post.html")' "$tmp/default-layout" >/dev/null
# Code examples, escaped links, generated archive navigation and external URLs
# are deliberately excluded; supported table/list/quote links remain evidence.
cat >> "$tmp/site/content/index.md" <<'MD'

`[code](absent.html)`
\[escaped](absent.html)

~~~
[fenced](absent.html)
~~~

> [quote](new.html)

- [list](new.html)

| Link |
| --- |
| [table](new.html) |

[external](https://example.org/new.html)
MD
"$cli" references "$tmp/site" --json > "$tmp/syntax"
jq -e 'all(.report.references[];.url!="absent.html" and (.url|startswith("https:")|not)) and any(.report.references[];.url=="new.html" and .source=="content/index.md") and all(.report.references[];.output!="articles.html")' "$tmp/syntax" >/dev/null
# Publish/unlist transitions preserve authored edges while changing draft scope.
sed -i 's/"draft":true/"draft":false,"listed":false/' "$tmp/site/content/draft.md"
"$cli" references "$tmp/site" --json | jq -e 'any(.report.references[];.source=="content/draft.md")' >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/site" "$tmp/final-source"
cp -a "$tmp/out" "$tmp/final-output"
"$cli" references "$tmp/site" --json > "$tmp/final-graph"
"$cli" backlinks "$tmp/site" a.svg --json > "$tmp/final-query"
diff -r "$tmp/final-source" "$tmp/site"
diff -r "$tmp/final-output" "$tmp/out"
echo 'Reference transition tests passed: broken slug refusal, redirect repair, selected layouts, supported syntax/exclusions, draft/unlisted transitions, no writes and clean parity.'
