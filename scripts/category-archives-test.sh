#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body{}' > "$tmp/site/style.css"
printf '%s\n' '{"base_url":"https://example.test","tag_index":true,"tag_page_size":1}' > "$tmp/site/site.json"
for n in 1 2; do printf '%s\n' '---' "{\"title\":\"Article$n\",\"categories\":[\"月\"],\"tags\":[\"topic\"],\"date\":\"2026-01-0$n\"}" '---' "Body $n" > "$tmp/site/content/p$n.md"; done
for state in '"kind":"page"' '"listed":false' '"draft":true'; do printf '%s\n' '---' "{$state,\"categories\":[\"private\"]}" '---' '# Excluded' > "$tmp/site/content/$(echo "$state" | tr -cd a-z).md"; done
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
category=category-e69c88
grep -Fq 'Article2' "$tmp/out/$category.html"
grep -Fq 'Article1' "$tmp/out/$category-2.html"
grep -Fq "$category-2.html" "$tmp/out/sitemap.xml"
grep -Fq "$category.html" "$tmp/out/tags.html"
grep -Fq '(2)' "$tmp/out/categories.html"
! grep -Fq 'private' "$tmp/out/categories.html"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==0' >/dev/null
sed -i 's/"categories":\["月"\]/"categories":[]/' "$tmp/site/content/p1.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/$category-2.html"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/before"
printf '# Collision\n' > "$tmp/site/content/categories.md"
if "$cli" build "$tmp/site" "$tmp/out" > "$tmp/error" 2>&1; then exit 1; fi
diff -r "$tmp/out" "$tmp/before"
echo 'Category archives passed: Unicode pagination, navigation/counts, post-only membership, no-op stability, guarded shrinking, clean parity and collisions.'
