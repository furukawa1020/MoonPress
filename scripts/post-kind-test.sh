#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body{}' > "$tmp/site/style.css"
printf '%s\n' '{"base_url":"https://example.test","feed":{"title":"Feed","description":"Test"}}' > "$tmp/site/site.json"
printf '%s\n' '---' '{"title":"Article","tags":["topic"],"date":"2026-01-01"}' '---' 'Post body.' > "$tmp/site/content/article.md"
printf '%s\n' '---' '{"title":"About","kind":"page","tags":["page-only"],"date":"2026-01-02"}' '---' 'Page body.' > "$tmp/site/content/about.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq 'Page body.' "$tmp/out/about.html"
grep -Fq 'about.html' "$tmp/out/sitemap.xml"
! grep -Fq 'About' "$tmp/out/articles.html"
! grep -Fq 'About' "$tmp/out/rss.xml"
test ! -e "$tmp/out/tag-706167652d6f6e6c79.html"
grep -Fq 'Article' "$tmp/out/articles.html"
cp "$tmp/site/content/about.md" "$tmp/before"
sed -i 's/"page"/"other"/' "$tmp/site/content/about.md"
if "$cli" build "$tmp/site" "$tmp/out" > "$tmp/log" 2>&1; then exit 1; fi
grep -Fq 'Page body.' "$tmp/out/about.html"
echo 'Post/page kinds passed: pages remain public and in sitemap, excluded from articles/tags/feed; invalid kinds preserve output.'
