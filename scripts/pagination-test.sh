#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '<title>{{title}}</title>{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '%s' '{"base_url":"https://example.org/project/","feed":{"title":"News","description":"Updates"}}' > "$tmp/site/site.json"
for n in 1 2 3 4 5; do
  printf '%s\n' '---' "{\"title\":\"Article $n\",\"description\":\"summary $n\",\"date\":\"2026-01-0$n\"}" '---' "# Article $n" > "$tmp/site/content/a$n.md"
done
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
  "$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0 and .report.deleted == 0' >/dev/null
else
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
fi
cp "$tmp/site/site.json" "$tmp/unpaginated.json"
jq '.page_size=2' "$tmp/site/site.json" > "$tmp/config"
cp "$tmp/config" "$tmp/site/site.json"
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
for page in articles articles-2 articles-3; do test -s "$tmp/out/$page.html"; done
test ! -e "$tmp/out/articles-4.html"
grep -Fq '>Article 5</a>' "$tmp/out/articles.html"
grep -Fq '>Article 4</a>' "$tmp/out/articles.html"
grep -Fq '>Article 3</a>' "$tmp/out/articles-2.html"
grep -Fq '>Article 1</a>' "$tmp/out/articles-3.html"
test "$(grep -h '<li><a href="a' "$tmp/out"/articles*.html | wc -l)" = 5
grep -Fq 'rel="prev" href="articles.html"' "$tmp/out/articles-2.html"
grep -Fq 'rel="next" href="articles-3.html"' "$tmp/out/articles-2.html"
grep -Fq 'Page 3 of 3' "$tmp/out/articles-3.html"
grep -Fq '/articles-3.html</loc>' "$tmp/out/sitemap.xml"
test "$(grep -c '<item>' "$tmp/out/rss.xml")" = 5
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
printf '\nBody edit\n' >> "$tmp/site/content/a1.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
test "$(stat -c %Y "$tmp/out/articles-3.html")" = 946684800
sed -i 's/summary 1/revised summary 1/' "$tmp/site/content/a1.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 3' >/dev/null
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
test "$(stat -c %Y "$tmp/out/articles-2.html")" = 946684800
# Date moves members across archive boundaries.
sed -i 's/2026-01-01/2027-01-01/' "$tmp/site/content/a1.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq '>Article 1</a>' "$tmp/out/articles.html"
"$cli" build "$tmp/site" "$tmp/reordered" >/dev/null
diff -r "$tmp/out" "$tmp/reordered"
# Preview has additional archive routes; normal builds remove them.
for n in 6 7; do
  printf '%s\n' '---' '{"draft":true}' '---' "# Draft $n" > "$tmp/site/content/d$n.md"
done
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
test -s "$tmp/preview/articles-4.html"
test "$(grep -c '<item>' "$tmp/preview/rss.xml")" = 7
"$cli" build "$tmp/site" "$tmp/preview" >/dev/null
diff -r "$tmp/out" "$tmp/preview"
cp -a "$tmp/out" "$tmp/valid"
for value in 0 1001 2.5 null true '"2"'; do
  jq --argjson value "$value" '.page_size=$value' "$tmp/config" > "$tmp/site/site.json"
  if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
  grep -Fq 'page_size' "$tmp/error"
  diff -r "$tmp/out" "$tmp/valid"
done
cp "$tmp/config" "$tmp/site/site.json"
printf '# Collision\n' > "$tmp/site/content/articles-2.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -Fq 'Output collision' "$tmp/error"
diff -r "$tmp/out" "$tmp/valid"
rm "$tmp/site/content/articles-2.md"
# Generated routes are valid link targets; shrinking fails with incoming links.
printf '\n[Archive](articles-3.html)\n' >> "$tmp/site/content/a1.md"
"$cli" check "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/linked"
rm "$tmp/site/content/a3.md" "$tmp/site/content/a4.md" "$tmp/site/content/a5.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -Fq 'broken internal link' "$tmp/error"
diff -r "$tmp/out" "$tmp/linked"
sed -i '/\[Archive\]/d' "$tmp/site/content/a1.md"
printf 'manual edit' >> "$tmp/out/articles-3.html"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
cp "$tmp/linked/articles-3.html" "$tmp/out/articles-3.html"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/articles-2.html"
test ! -e "$tmp/out/articles-3.html"
grep -Fq 'Page 1 of 1' "$tmp/out/articles.html"
"$cli" build "$tmp/site" "$tmp/small" >/dev/null
diff -r "$tmp/out" "$tmp/small"
# Disabling pagination restores original markup and dependencies.
cp "$tmp/unpaginated.json" "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
if grep -Fq 'class="pagination"' "$tmp/out/articles.html"; then exit 1; fi
"$cli" build "$tmp/site" "$tmp/disabled" >/dev/null
diff -r "$tmp/out" "$tmp/disabled"
echo 'Pagination tests passed: migration, partition/order, navigation/sitemap/RSS, scoped updates, drafts, collisions, shrinking/protection and clean parity.'
