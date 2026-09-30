#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '<link rel="alternate" type="application/rss+xml" href="rss.xml">{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '%s' '{"base_url":"https://example.org/project","feed":{"title":"News & 月","description":"Site news"}}' > "$tmp/site/site.json"
printf '%s\n' '---' '{"title":"Old","description":"<b>&","date":"2025-01-01"}' '---' '# Old' > "$tmp/site/content/old.md"
printf '%s\n' '---' '{"title":"New","date":"2026-01-01"}' '---' '# New' > "$tmp/site/content/新.md"
printf '%s\n' '---' '{"title":"Draft","draft":true}' '---' '# Draft' > "$tmp/site/content/draft.md"
"$cli" check "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq '<title>News &amp; 月</title>' "$tmp/out/rss.xml"
grep -Fq 'https://example.org/project/%E6%96%B0.html' "$tmp/out/rss.xml"
grep -Fq '&amp;lt;b&amp;gt;&amp;amp;' "$tmp/out/rss.xml"
test "$(grep '<item>' "$tmp/out/rss.xml" | head -1)" != ''
grep '<item>' "$tmp/out/rss.xml" | head -1 | grep -Fq '<title>New</title>'
if grep -Eq 'Draft|pubDate|lastBuildDate' "$tmp/out/rss.xml"; then exit 1; fi
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
printf '\nBody edit\n' >> "$tmp/site/content/old.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
test "$(stat -c %Y "$tmp/out/rss.xml")" = 946684800
sed -i 's/Site news/Updated news/' "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1 and .report.changes[0].action != "delete"' >/dev/null
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
test "$(stat -c %Y "$tmp/out/sitemap.xml")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/before"
printf '<foreign/>' > "$tmp/site/public/rss.xml"
if "$cli" build "$tmp/site" "$tmp/out" > /dev/null 2>"$tmp/error"; then exit 1; fi
grep -Fq 'Output collision' "$tmp/error"
diff -r "$tmp/out" "$tmp/before"
rm "$tmp/site/public/rss.xml"
cp "$tmp/site/site.json" "$tmp/config"
for config in '{"base_url":"https://example.org/","feed":null}' '{"base_url":"https://example.org/","feed":{"title":"x","description":"y","typo":1}}' '{"base_url":"https://example.org/","feed":{"title":"x\u0001","description":"y"}}'; do
  printf '%s' "$config" > "$tmp/site/site.json"
  if "$cli" explain "$tmp/site" "$tmp/out" > /dev/null 2>"$tmp/error"; then exit 1; fi
  diff -r "$tmp/out" "$tmp/before"
done
cp "$tmp/config" "$tmp/site/site.json"
cp "$tmp/site/content/old.md" "$tmp/old"
sed -i 's/<b>\&/bad\\u0001/' "$tmp/site/content/old.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -Fq 'invalid XML character' "$tmp/error"
diff -r "$tmp/out" "$tmp/before"
cp "$tmp/old" "$tmp/site/content/old.md"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
grep -Fq '<title>Draft</title>' "$tmp/preview/rss.xml"
"$cli" build "$tmp/site" "$tmp/preview" >/dev/null
diff -r "$tmp/out" "$tmp/preview"
# Disabling feed fails while a template still links it, then safely removes it.
printf '%s' '{"base_url":"https://example.org/project"}' > "$tmp/site/site.json"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
diff -r "$tmp/out" "$tmp/before"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'edited' >> "$tmp/out/rss.xml"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
cp "$tmp/before/rss.xml" "$tmp/out/rss.xml"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/rss.xml"
"$cli" build "$tmp/site" "$tmp/no-feed" >/dev/null
diff -r "$tmp/out" "$tmp/no-feed"
echo 'Feed tests passed: subscriptions, chronology, escaping, drafts, scoped/no-op builds, collisions, invalid XML, stale removal and clean parity.'
