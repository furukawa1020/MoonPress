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
printf '%s\n' '{"base_url":"https://example.org/project/","feed":{"title":"Feed","description":"News","limit":1}}' > "$tmp/site/site.json"
for item in 'old 2020-01-01' 'new 2026-01-01'; do
  read -r name date <<< "$item"
  printf '%s\n' '---' "{\"title\":\"$name\",\"date\":\"$date\"}" '---' "# $name" > "$tmp/site/content/$name.md"
done
printf '# Undated\n' > "$tmp/site/content/undated.md"
printf '%s\n' '---' '{"title":"Private","date":"2026-10-01","draft":true}' '---' '# Private' > "$tmp/site/content/draft.md"
printf '%s\n' '---' '{"title":"Unlisted","date":"2026-10-02","listed":false}' '---' '# Unlisted' > "$tmp/site/content/unlisted.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test "$(grep -o '<item>' "$tmp/out/rss.xml" | wc -l)" = 1
grep -Fq '<item><title>new</title>' "$tmp/out/rss.xml"
"$cli" deps "$tmp/site" --json | jq -e '.report.artifacts[]|select(.name=="rss.xml")|any(.dependencies[];.name=="metadata/new.html") and all(.dependencies[];.name!="metadata/old.html")' >/dev/null
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==0' >/dev/null
sed -i 's/"old"/"Changed old"/' "$tmp/site/content/old.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==2' >/dev/null
test "$(stat -c %Y "$tmp/out/rss.xml")" = 946684800
# XML-specific validation applies to serialized members, not omitted metadata.
sed -i 's/Changed old/Changed old\\u0001/' "$tmp/site/content/old.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test "$(stat -c %Y "$tmp/out/rss.xml")" = 946684800
sed -i 's/Changed old\\u0001/Changed old/' "$tmp/site/content/old.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp "$tmp/site/content/new.md" "$tmp/new-source"
rm "$tmp/site/content/new.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq '<item><title>Changed old</title>' "$tmp/out/rss.xml"
cp "$tmp/new-source" "$tmp/site/content/new.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq '<item><title>new</title>' "$tmp/out/rss.xml"
jq '.feed.limit=2'  "$tmp/site/site.json" > "$tmp/config"
cp "$tmp/config" "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==1' >/dev/null
test "$(grep -o '<item>' "$tmp/out/rss.xml" | wc -l)" = 2
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
grep -Fq '<item><title>Private</title>' "$tmp/preview/rss.xml"
! grep -Fq '<item><title>Unlisted</title>' "$tmp/preview/rss.xml"
jq 'del(.feed.limit)' "$tmp/site/site.json" > "$tmp/config"
cp "$tmp/config" "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==1' >/dev/null
test "$(grep -o '<item>' "$tmp/out/rss.xml" | wc -l)" = 3
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/valid"
cp "$tmp/site/site.json" "$tmp/good-config"
for value in null 0 -1 1001 1.5 true '"1"'; do
  jq --argjson value "$value" '.feed.limit=$value' "$tmp/good-config" > "$tmp/site/site.json"
  status=0
  "$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/stdout" 2> "$tmp/error" || status=$?
  test "$status" = 1; test ! -s "$tmp/stdout"
  diff -r "$tmp/out" "$tmp/valid"
done
cp "$tmp/good-config" "$tmp/site/site.json"
rm "$tmp/site/content/new.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/deleted-clean" >/dev/null
diff -r "$tmp/out" "$tmp/deleted-clean"
echo 'Feed limit tests passed: recent selection, member/dependency scope, omitted XML fields, draft/unlisted behavior, limits/removal/deletion, no-op, invalid config protection and clean parity.'
