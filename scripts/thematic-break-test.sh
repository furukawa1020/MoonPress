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
---
{"tags":["core"]}
---
---
# Home
before
- - -
after
- item
* * *
> quote
___
[Guide](guide.html#mp-guide)
~~~
---
***
~~~
MD
printf '***\n# Guide\n[Home](index.html#mp-home)\n' > "$tmp/site/content/guide.md"
"$cli" check "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
old_hash="$(printf moonpress-renderer-v12 | sha256sum | cut -d' ' -f1)"
jq --arg hash "$old_hash" '(.artifacts[].dependencies[] | select(.name == "compiler") | .digest) = $hash' \
  "$tmp/out/.moonpress.json" > "$tmp/previous.json"
cp "$tmp/previous.json" "$tmp/out/.moonpress.json"
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
jq -e '[.report.changes[] | select(.action == "write" and (.reason | contains("compiler")))] | length == 2' "$tmp/plan" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
test "$(grep -o '<hr>' "$tmp/out/index.html" | wc -l)" = 4
grep -Fq '<title>Home</title>' "$tmp/out/index.html"
grep -Fq '<pre><code>---' "$tmp/out/index.html"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
sed -i 's/before/before changed/' "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/valid"
printf '\n___\n[Broken](missing.html)\n' >> "$tmp/site/content/index.md"
for command in explain build; do
  if "$cli" "$command" "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
  test -s "$tmp/stderr"
  diff -r "$tmp/out" "$tmp/valid"
done
printf '%s\n' '---' '# Not JSON frontmatter' > "$tmp/site/content/index.md"
if "$cli" build "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
grep -Fq 'frontmatter' "$tmp/stderr"
diff -r "$tmp/out" "$tmp/valid"
echo 'Thematic break tests passed: block precedence, frontmatter/fence isolation, reference checks, migration, scoped/no-op builds and clean parity.'
