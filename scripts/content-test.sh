#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
cp site/style.css "$tmp/site/style.css"
printf '<title>{{title}}</title><meta name="description" content="{{description}}">{{content}}' > "$tmp/site/layout.html"
cat > "$tmp/site/content/a.md" <<'PAGE'
---
{"title":"Alpha","description":"<safe>","tags":["MoonBit"]}
---
# Alpha body
PAGE
cat > "$tmp/site/content/b.md" <<'PAGE'
---
{"title":"Beta","tags":["Other"]}
---
# Beta body
PAGE
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -q '<title>Alpha</title>' "$tmp/out/a.html"
grep -q '&lt;safe&gt;' "$tmp/out/articles.html"
test -s "$tmp/out/tag-4d6f6f6e426974.html"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
printf '\nBody edit.\n' >> "$tmp/site/content/a.md"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 1' "$tmp/log"
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
test "$(stat -c %Y "$tmp/out/tag-4d6f6f6e426974.html")" = 946684800
sed -i 's/"Alpha"/"Changed"/' "$tmp/site/content/a.md"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 3' "$tmp/log"
grep -q 'WRITE articles.html.*metadata/a.html' "$tmp/log"
test "$(stat -c %Y "$tmp/out/b.html")" = 946684800
test "$(stat -c %Y "$tmp/out/tag-4f74686572.html")" = 946684800
sed -i 's/"MoonBit"/"Other"/' "$tmp/site/content/a.md"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
test ! -e "$tmp/out/tag-4d6f6f6e426974.html"
grep -q 'Changed' "$tmp/out/tag-4f74686572.html"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp "$tmp/site/content/a.md" "$tmp/site/content/articles.md"
if "$cli" build "$tmp/site" "$tmp/collision" > /dev/null 2>"$tmp/error"; then exit 1; fi
grep -q 'Output collision' "$tmp/error"
test ! -e "$tmp/collision"
rm "$tmp/site/content/articles.md"
printf -- '---\n{"title":42}\n---\nBody\n' > "$tmp/site/content/a.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -q 'a.md:2:' "$tmp/error"
diff -r "$tmp/out" "$tmp/clean"
echo 'Content tests passed: metadata, scoped collection rebuilds, tag deletion, collision rejection and no mutation on invalid input.'
