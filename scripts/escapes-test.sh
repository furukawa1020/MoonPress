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
cat > "$tmp/site/content/index.md" <<'PAGE'
---
{"tags":["guide"]}
---
# A\*B
\*literal\*
PAGE
printf '# Other\n' > "$tmp/site/content/other.md"
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
  grep -Fq '<title>A\*B</title>' "$tmp/out/index.html"
else
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
  jq --arg compiler "$(printf moonpress-renderer-v15 | sha256sum | cut -d' ' -f1)" \
     --arg collection "$(printf collection-v3 | sha256sum | cut -d' ' -f1)" \
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
grep -Fq '<title>A*B</title>' "$tmp/out/index.html"
grep -Fq 'href="#mp-a-b"' "$tmp/out/index.html"
grep -Fq '>A*B</a>' "$tmp/out/articles.html"
grep -Fq '>A*B</a>' "$tmp/out/tag-6775696465.html"
test "$(stat -c %Y "$tmp/out/style.css")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
cat >> "$tmp/site/content/index.md" <<'PAGE'

\[Missing](ghost.html)
!\[Missing](ghost.png)
[\[Other\]](other.html)
[Anchor](#mp-a-b)
\<script\>
PAGE
"$cli" check "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
grep -Fq '<a href="other.html">[Other]</a>' "$tmp/out/index.html"
grep -Fq '&lt;script&gt;' "$tmp/out/index.html"
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
test "$(stat -c %Y "$tmp/out/other.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean-after" >/dev/null
diff -r "$tmp/out" "$tmp/clean-after"
cp -a "$tmp/out" "$tmp/valid"
printf '\n[x](other\\.html)\n' >> "$tmp/site/content/index.md"
for command in explain build; do
  if "$cli" "$command" "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
  grep -Fq 'disallowed link' "$tmp/stderr"
  diff -r "$tmp/out" "$tmp/valid"
done
echo 'Escape tests passed: literal references, labels, titles/anchors, strict URLs, renderer migration, no-op/scoped builds and clean parity.'
