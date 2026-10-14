#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '<title>{{title}}</title>{{toc}}{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '<svg/>' > "$tmp/site/public/a.svg"
cat > "$tmp/site/content/index.md" <<'MD'
# Home

| Name | Value | Other |
| :--- | :---: | ---: |
| [Guide](guide.html#mp-guide) | ![Image](a.svg) | <unsafe> |
| # Cell | `a|b [Ignore](missing.html)` | escaped \| pipe |
| **Moon** | ~~old~~ | 月😀 |
extra | cell | count | preserved

~~~
A | B
--- | ---
[Ignore](missing.html) | code
~~~
MD
printf '# Guide\n' > "$tmp/site/content/guide.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq '<th scope="col" style="text-align:left">Name</th>' "$tmp/out/index.html"
grep -Fq 'style="text-align:right">&lt;unsafe&gt;</td>' "$tmp/out/index.html"
grep -Fq 'escaped | pipe</td>' "$tmp/out/index.html"
grep -Fq '<p>extra | cell | count | preserved</p>' "$tmp/out/index.html"
test "$(grep -o '<table>' "$tmp/out/index.html" | wc -l)" = 1
old_hash="$(printf moonpress-renderer-v21 | sha256sum | cut -d' ' -f1)"
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
sed -i 's/escaped \\| pipe/changed \\| pipe/' "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==1' >/dev/null
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/site" "$tmp/source-valid"
cp -a "$tmp/out" "$tmp/valid"
for bad in '[Broken](missing.html)' '![Missing](missing.svg)' '[Unsafe](javascript:alert)' '[Guide](guide.html#mp-missing)'; do
  cp "$tmp/source-valid/content/index.md" "$tmp/site/content/index.md"
  printf '\nA | B\n--- | ---\n%s | safe\n' "$bad" >> "$tmp/site/content/index.md"
  for command in explain build plan; do
    status=0
    "$cli" "$command" "$tmp/site" "$tmp/out" --json > "$tmp/stdout" 2> "$tmp/error" || status=$?
    test "$status" = 1; test ! -s "$tmp/stdout"
    diff -r "$tmp/out" "$tmp/valid"
  done
done
# A table cell cannot define a generated heading target.
cp "$tmp/source-valid/content/index.md" "$tmp/site/content/index.md"
printf '\n[Cell](#mp-cell)\n' >> "$tmp/site/content/index.md"
status=0
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/stdout" 2> "$tmp/error" || status=$?
test "$status" = 1; grep -Fq 'broken heading link' "$tmp/error"
diff -r "$tmp/out" "$tmp/valid"
echo 'Table tests passed: semantic/aligned/escaped cells, code/pipe isolation, reference checks, malformed row preservation, migration, scope/no-op and clean parity.'
