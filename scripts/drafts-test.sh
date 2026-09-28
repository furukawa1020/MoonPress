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
printf '{"base_url":"https://example.org/"}' > "$tmp/site/site.json"
printf '# Home\n' > "$tmp/site/content/index.md"
note() { printf '%s\n' '---' "{\"draft\":$1,\"tags\":[\"private\"]}" '---' '# Note' "$2" > "$tmp/site/content/note.md"; }
note false 'Ready'
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
test -f "$tmp/out/note.html"
test -f "$tmp/out/tag-70726976617465.html"
cp -a "$tmp/out" "$tmp/published"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
note true '[Unfinished](missing.html)'
"$cli" explain "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'SKIP content/note.md' "$tmp/log"
grep -q 'DELETE note.html' "$tmp/log"
diff -r "$tmp/out" "$tmp/published"
"$cli" check "$tmp/site" > "$tmp/log"
grep -q 'Checked: 1 pages' "$tmp/log"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
test ! -e "$tmp/out/note.html"
test ! -e "$tmp/out/tag-70726976617465.html"
if grep -q 'note.html' "$tmp/out/articles.html" "$tmp/out/sitemap.xml"; then exit 1; fi
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" > /dev/null
diff -r "$tmp/out" "$tmp/clean"
printf '\nMore unfinished text\n' >> "$tmp/site/content/note.md"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 0' "$tmp/log"
# Publishing restores the article, collection membership, tag and sitemap route.
note false 'Ready again'
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
test -f "$tmp/out/note.html"
test -f "$tmp/out/tag-70726976617465.html"
grep -q 'note.html' "$tmp/out/sitemap.xml"
printf '# Home\n\n[Note](note.html)\n' > "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
cp -a "$tmp/out" "$tmp/before"
reject() {
  for command in check build explain; do
    status=0
    if [[ "$command" == check ]]; then
      "$cli" check "$tmp/site" > "$tmp/log" 2>"$tmp/error" || status=$?
    else
      "$cli" "$command" "$tmp/site" "$tmp/out" > "$tmp/log" 2>"$tmp/error" || status=$?
    fi
    test "$status" -eq 1
    test ! -s "$tmp/log"
    test -s "$tmp/error"
    diff -r "$tmp/out" "$tmp/before"
  done
}
note true 'Hidden'
reject
grep -q 'broken internal link' "$tmp/error"
# Even excluded documents must have valid metadata.
note null 'Invalid'
reject
grep -q 'wrong type for draft' "$tmp/error"
note true 'Hidden'
printf '%s\n' '---' '{"draft":true}' '---' '# Home' > "$tmp/site/content/index.md"
reject
grep -q 'No published .md pages found' "$tmp/error"
echo 'Draft tests passed: exclusion, publish/unpublish, no-op, clean equivalence, metadata validation and incoming-link/all-draft preflight.'
