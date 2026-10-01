#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
"$cli" posts "$tmp/site" --json | jq -e '.schema == 1 and .command == "posts" and .report.posts == []' >/dev/null
printf '%s\n' '---' '{"title":"Draft\nTitle","draft":true,"listed":false,"slug":"hello","date":"2026-01-01","tags":["月"]}' '---' '# Body' > "$tmp/site/content/a.md"
printf '# 公開候補\n' > "$tmp/site/content/月.md"
cp -a "$tmp/site" "$tmp/before"
"$cli" posts "$tmp/site" --json | jq -e '.report.posts | length == 2 and .[0] == {source:"content/a.md",output:"hello.html",title:"Draft\nTitle",draft:true,listed:false,date:"2026-01-01",tags:["月"]} and .[1].draft == false' >/dev/null
"$cli" posts "$tmp/site" > "$tmp/text"
grep -Fq 'Draft\nTitle' "$tmp/text"
test "$(wc -l < "$tmp/text")" = 3
diff -r "$tmp/site" "$tmp/before"
for flag in --help -h; do "$cli" posts "$flag" | grep -Fq 'Usage: moonpress posts'; done
failure() {
  local expected="$1" status=0
  shift
  "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" = "$expected"
  test ! -s "$tmp/stdout"
  test -s "$tmp/stderr"
}
failure 2 posts
failure 2 posts "$tmp/site" --include-drafts
failure 2 posts "$tmp/site" --json --json
failure 2 posts "$tmp/site" extra
printf '%s\n' '---' '{"draft":"yes"}' '---' > "$tmp/site/content/z.md"
failure 1 posts "$tmp/site" --json
rm "$tmp/site/content/z.md"
ln -s "$tmp/before/content/a.md" "$tmp/site/content/z.md"
failure 1 posts "$tmp/site"
rm "$tmp/site/content/z.md"
diff -r "$tmp/site" "$tmp/before"
echo 'Posts tests passed: metadata, drafts, Unicode, deterministic ordering, CLI grammar and no mutation.'
