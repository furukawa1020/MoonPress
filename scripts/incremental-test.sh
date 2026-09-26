#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -a site "$tmp/site"
"$cli" explain "$tmp/site" "$tmp/out" > "$tmp/plan"
test ! -e "$tmp/out"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
# Force a distinctive mtime: a no-op must not rewrite even its manifest.
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 0' "$tmp/log"
for f in "$tmp/out"/* "$tmp/out"/.moonpress.json "$tmp/out"/.nojekyll; do
  test "$(stat -c %Y "$f")" = 946684800
done
printf '\nChanged body.\n' >> "$tmp/site/content/index.md"
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" > "$tmp/plan"
grep -q 'WRITE index.html.*content/index.md' "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 1' "$tmp/log"
test "$(stat -c %Y "$tmp/out/guide.html")" = 946684800
test "$(stat -c %Y "$tmp/out/style.css")" = 946684800
printf '\n/* new color */\n' >> "$tmp/site/style.css"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 1' "$tmp/log"
printf '\n<!-- layout revision -->\n' >> "$tmp/site/layout.html"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 3' "$tmp/log"
mv "$tmp/site/content/guide.md" "$tmp/site/content/manual.md"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'DELETE guide.html' "$tmp/log"
test ! -e "$tmp/out/guide.html"
test -s "$tmp/out/manual.html"
rm "$tmp/out/index.html"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'output missing' "$tmp/log"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
reject() {
  local code=0
  "$cli" build "$tmp/site" "$tmp/out" >"$tmp/log" 2>"$tmp/error" || code=$?
  test "$code" = 1
  test -s "$tmp/error"
}
printf 'my own data' > "$tmp/out/notes.txt"
reject
cmp "$tmp/out/index.html" "$tmp/clean/index.html"
rm "$tmp/out/notes.txt"
printf 'manual edit' >> "$tmp/out/index.html"
reject
cp "$tmp/clean/index.html" "$tmp/out/index.html"
rm "$tmp/out/index.html"
ln -s "$tmp/clean/index.html" "$tmp/out/index.html"
reject
rm "$tmp/out/index.html"
cp "$tmp/clean/index.html" "$tmp/out/index.html"
# Reject the directory itself if it is a symlink (including trailing slash).
ln -s "$tmp/out" "$tmp/link"
if "$cli" build "$tmp/site" "$tmp/link/" > /dev/null 2>&1; then exit 1; fi
# Malformed/traversal manifests never authorize deleting outside the output.
printf 'precious' > "$tmp/precious"
printf '{"schema":1,"compiler":"moonpress-0.1","artifacts":[{"name":"../precious","digest":"","dependencies":[]}]}' > "$tmp/out/.moonpress.json"
reject
test "$(cat "$tmp/precious")" = precious
echo 'Incremental tests passed: no-op mtime, dependency scope, dry-run, delete/rename, missing output, clean equivalence and output protection.'
