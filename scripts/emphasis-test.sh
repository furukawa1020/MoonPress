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
printf '<svg/>' > "$tmp/site/public/moon.svg"
cat > "$tmp/site/content/index.md" <<'MD'
---
{"tags":["core"]}
---
# **Moon** *Press*

**outer *inner* end** and **`*code*` [Guide](guide.html#mp-guide) ![Moon](moon.svg)**

~~~
**literal** [fake](missing.html)
~~~
MD
printf '# **Guide**\n\n[Home](index.html#mp-moon-press)\n' > "$tmp/site/content/guide.md"
"$cli" check "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
# Exercise the compiler-dependency migration from the previous renderer.
old_hash="$(printf moonpress-renderer-v11 | sha256sum | cut -d' ' -f1)"
jq --arg hash "$old_hash" '(.artifacts[].dependencies[] | select(.name == "compiler") | .digest) = $hash' \
  "$tmp/out/.moonpress.json" > "$tmp/previous.json"
cp "$tmp/previous.json" "$tmp/out/.moonpress.json"
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
jq -e '[.report.changes[] | select(.action == "write" and (.reason | contains("compiler")))] | length == 2' "$tmp/plan" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
grep -Fq '<title>Moon Press</title>' "$tmp/out/index.html"
grep -Fq '<h1 id="mp-moon-press"><strong>Moon</strong> <em>Press</em></h1>' "$tmp/out/index.html"
grep -Fq '<strong>outer <em>inner</em> end</strong>' "$tmp/out/index.html"
grep -Fq '>Moon Press</a>' "$tmp/out/articles.html"
grep -Fq '>Moon Press</a>' "$tmp/out/tag-636f7265.html"
grep -Fq '<pre><code>**literal** [fake](missing.html)' "$tmp/out/index.html"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
sed -i 's/outer/changed/g' "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/valid"
cp "$tmp/site/content/index.md" "$tmp/index.md"
for bad in '**[Broken](missing.html)**' '**[Broken](guide.html#mp-missing)**' '*![Bad](missing.svg)*' '**[Bad](javascript:alert)**'; do
  cp "$tmp/index.md" "$tmp/site/content/index.md"
  printf '\n%s\n' "$bad" >> "$tmp/site/content/index.md"
  if "$cli" check "$tmp/site" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
  for command in explain build; do
    if "$cli" "$command" "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
    test -s "$tmp/stderr"
    diff -r "$tmp/out" "$tmp/valid"
  done
done
echo 'Emphasis tests passed: rendering, titles/TOC/anchors, reference preflight, renderer migration, scoped rebuilds, no-op and clean parity.'
