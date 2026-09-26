#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
cp site/style.css "$tmp/site/style.css"
printf '<a href="/project/a.html">Home</a>{{content}}' > "$tmp/site/layout.html"
printf '{"base_url":"https://example.org/project"}' > "$tmp/site/site.json"
printf '# A\n\n[Next](b.html?from=a#section)\n' > "$tmp/site/content/a.md"
printf '# B\n\n`[example](missing.html)`\n' > "$tmp/site/content/b.md"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
grep -q 'https://example.org/project/b.html' "$tmp/out/sitemap.xml"
grep -q '<a href="b.html?from=a#section">Next</a>' "$tmp/out/a.html"
cp -a "$tmp/out" "$tmp/before"
rm "$tmp/site/content/b.md"
if "$cli" build "$tmp/site" "$tmp/out" > /dev/null 2>"$tmp/error"; then exit 1; fi
grep -q 'broken internal link' "$tmp/error"
diff -r "$tmp/out" "$tmp/before"
printf '# A\n\nNo broken links.\n' > "$tmp/site/content/a.md"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
test ! -e "$tmp/out/b.html"
if grep -q '/b.html' "$tmp/out/sitemap.xml"; then exit 1; fi
"$cli" build "$tmp/site" "$tmp/clean" > /dev/null
diff -r "$tmp/out" "$tmp/clean"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
sed -i s/example.org/example.net/ "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 1' "$tmp/log"
test "$(stat -c %Y "$tmp/out/a.html")" = 946684800
grep -q example.net "$tmp/out/sitemap.xml"
# Removing config removes the tracked sitemap; use relative links without a base.
printf '{{content}}' > "$tmp/site/layout.html"
rm "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
test ! -e "$tmp/out/sitemap.xml"
cp -a "$tmp/out" "$tmp/valid"
printf '<a href="ghost.html">Ghost</a>{{content}}' > "$tmp/site/layout.html"
if "$cli" explain "$tmp/site" "$tmp/out" > /dev/null 2>"$tmp/error"; then exit 1; fi
grep -q 'layout.html: broken internal link' "$tmp/error"
diff -r "$tmp/out" "$tmp/valid"
echo 'Navigation tests passed: preflight links, source deletion, sitemap dependencies, base URL changes and dry-run integrity.'
