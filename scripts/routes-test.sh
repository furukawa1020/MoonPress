#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf 'asset' > "$tmp/site/public/a.pdf"
printf '%s\n' '---' '{"slug":"home","tags":["core"]}' '---' '# Home' > "$tmp/site/content/index.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' > "$tmp/site/content/draft.md"
printf '%s\n' '{"base_url":"https://example.org/project/","feed":{"title":"Feed","description":"Summary"},"tag_index":true,"redirects":{"old.html":"home.html","older.html":"old.html"}}' > "$tmp/site/site.json"
cp -a "$tmp/site" "$tmp/source-before"
"$cli" routes "$tmp/site" --json > "$tmp/report"
"$cli" routes "$tmp/site" --json > "$tmp/repeat"
cmp "$tmp/report" "$tmp/repeat"
jq -e '.schema==1 and .command=="routes" and (.include_drafts|not) and .report.pages==1 and all(.report.routes[];.name!="draft.html" and .name!=".moonpress.json")' "$tmp/report" >/dev/null
jq -e '.report.routes[]|select(.name=="home.html")|.kind=="page" and .source=="content/index.md" and .target==null' "$tmp/report" >/dev/null
jq -e '.report.routes[]|select(.name=="older.html")|.kind=="redirect" and .target=="home.html"' "$tmp/report" >/dev/null
jq -e '.report.routes[]|select(.name=="a.pdf")|.kind=="asset" and .source=="public/a.pdf"' "$tmp/report" >/dev/null
for pair in 'articles.html archive' 'tags.html archive' 'rss.xml feed' 'sitemap.xml sitemap' '.nojekyll marker'; do
  read -r name kind <<< "$pair"
  jq -e --arg name "$name" --arg kind "$kind" '.report.routes[]|select(.name==$name)|.kind==$kind' "$tmp/report" >/dev/null
done
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
jq -S '[.report.routes[].name]|sort' "$tmp/report" > "$tmp/expected"
jq -S '[.artifacts[].name]|sort' "$tmp/out/.moonpress.json" > "$tmp/actual"
cmp "$tmp/expected" "$tmp/actual"
cp -a "$tmp/out" "$tmp/output-before"
"$cli" routes "$tmp/site" --include-drafts --json > "$tmp/draft-report"
jq -e '.include_drafts and .report.include_drafts and any(.report.routes[];.name=="draft.html" and .kind=="page")' "$tmp/draft-report" >/dev/null
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
jq -S '[.report.routes[].name]|sort' "$tmp/draft-report" > "$tmp/expected"
jq -S '[.artifacts[].name]|sort' "$tmp/preview/.moonpress.json" > "$tmp/actual"
cmp "$tmp/expected" "$tmp/actual"
"$cli" routes "$tmp/site" | grep -Fq 'outputs; no files written'
diff -r "$tmp/site" "$tmp/source-before"
diff -r "$tmp/out" "$tmp/output-before"
reject() { local code="$1" status=0; shift; "$@" > "$tmp/stdout" 2> "$tmp/error" || status=$?; test "$status" = "$code"; test ! -s "$tmp/stdout"; test -s "$tmp/error"; }
reject 2 "$cli" routes "$tmp/site" --json --json
reject 2 "$cli" routes "$tmp/site" --include-drafts --include-drafts
reject 2 "$cli" routes "$tmp/site" extra
reject 2 "$cli" routes "$tmp/site" --bad
"$cli" routes --help | grep -Fq 'terminal redirect target'
printf '\n[Missing](missing.html)\n' >> "$tmp/site/content/index.md"
cp -a "$tmp/site" "$tmp/invalid-source"
reject 1 "$cli" routes "$tmp/site" --json
diff -r "$tmp/site" "$tmp/invalid-source"
diff -r "$tmp/out" "$tmp/output-before"
echo 'Route tests passed: manifest parity, source/slug/kind/terminal targets, drafts, deterministic reports, strict grammar and no writes.'
