#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/layouts"
printf '{{content}}' > "$tmp/site/layout.html"
printf '<main>{{content}}</main>' > "$tmp/site/layouts/list.html"
printf 'body {}' > "$tmp/site/style.css"
printf '# Home\n' > "$tmp/site/content/index.md"
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
else
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
fi
printf '{}' > "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
printf '%s' '{"tag_index":true,"page_size":1,"tag_page_size":1,"collection_layout":"list.html"}' > "$tmp/site/site.json"
printf '%s\n' '---' '{"tags":["local"]}' '---' '# Post' > "$tmp/site/content/post.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/sitemap.xml"
grep -Fq '<main>' "$tmp/out/articles-2.html"
test -f "$tmp/out/tags.html"
cp "$tmp/site/site.json" "$tmp/local.json"
# Publishing settings can be introduced later without touching local content.
jq '.base_url="https://example.org/project/" | .feed={title:"Feed",description:"News"}' "$tmp/local.json" > "$tmp/site/site.json"
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/legacy" >/dev/null
  "$cli" build "$tmp/site" "$tmp/legacy" --json | jq -e '.report.written == 0' >/dev/null
fi
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 2' >/dev/null
test -f "$tmp/out/rss.xml"
cp -a "$tmp/out" "$tmp/valid"
jq 'del(.base_url)' "$tmp/site/site.json" > "$tmp/bad.json"
cp "$tmp/bad.json" "$tmp/site/site.json"
for command in explain build; do
  if "$cli" "$command" "$tmp/site" "$tmp/out" > "$tmp/stdout" 2> "$tmp/error"; then exit 1; fi
  grep -Fq 'feed requires base_url' "$tmp/error"
  test ! -s "$tmp/stdout"
  diff -r "$tmp/out" "$tmp/valid"
done
cp "$tmp/local.json" "$tmp/site/site.json"
printf '\n[Sitemap](sitemap.xml)\n' >> "$tmp/site/content/post.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2> "$tmp/error"; then exit 1; fi
grep -Fq 'broken internal link' "$tmp/error"
diff -r "$tmp/out" "$tmp/valid"
sed -i '/\[Sitemap\]/d' "$tmp/site/content/post.md"
printf edited >> "$tmp/out/sitemap.xml"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2> "$tmp/error"; then exit 1; fi
cp "$tmp/valid/sitemap.xml" "$tmp/out/sitemap.xml"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.deleted == 2' >/dev/null
test ! -e "$tmp/out/sitemap.xml"
test ! -e "$tmp/out/rss.xml"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
# Exercise the full generated starter through editing, preview and publication.
"$cli" init "$tmp/starter" >/dev/null
"$cli" build "$tmp/starter" "$tmp/starter-out" >/dev/null
printf '%s\n' '---' '{"title":"New article","tags":["news"]}' '---' '# New article' > "$tmp/starter/content/new.md"
"$cli" build "$tmp/starter" "$tmp/starter-out" >/dev/null
grep -Fq 'New article</a>' "$tmp/starter-out/articles.html"
grep -Fq 'news</a>' "$tmp/starter-out/tags.html"
printf '%s\n' '---' '{"draft":true,"tags":["draft"]}' '---' '# Draft' > "$tmp/starter/content/draft.md"
"$cli" build "$tmp/starter" "$tmp/preview" --include-drafts >/dev/null
test -f "$tmp/preview/draft.html"
test ! -e "$tmp/starter-out/draft.html"
"$cli" build "$tmp/starter" "$tmp/preview" >/dev/null
diff -r "$tmp/starter-out" "$tmp/preview"
jq '.base_url="https://example.org/project/" | .feed={title:"My site",description:"News"}' "$tmp/starter/site.json" > "$tmp/publish.json"
cp "$tmp/publish.json" "$tmp/starter/site.json"
"$cli" build "$tmp/starter" "$tmp/starter-out" >/dev/null
"$cli" build "$tmp/starter" "$tmp/starter-clean" >/dev/null
diff -r "$tmp/starter-out" "$tmp/starter-clean"
echo 'Local configuration tests passed: URL-free features, RSS validation, publication transitions, protected deletion and starter authoring workflow.'
