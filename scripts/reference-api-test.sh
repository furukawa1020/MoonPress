#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/layouts" "$tmp/site/public"
printf '<a href="index.html">Home</a>{{content}}' > "$tmp/site/layout.html"
printf '<img src="photo.svg">{{content}}' > "$tmp/site/layouts/post.html"
printf 'body{}' > "$tmp/site/style.css"
printf '<svg></svg>' > "$tmp/site/public/photo.svg"
printf '%s\n' '{"base_url":"https://example.org/demo/","redirects":{"old.html":"月.html"}}' > "$tmp/site/site.json"
printf '%s\n' '# Home' '[target](/demo/%%E6%%9C%%88.html?x=1#mp-target)' > "$tmp/site/content/index.md"
# Literal percent signs are intentional source bytes, not printf formatting.
sed -i 's/%%/%/g' "$tmp/site/content/index.md"
printf '%s\n' '[external](https://example.org)' '`[code](absent.html)`' >> "$tmp/site/content/index.md"
printf '%s\n' '---' '{"slug":"月","layout":"post.html","listed":false}' '---' '# Target' > "$tmp/site/content/target.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' '[home](index.html)' > "$tmp/site/content/draft.md"
cp -a "$tmp/site" "$tmp/before"
MOONPRESS_REFERENCE_PROBE="$tmp/site" moon test --target native --filter 'reference graph filesystem probe'
diff -r "$tmp/before" "$tmp/site"
echo 'Reference API tests passed: read-only deterministic graph, selected layouts, Unicode slugs, redirects, unlisted/draft scope and code/external exclusions.'
