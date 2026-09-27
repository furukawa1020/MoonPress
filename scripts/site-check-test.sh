#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '{{toc}}{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '# Home\n\n![Moon](moon.svg)\n' > "$tmp/site/content/index.md"
printf '<svg/>' > "$tmp/site/public/moon.svg"
cp -a "$tmp/site" "$tmp/source-before"
# An invalid TMPDIR demonstrates that check needs no temp workspace.
TMPDIR="$tmp/no-temp" "$cli" check "$tmp/site" > "$tmp/log"
grep -q '^Checked: 1 pages, 5 outputs; no files written$' "$tmp/log"
test ! -e "$tmp/no-temp"
diff -r "$tmp/site" "$tmp/source-before"
test ! -e "$tmp/site/.moonpress.json"
"$cli" build "$tmp/site" "$tmp/dist" > /dev/null
printf 'manual output edit' > "$tmp/dist/index.html"
printf 'unmanaged' > "$tmp/dist/foreign.txt"
cp -a "$tmp/dist" "$tmp/dist-before"
"$cli" check "$tmp/site" > /dev/null
diff -r "$tmp/dist" "$tmp/dist-before"
# explain is responsible for inspecting existing output integrity.
if "$cli" explain "$tmp/site" "$tmp/dist" > /dev/null 2>"$tmp/error"; then exit 1; fi
reject() {
  cp -a "$tmp/site" "$tmp/invalid-before"
  local status=0
  "$cli" check "$tmp/site" > "$tmp/log" 2>"$tmp/error" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/log"
  test -s "$tmp/error"
  diff -r "$tmp/site" "$tmp/invalid-before"
  diff -r "$tmp/dist" "$tmp/dist-before"
  # Build must reject the same inputs without creating its output.
  if "$cli" build "$tmp/site" "$tmp/rejected" > /dev/null 2>"$tmp/build-error"; then exit 1; fi
  cmp "$tmp/error" "$tmp/build-error"
  test ! -e "$tmp/rejected"
  rm -rf "$tmp/invalid-before"
}
printf '# Home\n\n[Missing](ghost.html)\n' > "$tmp/site/content/index.md"
reject
printf '# Home\n\n![Missing](ghost.png)\n' > "$tmp/site/content/index.md"
reject
printf '%s\n' '---' '{"unknown":true}' '---' '# Home' > "$tmp/site/content/index.md"
reject
cp "$tmp/source-before/content/index.md" "$tmp/site/content/index.md"
printf '# Collision\n' > "$tmp/site/content/articles.md"
reject
rm "$tmp/site/content/articles.md"
printf '<a href="ghost.html">Ghost</a>{{content}}' > "$tmp/site/layout.html"
reject
cp "$tmp/source-before/layout.html" "$tmp/site/layout.html"
printf 'unsupported' > "$tmp/site/public/bad.js"
reject
rm "$tmp/site/public/bad.js"
printf '{"unknown":true}' > "$tmp/site/site.json"
reject
rm "$tmp/site/site.json"
"$cli" check "$tmp/site" > /dev/null
for mode in missing extra; do
  status=0
  if [[ "$mode" == missing ]]; then
    "$cli" check > "$tmp/log" 2>"$tmp/error" || status=$?
  else
    "$cli" check "$tmp/site" "$tmp/output" > "$tmp/log" 2>"$tmp/error" || status=$?
  fi
  test "$status" -eq 2
  test ! -s "$tmp/log"
  grep -q 'Usage:' "$tmp/error"
done
echo 'Site check tests passed: no output/temp writes, input/output preservation, build parity, validation failures and exit codes.'
