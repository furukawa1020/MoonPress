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
printf '<svg/>' > "$tmp/site/public/image.svg"
cat > "$tmp/site/content/index.md" <<'MD'
---
{"tags":["core"]}
---
~~~
# Hidden
~~~
# [月](guide.html) `code` ![絵](image.svg) & <b>
MD
printf '# Guide\n' > "$tmp/site/content/guide.md"
printf '# ![](image.svg)\n# Later\n' > "$tmp/site/content/empty.md"
printf '%s\n' '---' '{"title":"[Literal](url) `code` {{content}}"}' '---' '# Auto' > "$tmp/site/content/explicit.md"
if [[ -n "${LEGACY_CLI:-}" ]]; then
  "$LEGACY_CLI" build "$tmp/site" "$tmp/out" >/dev/null
  grep -Fq '<title>[月](guide.html)' "$tmp/out/index.html"
else
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
  # Keep a valid managed output with the previous compiler dependency revision.
  old_hash="$(printf moonpress-renderer-v10 | sha256sum | cut -d' ' -f1)"
  jq --arg hash "$old_hash" '(.artifacts[].dependencies[] | select(.name == "compiler") | .digest) = $hash' \
    "$tmp/out/.moonpress.json" > "$tmp/previous.json"
  cp "$tmp/previous.json" "$tmp/out/.moonpress.json"
fi
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
jq -e '[.report.changes[] | select(.action == "write" and (.reason | contains("compiler")))] | length == 4' "$tmp/plan" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
grep -Fq '<title>月 code 絵 &amp; &lt;b&gt;</title>' "$tmp/out/index.html"
grep -Fq '>月 code 絵 &amp; &lt;b&gt;</a>' "$tmp/out/articles.html"
grep -Fq '>月 code 絵 &amp; &lt;b&gt;</a>' "$tmp/out/tag-636f7265.html"
grep -Fq '<title>empty</title>' "$tmp/out/empty.html"
grep -Fq '<title>[Literal](url) `code` {{content}}</title>' "$tmp/out/explicit.html"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
# A label edit changes the automatic title and dependent collections.
sed -i 's/\[月\]/[星]/' "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
jq -e '.report.written == 3' "$tmp/build" >/dev/null
grep -Fq '<title>星 code 絵 &amp; &lt;b&gt;</title>' "$tmp/out/index.html"
test "$(stat -c %Y "$tmp/out/guide.html")" = 946684800
echo 'Title tests passed: visible inline text, literal metadata, escaping, prior-renderer upgrade, collection dependencies, no-op and clean parity.'
