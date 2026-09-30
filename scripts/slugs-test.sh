#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/layouts"
printf '{{content}}' > "$tmp/site/layout.html"
printf '<title>{{title}}</title>{{toc}}{{content}}<a href="#mp-article">Top</a>' > "$tmp/site/layouts/post.html"
printf 'body {}' > "$tmp/site/style.css"
printf '%s' '{"base_url":"https://example.org/","page_size":1,"feed":{"title":"News","description":"News"}}' > "$tmp/site/site.json"
printf '# Home\n' > "$tmp/site/content/index.md"
printf '# Article\n' > "$tmp/site/content/source.md"
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
  "$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
fi
printf '%s\n' '---' '{"slug":"月","title":"Article","layout":"post.html","tags":["topic"]}' '---' '# Article' > "$tmp/site/content/source.md"
printf '# Home\n[Article](%%E6%%9C%%88.html#mp-article)\n' > "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test -s "$tmp/out/月.html"
test ! -e "$tmp/out/source.html"
grep -Fq 'href="%E6%9C%88.html"' "$tmp/out/articles.html"
grep -Fq '/%E6%9C%88.html' "$tmp/out/rss.xml"
grep -Fq '/%E6%9C%88.html' "$tmp/out/sitemap.xml"
grep -Fq 'href="#mp-article"' "$tmp/out/月.html"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
# Rename changes source processing order, but not output URL or membership order.
mv "$tmp/site/content/source.md" "$tmp/site/content/a.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1 and .report.deleted == 0' >/dev/null
for file in articles.html articles-2.html rss.xml sitemap.xml tag-746f706963.html; do
  test "$(stat -c %Y "$tmp/out/$file")" = 946684800
done
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/before"
# Invalid draft slugs are still metadata errors.
printf '%s\n' '---' '{"draft":true,"slug":"../bad"}' '---' '# Draft' > "$tmp/site/content/draft.md"
if "$cli" check "$tmp/site" >/dev/null 2>"$tmp/error"; then exit 1; fi
rm "$tmp/site/content/draft.md"
for slug in 月 articles articles-2; do
  printf '%s\n' '---' "{\"slug\":\"$slug\"}" '---' '# Duplicate' > "$tmp/site/content/duplicate.md"
  if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
  diff -r "$tmp/out" "$tmp/before"
done
rm "$tmp/site/content/duplicate.md"
# A new URL is not an implicit redirect: stale author links fail first.
sed -i 's/"slug":"月"/"slug":"stable"/' "$tmp/site/content/a.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -Fq 'broken internal link' "$tmp/error"
diff -r "$tmp/out" "$tmp/before"
sed -i 's/%E6%9C%88.html/stable.html/' "$tmp/site/content/index.md"
printf 'manual edit' >> "$tmp/out/月.html"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
cp "$tmp/before/月.html" "$tmp/out/月.html"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
test ! -e "$tmp/out/月.html"
test -s "$tmp/out/stable.html"
"$cli" build "$tmp/site" "$tmp/changed" >/dev/null
diff -r "$tmp/out" "$tmp/changed"
# Draft previews use the same chosen URL and remove it on normal publication.
printf '%s\n' '---' '{"draft":true,"slug":"preview"}' '---' '# Draft' > "$tmp/site/content/draft.md"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
test -s "$tmp/preview/preview.html"
"$cli" build "$tmp/site" "$tmp/preview" >/dev/null
diff -r "$tmp/out" "$tmp/preview"
echo 'Slug tests passed: stable renamed sources, Unicode routing, collections/feed/sitemap, layouts/anchors, migration, protection, drafts and clean parity.'
