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
printf '%s' '{"base_url":"https://example.org/","page_size":3}' > "$tmp/site/site.json"
for n in 1 2 3; do
  printf '%s\n' '---' "{\"title\":\"A$n\",\"tags\":[\"月\"],\"date\":\"2026-01-0$n\"}" '---' "# A$n" > "$tmp/site/content/a$n.md"
done
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
  "$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
else
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
fi
cp "$tmp/site/site.json" "$tmp/original"
jq '.tag_page_size=1' "$tmp/original" > "$tmp/site/site.json"
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
tag=tag-e69c88
grep -Fq '>A3</a>' "$tmp/out/$tag.html"
grep -Fq '>A2</a>' "$tmp/out/$tag-2.html"
grep -Fq '>A1</a>' "$tmp/out/$tag-3.html"
grep -Fq "rel=\"prev\" href=\"$tag.html\"" "$tmp/out/$tag-2.html"
grep -Fq "/$tag-3.html</loc>" "$tmp/out/sitemap.xml"
test ! -e "$tmp/out/articles-2.html"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
sed -i 's/"title":"A1"/"title":"Changed"/' "$tmp/site/content/a1.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 3' >/dev/null
test "$(stat -c %Y "$tmp/out/$tag.html")" = 946684800
test "$(stat -c %Y "$tmp/out/$tag-2.html")" = 946684800
printf '%s\n' '---' '{"draft":true,"tags":["月"]}' '---' '# Draft' > "$tmp/site/content/draft.md"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
test -s "$tmp/preview/$tag-4.html"
"$cli" build "$tmp/site" "$tmp/preview" >/dev/null
diff -r "$tmp/out" "$tmp/preview"
cp -a "$tmp/out" "$tmp/valid"
printf '# Collision\n' > "$tmp/site/content/$tag-2.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -Fq 'Output collision' "$tmp/error"
diff -r "$tmp/out" "$tmp/valid"
rm "$tmp/site/content/$tag-2.md"
printf '\n[Tag](tag-e69c88-3.html)\n' >> "$tmp/site/content/a3.md"
"$cli" check "$tmp/site" >/dev/null
# Removing membership shrinks routes; stale references prevent mutation.
sed -i 's/"title":"Changed"/"title":"Changed","listed":false/' "$tmp/site/content/a1.md"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -Fq 'broken internal link' "$tmp/error"
diff -r "$tmp/out" "$tmp/valid"
sed -i '/\[Tag\]/d' "$tmp/site/content/a3.md"
printf 'edited' >> "$tmp/out/$tag-3.html"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
cp "$tmp/valid/$tag-3.html" "$tmp/out/$tag-3.html"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/$tag-3.html"
cp "$tmp/original" "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/$tag-2.html"
"$cli" build "$tmp/site" "$tmp/disabled" >/dev/null
diff -r "$tmp/out" "$tmp/disabled"
echo 'Tag pagination tests passed: Unicode routes, independent archives, migration, scoped updates, preview, collisions, protected shrinking and parity.'
