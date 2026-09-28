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
printf '%s\n' '---' '{"draft":true,"tags":["preview"]}' '---' '# Draft' > "$tmp/site/content/draft.md"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
cp -a "$tmp/out" "$tmp/public"
"$cli" check "$tmp/site" --include-drafts > "$tmp/log"
grep -q 'Checked: 2 pages' "$tmp/log"
"$cli" explain "$tmp/site" "$tmp/out" --include-drafts > "$tmp/log"
grep -q 'WRITE draft.html' "$tmp/log"
diff -r "$tmp/out" "$tmp/public"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --include-drafts > /dev/null
test -f "$tmp/out/draft.html"
grep -q 'draft.html' "$tmp/out/articles.html" "$tmp/out/sitemap.xml"
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/preview-clean" --include-drafts > /dev/null
diff -r "$tmp/out" "$tmp/preview-clean"
"$cli" build "$tmp/site" "$tmp/out" --include-drafts > "$tmp/log"
grep -q 'written: 0' "$tmp/log"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
diff -r "$tmp/out" "$tmp/public"
# A preview validates references in drafts; published mode excludes them.
printf '\n[Missing](ghost.html)\n' >> "$tmp/site/content/draft.md"
"$cli" check "$tmp/site" > /dev/null
for command in check build explain; do
  status=0
  if [[ "$command" == check ]]; then
    "$cli" check "$tmp/site" --include-drafts > "$tmp/log" 2>"$tmp/error" || status=$?
  else
    "$cli" "$command" "$tmp/site" "$tmp/out" --include-drafts > "$tmp/log" 2>"$tmp/error" || status=$?
  fi
  test "$status" -eq 1
  grep -q 'broken internal link' "$tmp/error"
  diff -r "$tmp/out" "$tmp/public"
done
# All-draft sites are explicitly available only in preview mode.
rm "$tmp/site/content/index.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' > "$tmp/site/content/draft.md"
"$cli" check "$tmp/site" --include-drafts > /dev/null
"$cli" build "$tmp/site" "$tmp/all-draft" --include-drafts > /dev/null
test -f "$tmp/all-draft/draft.html"
if "$cli" check "$tmp/site" > /dev/null 2>"$tmp/error"; then exit 1; fi
# A draft named like a generated route must still fail in preview.
cp "$tmp/site/content/draft.md" "$tmp/site/content/articles.md"
if "$cli" check "$tmp/site" --include-drafts > /dev/null 2>"$tmp/error"; then exit 1; fi
grep -q 'Output collision' "$tmp/error"
usage_error() {
  local status=0
  "$cli" "$@" > "$tmp/log" 2>"$tmp/error" || status=$?
  test "$status" -eq 2
  test ! -s "$tmp/log"
  grep -q 'Usage:' "$tmp/error"
}
usage_error check --include-drafts
usage_error check --include-drafts "$tmp/site"
usage_error check "$tmp/site" --unknown
usage_error check "$tmp/site" --include-drafts --include-drafts
usage_error build "$tmp/site" --include-drafts
usage_error build "$tmp/site" "$tmp/out" --unknown
usage_error build --include-drafts "$tmp/site" "$tmp/out"
usage_error build "$tmp/site" "$tmp/out" --include-drafts --include-drafts
echo 'Draft preview tests passed: explicit inclusion, mode switching, clean/no-op, all-draft preview, validation and option parsing.'
