#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '{{toc}}\n<main>{{content}}</main>' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '%s\n' '---' '{"tags":["core"]}' '---' '# Intro' '## Intro' '### Intro-2' '```' '# Hidden' '```' > "$tmp/site/content/index.md"
printf 'No headings.' > "$tmp/site/content/plain.md"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
sed -n 's/.*<a href="#\([^"]*\)".*/\1/p' "$tmp/out/index.html" > "$tmp/toc-ids"
sed -n 's/.*<h[1-6] id="\([^"]*\)".*/\1/p' "$tmp/out/index.html" > "$tmp/heading-ids"
cmp "$tmp/toc-ids" "$tmp/heading-ids"
printf 'mp-intro\nmp-intro-2\nmp-intro-2-2\n' > "$tmp/expected"
cmp "$tmp/toc-ids" "$tmp/expected"
for file in plain.html articles.html tag-636f7265.html; do
  if grep -q 'class="toc"\|{{toc}}' "$tmp/out/$file"; then exit 1; fi
done
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 0' "$tmp/log"
printf '\n## Added\n' >> "$tmp/site/content/index.md"
"$cli" explain "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'WRITE index.html' "$tmp/log"
if grep -q 'mp-added' "$tmp/out/index.html"; then exit 1; fi
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 1' "$tmp/log"
grep -q 'href="#mp-added"' "$tmp/out/index.html"
grep -q '<h2 id="mp-added">' "$tmp/out/index.html"
for file in articles.html tag-636f7265.html plain.html; do
  test "$(stat -c %Y "$tmp/out/$file")" = 946684800
done
"$cli" build "$tmp/site" "$tmp/clean" > /dev/null
diff -r "$tmp/out" "$tmp/clean"
# Layout opt-out removes the TOC while preserving anchor navigation.
printf '{{content}}' > "$tmp/site/layout.html"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
if grep -q 'class="toc"' "$tmp/out/index.html"; then exit 1; fi
grep -q '<h2 id="mp-added">' "$tmp/out/index.html"
echo 'TOC tests passed: matching anchor IDs, no-headings/collections, scoped updates, no-op, dry-run, clean equivalence and layout opt-out.'
