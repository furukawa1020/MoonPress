#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/layouts"
printf '<title>{{title}}</title><div class="date">{{date}}</div>{{content}}' > "$tmp/site/layout.html"
printf '<article data-date="{{date}}">{{content}}</article>' > "$tmp/site/layouts/post.html"
printf 'body {}' > "$tmp/site/style.css"
printf '{"base_url":"https://example.org/"}' > "$tmp/site/site.json"
printf '# Home\n' > "$tmp/site/content/index.md"
for page in a b; do
  printf '%s\n' '---' '{"date":"2024-02-29","tags":["core"],"layout":"post.html"}' '---' "# $page" > "$tmp/site/content/$page.md"
done
printf '%s\n' '---' '{"date":"9999-12-31","draft":true,"tags":["core"]}' '---' '# Draft' > "$tmp/site/content/draft.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq 'data-date="2024-02-29"' "$tmp/out/a.html"
grep -Fq '<div class="date"></div>' "$tmp/out/articles.html"
order() { sed -n 's/^<li><a href="\([^"]*\)".*/\1/p' "$1" | paste -sd,; }
test "$(order "$tmp/out/articles.html")" = 'a.html,b.html,index.html'
test "$(order "$tmp/out/tag-636f7265.html")" = 'a.html,b.html'
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
test "$(stat -c %Y "$tmp/out/a.html")" = 946684800
printf '\nBody edit\n' >> "$tmp/site/content/a.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
sed -i 's/2024-02-29/2026-09-29/' "$tmp/site/content/b.md"
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
jq -e '.report.written == 3' "$tmp/plan" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
test "$(order "$tmp/out/articles.html")" = 'b.html,a.html,index.html'
test "$(order "$tmp/out/tag-636f7265.html")" = 'b.html,a.html'
test "$(stat -c %Y "$tmp/out/sitemap.xml")" = 946684800
sed -i 's/"date":"2026-09-29",//' "$tmp/site/content/b.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 3' >/dev/null
grep -Fq 'data-date=""' "$tmp/out/b.html"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
test "$(order "$tmp/preview/articles.html")" = 'draft.html,a.html,b.html,index.html'
grep -Fq '<div class="date">9999-12-31</div>' "$tmp/preview/draft.html"
"$cli" build "$tmp/site" "$tmp/preview" >/dev/null
diff -r "$tmp/out" "$tmp/preview"
cp -a "$tmp/out" "$tmp/valid"
# Excluded drafts still have strict metadata validation.
for bad in 1900-02-29 2026-04-31 0000-01-01; do
  sed "s/9999-12-31/$bad/" "$tmp/site/content/draft.md" > "$tmp/draft.md"
  cp "$tmp/site/content/draft.md" "$tmp/good.md"
  cp "$tmp/draft.md" "$tmp/site/content/draft.md"
  if "$cli" check "$tmp/site" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
  for command in explain build; do
    if "$cli" "$command" "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
    grep -Fq 'draft.md:2: date must' "$tmp/stderr"
    diff -r "$tmp/out" "$tmp/valid"
  done
  cp "$tmp/good.md" "$tmp/site/content/draft.md"
done
# Migrate a prior-renderer manifest, including collection caches.
jq --arg page "$(printf moonpress-renderer-v13 | sha256sum | cut -d' ' -f1)" \
   --arg collection "$(printf collection-v2 | sha256sum | cut -d' ' -f1)" \
   '(.artifacts[].dependencies[] | select(.name == "compiler") | .digest) = $page | (.artifacts[].dependencies[] | select(.name == "collection-renderer") | .digest) = $collection' \
   "$tmp/out/.moonpress.json" > "$tmp/old.json"
cp "$tmp/old.json" "$tmp/out/.moonpress.json"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 5' >/dev/null
diff -r "$tmp/out" "$tmp/clean"
if [[ -n "${LEGACY_CLI:-}" ]]; then
  mkdir -p "$tmp/legacy-site/content"
  printf '<div>{{date}}</div>{{content}}' > "$tmp/legacy-site/layout.html"
  printf 'body {}' > "$tmp/legacy-site/style.css"
  printf '# Old\n' > "$tmp/legacy-site/content/index.md"
  "$LEGACY_CLI" build "$tmp/legacy-site" "$tmp/legacy-out" >/dev/null
  grep -Fq '<div>{{date}}</div>' "$tmp/legacy-out/index.html"
  "$cli" build "$tmp/legacy-site" "$tmp/legacy-out" --json | jq -e '.report.written == 2' >/dev/null
  grep -Fq '<div></div>' "$tmp/legacy-out/index.html"
  grep -Fq '<div></div>' "$tmp/legacy-out/articles.html"
  "$cli" build "$tmp/legacy-site" "$tmp/legacy-clean" >/dev/null
  diff -r "$tmp/legacy-out" "$tmp/legacy-clean"
fi
echo 'Date tests passed: chronological collections, named/default layouts, scoped dependencies, draft validation/preview, migration, no-op and clean parity.'
