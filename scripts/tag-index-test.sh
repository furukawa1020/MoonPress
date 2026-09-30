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
printf '%s' '{"base_url":"https://example.org/","tag_page_size":1}' > "$tmp/site/site.json"
for n in 1 2; do
  printf '%s\n' '---' "{\"title\":\"A$n\",\"tags\":[\"月\"]}" '---' "# A$n" > "$tmp/site/content/a$n.md"
done
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
  "$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
else
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
fi
cp "$tmp/site/site.json" "$tmp/disabled.json"
jq '.tag_index=true' "$tmp/disabled.json" > "$tmp/site/site.json"
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
jq -e '.report.written == 2' "$tmp/build" >/dev/null
grep -Fq 'href="tag-e69c88.html">月</a>' "$tmp/out/tags.html"
grep -Fq '(2 articles)' "$tmp/out/tags.html"
grep -Fq '/tags.html</loc>' "$tmp/out/sitemap.xml"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
sed -i 's/"title":"A1"/"title":"Changed","date":"2026-01-01"/' "$tmp/site/content/a1.md"
printf '\n[Tags](tags.html)\n' >> "$tmp/site/content/a1.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test "$(stat -c %Y "$tmp/out/tags.html")" = 946684800
sed -i 's/"title":"A2"/"title":"A2","listed":false/' "$tmp/site/content/a2.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq '(1 article)' "$tmp/out/tags.html"
test ! -e "$tmp/out/tag-e69c88-2.html"
printf '%s\n' '---' '{"draft":true,"tags":["月"]}' '---' '# Draft' > "$tmp/site/content/draft.md"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
grep -Fq '(2 articles)' "$tmp/preview/tags.html"
"$cli" build "$tmp/site" "$tmp/preview" >/dev/null
diff -r "$tmp/out" "$tmp/preview"
cp -a "$tmp/out" "$tmp/valid"
printf '# Collision\n' > "$tmp/site/content/tags.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -Fq 'Output collision' "$tmp/error"
diff -r "$tmp/out" "$tmp/valid"
rm "$tmp/site/content/tags.md"
cp "$tmp/disabled.json" "$tmp/site/site.json"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -Fq 'broken internal link' "$tmp/error"
diff -r "$tmp/out" "$tmp/valid"
sed -i '/\[Tags\]/d' "$tmp/site/content/a1.md"
printf edited >> "$tmp/out/tags.html"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
cp "$tmp/valid/tags.html" "$tmp/out/tags.html"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/tags.html"
# Empty enabled index is a valid public route.
sed -i 's/"title":"Changed"/"title":"Changed","listed":false/' "$tmp/site/content/a1.md"
jq '.tag_index=true' "$tmp/disabled.json" > "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq '<h1>Tags</h1>' "$tmp/out/tags.html"
if grep -Fq '<li>' "$tmp/out/tags.html"; then exit 1; fi
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
echo 'Tag index tests passed: counts, precise dependencies, pagination, previews, empty index, collisions, protected removal and parity.'
