#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/layouts"
printf '<main>{{title}}{{content}}</main>' > "$tmp/site/layout.html"
printf '<aside>{{title}}{{content}}</aside>' > "$tmp/site/layouts/一覧.html"
printf 'body {}' > "$tmp/site/style.css"
printf '%s' '{"base_url":"https://example.org/project/","page_size":1,"tag_page_size":1,"tag_index":true,"feed":{"title":"Feed","description":"Articles"}}' > "$tmp/site/site.json"
for n in 1 2; do
  printf '%s\n' '---' '{"tags":["a"]}' '---' "# Page $n" > "$tmp/site/content/p$n.md"
done
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
  "$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
else
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
fi
cp "$tmp/site/site.json" "$tmp/default.json"
cp "$tmp/out/sitemap.xml" "$tmp/sitemap.xml"
jq '.collection_layout="一覧.html"' "$tmp/default.json" > "$tmp/site/site.json"
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
jq -e '.report.written == 5' "$tmp/build" >/dev/null
for route in articles articles-2 tag-61 tag-61-2 tags; do
  grep -Fq '<aside>' "$tmp/out/$route.html"
  jq -e --arg route "$route.html" '[.artifacts[] | select(.name == $route) | .dependencies[].name] | index("layouts/一覧.html") != null and index("layout.html") == null' "$tmp/out/.moonpress.json" >/dev/null
done
diff "$tmp/sitemap.xml" "$tmp/out/sitemap.xml"
grep -Fq '<main>' "$tmp/out/p1.html"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
printf '<aside class="new">{{title}}{{content}}</aside>' > "$tmp/site/layouts/一覧.html"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 5' >/dev/null
test "$(stat -c %Y "$tmp/out/p1.html")" = 946684800
test "$(stat -c %Y "$tmp/out/rss.xml")" = 946684800
test "$(stat -c %Y "$tmp/out/sitemap.xml")" = 946684800
# Default-layout anchors are checked only for source pages using that layout.
printf '<main><a href="#mp-shared">Jump</a>{{content}}</main>' > "$tmp/site/layout.html"
printf '\n## Shared\n' >> "$tmp/site/content/p1.md"
printf '\n## Shared\n' >> "$tmp/site/content/p2.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 2' >/dev/null
cp -a "$tmp/out" "$tmp/valid"
cp "$tmp/site/layouts/一覧.html" "$tmp/layout.html"
assert_rejected() {
  if timeout 10 "$cli" check "$tmp/site" > /dev/null 2> "$tmp/error"; then exit 1; fi
  for command in explain build; do
    if timeout 10 "$cli" "$command" "$tmp/site" "$tmp/out" > /dev/null 2> "$tmp/error"; then exit 1; fi
    test -s "$tmp/error"
    diff -r "$tmp/out" "$tmp/valid"
  done
}
for bad in 'missing content' '<a href="missing.html">Bad</a>{{content}}' '<img src="missing.svg">{{content}}' '<a href="#mp-shared">Bad</a>{{content}}'; do
  printf '%s' "$bad" > "$tmp/site/layouts/一覧.html"
  assert_rejected
done
printf '\377{{content}}' > "$tmp/site/layouts/一覧.html"
assert_rejected
rm "$tmp/site/layouts/一覧.html"
assert_rejected
ln -s "$tmp/layout.html" "$tmp/site/layouts/一覧.html"
assert_rejected
rm "$tmp/site/layouts/一覧.html"
cp "$tmp/layout.html" "$tmp/site/layouts/一覧.html"
printf '%s\n' '---' '{"draft":true,"tags":["a"]}' '---' '# Draft' '## Shared' > "$tmp/site/content/draft.md"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
grep -Fq '<aside' "$tmp/preview/articles-3.html"
grep -Fq '<aside' "$tmp/preview/tag-61-3.html"
"$cli" build "$tmp/site" "$tmp/preview" >/dev/null
diff -r "$tmp/out" "$tmp/preview"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
# Revert to the default and stop reading the formerly selected template.
printf '<main>{{title}}{{content}}</main>' > "$tmp/site/layout.html"
cp "$tmp/default.json" "$tmp/site/site.json"
rm "$tmp/site/layouts/一覧.html"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/final-clean" >/dev/null
diff -r "$tmp/out" "$tmp/final-clean"
echo 'Collection layout tests passed: scoped dependencies, routes, anchors, preflight, preview, default compatibility and clean parity.'
