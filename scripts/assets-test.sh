#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '{"base_url":"https://example.org/"}' > "$tmp/site/site.json"
printf '# Home\n\n[Download](sample.pdf)\n' > "$tmp/site/content/index.md"
# Deliberately include NUL and invalid UTF-8 to catch accidental text conversion.
printf '\000\377\200\001\012' > "$tmp/site/public/sample.pdf"
printf '月' > "$tmp/site/public/資料.txt"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
cmp "$tmp/site/public/sample.pdf" "$tmp/out/sample.pdf"
cmp "$tmp/site/public/資料.txt" "$tmp/out/資料.txt"
cp -a "$tmp/out" "$tmp/initial"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 0' "$tmp/log"
test "$(stat -c %Y "$tmp/out/sample.pdf")" = 946684800
printf '\377\000more' >> "$tmp/site/public/sample.pdf"
"$cli" explain "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'changed dependency: public/sample.pdf' "$tmp/log"
diff -r "$tmp/out" "$tmp/initial"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 1' "$tmp/log"
cmp "$tmp/site/public/sample.pdf" "$tmp/out/sample.pdf"
for name in index.html articles.html style.css sitemap.xml; do
  test "$(stat -c %Y "$tmp/out/$name")" = 946684800
done
rm "$tmp/out/資料.txt"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'output missing' "$tmp/log"
cmp "$tmp/site/public/資料.txt" "$tmp/out/資料.txt"
cp -a "$tmp/out" "$tmp/before"
reject() {
  for command in build explain; do
    if "$cli" "$command" "$tmp/site" "$tmp/out" > /dev/null 2>"$tmp/error"; then
      echo 'Expected asset rejection' >&2; exit 1
    fi
    test -s "$tmp/error"
    diff -r "$tmp/out" "$tmp/before"
  done
}
for name in style.css sitemap.xml .moonpress.json index.html .nojekyll bad.js bad.TS bad.mjs bad.cjs bad.jsx bad.tsx; do
  printf 'invalid asset' > "$tmp/site/public/$name"
  reject
  rm "$tmp/site/public/$name"
done
ln -s "$tmp/site/style.css" "$tmp/site/public/link.css"
reject
rm "$tmp/site/public/link.css"
mkdir "$tmp/site/public/nested"
reject
rmdir "$tmp/site/public/nested"
mv "$tmp/site/public" "$tmp/assets"
ln -s "$tmp/assets" "$tmp/site/public"
reject
rm "$tmp/site/public"
mv "$tmp/assets" "$tmp/site/public"
# Removing a referenced asset must fail even while its stale output still exists.
mv "$tmp/site/public/sample.pdf" "$tmp/site/public/renamed.pdf"
reject
printf '# Home\n\n[Download](renamed.pdf)\n' > "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
test ! -e "$tmp/out/sample.pdf"
cmp "$tmp/site/public/renamed.pdf" "$tmp/out/renamed.pdf"
"$cli" build "$tmp/site" "$tmp/clean" > /dev/null
diff -r "$tmp/out" "$tmp/clean"
# Removing the optional directory removes all previously tracked assets.
mv "$tmp/site/public" "$tmp/assets"
printf '# Home\n' > "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
test ! -e "$tmp/out/renamed.pdf"
test ! -e "$tmp/out/資料.txt"
"$cli" build "$tmp/site" "$tmp/without-assets" > /dev/null
diff -r "$tmp/out" "$tmp/without-assets"
echo 'Asset tests passed: binary integrity, no-op/update/delete/rename/missing, links, collisions, symlinks, unsupported types and clean equivalence.'
