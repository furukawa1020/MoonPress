#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '# Home\n[Old](old.html)\n' > "$tmp/site/content/index.md"
printf '# New\n' > "$tmp/site/content/new.md"
printf '# Other\n' > "$tmp/site/content/other.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' > "$tmp/site/content/draft.md"
config='{"base_url":"https://example.org/project/","redirects":{"old.html":"new.html","older.html":"old.html"}}'
printf '%s\n' "$config" > "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq 'content="0; url=new.html"' "$tmp/out/old.html"
cmp "$tmp/out/old.html" "$tmp/out/older.html"
grep -Fq 'href="https://example.org/project/new.html"' "$tmp/out/old.html"
test "$(grep -o '<loc>' "$tmp/out/sitemap.xml" | wc -l)" = 4
! grep -Fq '/old.html' "$tmp/out/sitemap.xml"
"$cli" deps "$tmp/site" --json | jq -e '.report.artifacts[]|select(.name=="older.html")|any(.dependencies[];.name=="site.json/redirects/older.html")' >/dev/null
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==0' >/dev/null
jq '.redirects["older.html"]="other.html"' "$tmp/site/site.json" > "$tmp/config"
cp "$tmp/config" "$tmp/site/site.json"
cp -a "$tmp/out" "$tmp/before"
"$cli" plan "$tmp/site" "$tmp/out" --json > "$tmp/plan"
jq -e '.report.summary.written==1 and any(.report.outputs[];.name=="older.html" and .action=="write")' "$tmp/plan" >/dev/null
diff -r "$tmp/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==1' >/dev/null
test "$(stat -c %Y "$tmp/out/sitemap.xml")" = 946684800
printf '\nBody edit\n' >> "$tmp/site/content/new.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==1' >/dev/null
test "$(stat -c %Y "$tmp/out/old.html")" = 946684800
jq 'del(.redirects["older.html"])' "$tmp/site/site.json" > "$tmp/config"
cp "$tmp/config" "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.deleted==1 and .report.written==0' >/dev/null
test ! -e "$tmp/out/older.html"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/valid"
cp "$tmp/site/site.json" "$tmp/good-config"
reject() { local status=0; "$@" > "$tmp/stdout" 2> "$tmp/error" || status=$?; test "$status" = 1; test ! -s "$tmp/stdout"; test -s "$tmp/error"; }
for redirects in '{"old.html":"missing.html"}' '{"old.html":"old.html"}' '{"old.html":"older.html","older.html":"old.html"}' '{"index.html":"new.html"}' '{"old.html":"draft.html"}' '{"../old.html":"new.html"}' '{"old.html":false}' 'null'; do
  jq --argjson redirects "$redirects" '.redirects=$redirects' "$tmp/good-config" > "$tmp/site/site.json"
  for command in build explain plan; do reject "$cli" "$command" "$tmp/site" "$tmp/out" --json; done
  reject "$cli" build "$tmp/site" "$tmp/fresh" --json
  test ! -e "$tmp/fresh"
  diff -r "$tmp/out" "$tmp/valid"
done
jq '.redirects={"old.html":"draft.html"}' "$tmp/good-config" > "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
grep -Fq 'content="0; url=draft.html"' "$tmp/preview/old.html"
cp "$tmp/good-config" "$tmp/site/site.json"
printf '\nmanual\n' >> "$tmp/out/old.html"
cp -a "$tmp/out" "$tmp/edited"
reject "$cli" build "$tmp/site" "$tmp/out" --json
diff -r "$tmp/out" "$tmp/edited"
# A public/generated HTML name cannot silently overwrite an existing source page.
printf '# Collision\n' > "$tmp/site/content/old.md"
reject "$cli" check "$tmp/site" --json
echo 'Redirect tests passed: terminal chains, canonical/sitemap behavior, targeted dependencies, draft scope, cycles/collisions/dangling names, protected publication and clean parity.'
