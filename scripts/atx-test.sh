#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '<title>{{title}}</title>{{toc}}{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '%s\n' '---' '{"tags":["guide"]}' '---' '# Home ###' > "$tmp/site/content/index.md"
printf '# Other\n' > "$tmp/site/content/other.md"
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
  grep -Fq '<title>Home ###</title>' "$tmp/out/index.html"
else
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
  jq --arg compiler "$(printf moonpress-renderer-v16 | sha256sum | cut -d' ' -f1)" \
     --arg collection "$(printf collection-v4 | sha256sum | cut -d' ' -f1)" \
    '(.artifacts[].dependencies[] | select(.name == "compiler") | .digest) = $compiler |
     (.artifacts[].dependencies[] | select(.name == "collection-renderer") | .digest) = $collection' \
    "$tmp/out/.moonpress.json" > "$tmp/previous.json"
  cp "$tmp/previous.json" "$tmp/out/.moonpress.json"
fi
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
jq -e '.report.written == 4' "$tmp/build" >/dev/null
grep -Fq '<title>Home</title>' "$tmp/out/index.html"
grep -Fq '>Home</a>' "$tmp/out/articles.html"
grep -Fq '>Home</a>' "$tmp/out/tag-6775696465.html"
test "$(stat -c %Y "$tmp/out/style.css")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
printf '\n##\tDetails ###\r\n[Details](#mp-details)\n##\n[Empty](#mp-section)\n' >> "$tmp/site/content/index.md"
"$cli" check "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
grep -Fq '<h2 id="mp-details">Details</h2>' "$tmp/out/index.html"
grep -Fq '<h2 id="mp-section"></h2>' "$tmp/out/index.html"
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
test "$(stat -c %Y "$tmp/out/other.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean-after" >/dev/null
diff -r "$tmp/out" "$tmp/clean-after"
cp -a "$tmp/out" "$tmp/valid"
sed -i 's/Details ###/Renamed ###/' "$tmp/site/content/index.md"
for command in explain build; do
  if "$cli" "$command" "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
  test -s "$tmp/stderr"
  diff -r "$tmp/out" "$tmp/valid"
done
echo 'ATX tests passed: title/collection migration, tabs/empty headings, anchors, scoped/no-op builds, clean parity and preflight integrity.'
