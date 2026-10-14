#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '<title>{{title}}</title>{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '<svg/>' > "$tmp/site/public/a.svg"
printf '# Home\n\n[Guide](guide.html)  \n![Image](a.svg)\\\nnext\n\n> quote  \n> next\n\n~~~\nliteral  \n~~~\n' > "$tmp/site/content/index.md"
printf '# Guide\n' > "$tmp/site/content/guide.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq '</a><br>' "$tmp/out/index.html"
grep -Fq 'alt="Image"><br>' "$tmp/out/index.html"
grep -Fq '<p>quote<br>' "$tmp/out/index.html"
old_hash="$(printf moonpress-renderer-v19 | sha256sum | cut -d' ' -f1)"
jq --arg hash "$old_hash" '(.artifacts[].dependencies[]|select(.name=="compiler")|.digest)=$hash' "$tmp/out/.moonpress.json" > "$tmp/old"
cp "$tmp/old" "$tmp/out/.moonpress.json"
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
jq -e '.report.written==2' "$tmp/plan" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==0' >/dev/null
printf '\nbody  \nchanged\n' >> "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==1' >/dev/null
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/valid"
printf '\n[Broken](missing.html)\\\nnext\n' >> "$tmp/site/content/index.md"
for command in explain build plan; do
  status=0
  "$cli" "$command" "$tmp/site" "$tmp/out" --json > "$tmp/stdout" 2> "$tmp/error" || status=$?
  test "$status" = 1; test ! -s "$tmp/stdout"
  diff -r "$tmp/out" "$tmp/valid"
done
echo 'Hard break tests passed: paragraphs/quotes, code preservation, reference validation, migration, scope/no-op, clean parity and no mutation.'
