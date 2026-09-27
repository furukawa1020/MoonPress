#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '{{toc}}{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
cat > "$tmp/site/content/index.md" <<'PAGE'
# Home
## `` Code ` sample ``
Use `` [missing](ghost.html) ![missing](ghost.png) ` `` here.
PAGE
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
grep -q '<code>Code ` sample</code>' "$tmp/out/index.html"
grep -q 'href="#mp-code-sample"' "$tmp/out/index.html"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
printf '\nA ``second ` sample``.\n' >> "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 1' "$tmp/log"
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" > /dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/before"
printf '\nUnclosed `` [real](ghost.html)\n' >> "$tmp/site/content/index.md"
for command in build explain; do
  if "$cli" "$command" "$tmp/site" "$tmp/out" > /dev/null 2>"$tmp/error"; then exit 1; fi
  grep -q 'broken internal link' "$tmp/error"
  diff -r "$tmp/out" "$tmp/before"
done
echo 'Code span tests passed: literal references, heading/TOC text, scoped updates, clean equivalence and unclosed-span validation.'
