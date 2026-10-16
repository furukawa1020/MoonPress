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
printf '# Home\n' > "$tmp/site/content/index.md"
printf '%s\n' '---' '{"date":"2026-01-01","tags":["news"]}' '---' '# News' > "$tmp/site/content/news.md"
printf '{}\n' > "$tmp/config"
"$cli" settings-save "$tmp/site" absent "$tmp/config" >/dev/null
save() { local version; version="$("$cli" settings-read "$tmp/site" --json | jq -r '.report.digest')"; "$cli" settings-save "$tmp/site" "$version" "$tmp/config" >/dev/null; }
review() { "$cli" review "$tmp/site" "$tmp/out" --json | jq -r '.report.review_id'; }
reject() { local code=0; "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?; test "$code" = 1; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
id="$(review)"
cp -a "$tmp/out" "$tmp/before"
printf '%s\n' '{"base_url":"https://example.org/blog/","feed":{"title":"News","description":"Updates"},"tag_index":true,"redirects":{"old.html":"news.html"}}' > "$tmp/config"
save
diff -r "$tmp/out" "$tmp/before"
reject "$cli" build-reviewed "$tmp/site" "$tmp/out" "$id"
diff -r "$tmp/out" "$tmp/before"
"$cli" check "$tmp/site" >/dev/null
"$cli" build-reviewed "$tmp/site" "$tmp/out" "$(review)" >/dev/null
for file in sitemap.xml rss.xml tags.html old.html; do test -f "$tmp/out/$file"; done
"$cli" build "$tmp/site" "$tmp/clean-enabled" >/dev/null
diff -r "$tmp/out" "$tmp/clean-enabled"
# Schema validity is deliberately separate from route/layout validity.
for config in '{"redirects":{"old.html":"missing.html"}}' '{"tag_index":true,"collection_layout":"missing.html"}'; do
  printf '%s\n' "$config" > "$tmp/config"
  save
  reject "$cli" check "$tmp/site"
  reject "$cli" build "$tmp/site" "$tmp/out"
  diff -r "$tmp/out" "$tmp/clean-enabled"
done
printf '{}\n' > "$tmp/config"
save
# Manual edits still block deletions after settings disable generated artifacts.
printf manual >> "$tmp/out/rss.xml"
reject "$cli" build "$tmp/site" "$tmp/out"
cp "$tmp/clean-enabled/rss.xml" "$tmp/out/rss.xml"
"$cli" build-reviewed "$tmp/site" "$tmp/out" "$(review)" >/dev/null
for file in sitemap.xml rss.xml tags.html old.html; do test ! -e "$tmp/out/$file"; done
"$cli" build "$tmp/site" "$tmp/clean-disabled" >/dev/null
diff -r "$tmp/out" "$tmp/clean-disabled"
echo 'Settings transitions passed: separate full validation, stale reviewed plans, feed/sitemap/redirect enable-disable, manual output protection and fresh/incremental parity.'
