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
cat > "$tmp/site/content/index.md" <<'MD'
**Home**
====

Section [Guide](guide.html#mp-guide)
---

[Section](#mp-section-guide)

~~~
Hidden
===
~~~
MD
printf 'Guide\n===\n[Home](index.html#mp-home)\n' > "$tmp/site/content/guide.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
grep -Fq '<title>Home</title>' "$tmp/out/index.html"
grep -Fq '<h1 id="mp-home"><strong>Home</strong></h1>' "$tmp/out/index.html"
grep -Fq '<h2 id="mp-section-guide">' "$tmp/out/index.html"
old_hash="$(printf moonpress-renderer-v20 | sha256sum | cut -d' ' -f1)"
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
printf '\nBody edit\n' >> "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==1' >/dev/null
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/valid"
sed -i 's/^Guide$/Renamed/' "$tmp/site/content/guide.md"
for command in explain build plan; do
  status=0
  "$cli" "$command" "$tmp/site" "$tmp/out" --json > "$tmp/stdout" 2> "$tmp/error" || status=$?
  test "$status" = 1; test ! -s "$tmp/stdout"
  grep -Fq 'broken heading link' "$tmp/error"
  diff -r "$tmp/out" "$tmp/valid"
done
sed -i 's/mp-guide/mp-renamed/g' "$tmp/site/content/index.md"
# The local Section link uses visible heading text; changing Guide destination alone preserves its ID.
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==3' >/dev/null
grep -Fq '>Renamed</a>' "$tmp/out/articles.html"
"$cli" build "$tmp/site" "$tmp/renamed-clean" >/dev/null
diff -r "$tmp/out" "$tmp/renamed-clean"
echo 'Setext tests passed: titles/TOC/anchors, code isolation, migration, scope/no-op, stale anchor protection, metadata propagation and clean parity.'
