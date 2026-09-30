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
printf '%s' '{"base_url":"https://example.org/","page_size":1,"feed":{"title":"News","description":"News"}}' > "$tmp/site/site.json"
printf '%s\n' '---' '{"slug":"home","title":"Home","tags":["home"]}' '---' '# Home' '[Post](post.html)' > "$tmp/site/content/index.md"
printf '%s\n' '---' '{"title":"Post","tags":["news"]}' '---' '# Post' '[Home](home.html)' > "$tmp/site/content/post.md"
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
  "$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
else
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
fi
cp -a "$tmp/out" "$tmp/before"
sed -i 's/"slug":"home"/"slug":"home","listed":false/' "$tmp/site/content/index.md"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
jq -e '.report.pages == 2' "$tmp/build" >/dev/null
test -s "$tmp/out/home.html"
test ! -e "$tmp/out/articles-2.html"
test ! -e "$tmp/out/tag-686f6d65.html"
grep -Fq '/home.html</loc>' "$tmp/out/sitemap.xml"
grep -Fq 'href="home.html"' "$tmp/out/post.html"
if grep -Fq '>Home</' "$tmp/out/articles.html" "$tmp/out/rss.xml"; then exit 1; fi
test "$(grep -c '<item>' "$tmp/out/rss.xml")" = 1
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
sed -i 's/"title":"Home"/"title":"About us"/' "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
for file in articles.html rss.xml sitemap.xml; do test "$(stat -c %Y "$tmp/out/$file")" = 946684800; done
# Standalone pages still undergo full link validation.
cp -a "$tmp/out" "$tmp/valid"
printf '\n[Bad](missing.html)\n' >> "$tmp/site/content/index.md"
if "$cli" check "$tmp/site" >/dev/null 2>"$tmp/error"; then exit 1; fi
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
diff -r "$tmp/out" "$tmp/valid"
sed -i '/\[Bad\]/d' "$tmp/site/content/index.md"
# Draft preview does not override listed=false.
printf '%s\n' '---' '{"draft":true,"listed":false,"tags":["secret"]}' '---' '# Preview' > "$tmp/site/content/draft.md"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
test -s "$tmp/preview/draft.html"
test ! -e "$tmp/preview/articles-2.html"
test ! -e "$tmp/preview/tag-736563726574.html"
test "$(grep -c '<item>' "$tmp/preview/rss.xml")" = 1
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/valid2"
# Invalid flags in excluded drafts remain errors.
sed -i 's/"listed":false/"listed":"false"/' "$tmp/site/content/draft.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
diff -r "$tmp/out" "$tmp/valid2"
rm "$tmp/site/content/draft.md"
# References to a disappearing tag stop publication before writes.
printf '\n[Tag](tag-6e657773.html)\n' >> "$tmp/site/content/index.md"
sed -i 's/"title":"Post"/"title":"Post","listed":false/' "$tmp/site/content/post.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -Fq 'broken internal link' "$tmp/error"
diff -r "$tmp/out" "$tmp/valid2"
sed -i '/\[Tag\]/d' "$tmp/site/content/index.md"
printf 'manual edit' >> "$tmp/out/tag-6e657773.html"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
cp "$tmp/valid2/tag-6e657773.html" "$tmp/out/tag-6e657773.html"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test -s "$tmp/out/home.html"
test -s "$tmp/out/post.html"
test ! -e "$tmp/out/tag-6e657773.html"
if grep -Fq '<item>' "$tmp/out/rss.xml"; then exit 1; fi
grep -Fq 'Page 1 of 1' "$tmp/out/articles.html"
"$cli" build "$tmp/site" "$tmp/empty-archive" >/dev/null
diff -r "$tmp/out" "$tmp/empty-archive"
# Restoring listing recreates aggregates through the same plan.
sed -i 's/"listed":false/"listed":true/' "$tmp/site/content/post.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test -s "$tmp/out/tag-6e657773.html"
"$cli" build "$tmp/site" "$tmp/restored" >/dev/null
diff -r "$tmp/out" "$tmp/restored"
echo 'Listed tests passed: public standalone pages, aggregate exclusion, previews, empty archives, migration, scoped updates, preflight/protection and clean parity.'
