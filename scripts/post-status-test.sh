#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" new "$tmp/site" post Title >/dev/null
version() { "$cli" read "$tmp/site" post.md --json | jq -r '.report.digest'; }
old="$(version)"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/post.html"
"$cli" status "$tmp/site" post.md "$old" ready --json | jq -e '.command == "status" and .report.changed' >/dev/null
"$cli" posts "$tmp/site" --json | jq -e '[.report.posts[] | select(.source=="content/post.md")][0].draft == false' >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test -f "$tmp/out/post.html"
cp -a "$tmp/site" "$tmp/ready-site"
failure() {
  local expected="$1" status=0
  shift
  "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" = "$expected"
  test ! -s "$tmp/stdout"
  test -s "$tmp/stderr"
}
failure 1 status "$tmp/site" post.md "$old" draft
grep -Fq 'changed since it was read' "$tmp/stderr"
diff -r "$tmp/site" "$tmp/ready-site"
current="$(version)"
touch -t 200001010000 "$tmp/site/content/post.md"
"$cli" status "$tmp/site" post.md "$current" ready --json | jq -e '.report.changed == false' >/dev/null
test "$(stat -c %Y "$tmp/site/content/post.md")" = 946684800
printf '\n[Post](post.html)\n' >> "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/linked"
"$cli" status "$tmp/site" post.md "$current" draft >/dev/null
failure 1 build "$tmp/site" "$tmp/out"
grep -Fq 'broken internal link' "$tmp/stderr"
diff -r "$tmp/out" "$tmp/linked"
sed -i '/\[Post\]/d' "$tmp/site/content/index.md"
printf edited >> "$tmp/out/post.html"
failure 1 build "$tmp/site" "$tmp/out"
cp "$tmp/linked/post.html" "$tmp/out/post.html"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/post.html"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
test -f "$tmp/preview/post.html"
"$cli" build "$tmp/site" "$tmp/preview" >/dev/null
diff -r "$tmp/out" "$tmp/preview"
"$cli" status --help | grep -Fq 'does not deploy'
failure 2 status
failure 2 status "$tmp/site" post.md "$(version)" publish
failure 2 status "$tmp/site" post.md "$(version)" draft --include-drafts
failure 2 status "$tmp/site" post.md "$(version)" draft --json --json
echo 'Post status tests passed: ready/draft transitions, stale-version refusal, no-op, link protection, output protection and preview parity.'
