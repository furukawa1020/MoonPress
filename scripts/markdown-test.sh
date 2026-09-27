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
printf '# Home\n\n- [Guide](guide.html)\n- `<x>`\n\n3. Third\n4. Fourth\n\n> [Guide](guide.html)\n> quote\n' > "$tmp/site/content/index.md"
printf '# Guide\n' > "$tmp/site/content/guide.md"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
grep -q '<ul>' "$tmp/out/index.html"
grep -q '<ol start="3">' "$tmp/out/index.html"
grep -q '<blockquote>' "$tmp/out/index.html"
grep -q '<li><code>&lt;x&gt;</code></li>' "$tmp/out/index.html"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
printf '\n- Added item\n' >> "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 1' "$tmp/log"
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" > /dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/before"
for marker in '- ' '2. ' '> '; do
  printf '# Home\n\n%s[Missing](missing.html)\n' "$marker" > "$tmp/site/content/index.md"
  for command in build explain; do
    if "$cli" "$command" "$tmp/site" "$tmp/out" > /dev/null 2>"$tmp/error"; then exit 1; fi
    grep -q 'broken internal link' "$tmp/error"
    diff -r "$tmp/out" "$tmp/before"
  done
done
echo 'Markdown tests passed: lists/quotes, scoped rebuilds, clean equivalence and preflight link errors.'
