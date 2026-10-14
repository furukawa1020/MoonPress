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
# ~~Home~~

~~[Guide](guide.html#mp-guide)~~ **outer ~~old~~ end**
~~![Image](a.svg)~~
`~~[Ignore](missing.html)~~`
~~~
~~[Ignore](missing.html)~~
~~~
MD
printf '# Guide\n[Home](index.html#mp-home)\n' > "$tmp/site/content/guide.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq '<title>Home</title>' "$tmp/out/index.html"
grep -Fq '<h1 id="mp-home"><del>Home</del></h1>' "$tmp/out/index.html"
grep -Fq '<strong>outer <del>old</del> end</strong>' "$tmp/out/index.html"
old_hash="$(printf moonpress-renderer-v18 | sha256sum | cut -d' ' -f1)"
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
printf '\n~~Body edit~~\n' >> "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==1' >/dev/null
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/valid"
for bad in '[Broken](missing.html)' '![Missing](missing.svg)' '[Unsafe](javascript:alert)' '[Guide](guide.html#mp-missing)'; do
  printf '\n~~%s~~\n' "$bad" >> "$tmp/site/content/index.md"
  for command in explain build plan; do
    status=0
    "$cli" "$command" "$tmp/site" "$tmp/out" --json > "$tmp/stdout" 2> "$tmp/error" || status=$?
    test "$status" = 1; test ! -s "$tmp/stdout"
    diff -r "$tmp/out" "$tmp/valid"
  done
  sed -i '$d' "$tmp/site/content/index.md"
done
echo 'Strikethrough tests passed: shared title/TOC/anchors, nesting, reference safety, migration, no-op/scoped updates and clean parity.'
