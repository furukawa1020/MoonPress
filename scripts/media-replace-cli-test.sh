#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
mkdir "$tmp/site/public"
name='月 &a.PNG'
asset="$tmp/site/public/$name"
printf '\000\377old' > "$asset"
printf '\377\000new' > "$tmp/replacement"
cp "$tmp/replacement" "$tmp/replacement-before"
cp -a "$tmp/site" "$tmp/before"
"$cli" media-read "$tmp/site" "$name" --json > "$tmp/read"
version="$(jq -r '.report.digest' "$tmp/read")"
test "$version" = "$(sha256sum "$asset" | cut -d ' ' -f1)"
jq -e '.schema==1 and .command=="media-read" and (.include_drafts|not) and .report.bytes==5 and .report.image and .report.url=="%E6%9C%88%20%26a.PNG"' "$tmp/read" >/dev/null
diff -r "$tmp/before" "$tmp/site"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/output-before"
chmod 640 "$asset"
touch -t 200001010000 "$asset"
metadata="$(stat -c '%i %a %Y' "$asset")"
"$cli" media-replace "$tmp/site" "$name" "$version" "$asset" --json | jq -e '(.report.changed|not)' >/dev/null
test "$(stat -c '%i %a %Y' "$asset")" = "$metadata"
"$cli" media-replace "$tmp/site" "$name" "$version" "$tmp/replacement" --json > "$tmp/changed"
jq -e --arg old "$version" '.command=="media-replace" and .report.changed and .report.previous_digest==$old and .report.item.source=="public/月 &a.PNG"' "$tmp/changed" >/dev/null
cmp "$asset" "$tmp/replacement"
cmp "$tmp/replacement" "$tmp/replacement-before"
test "$(stat -c %a "$asset")" = 640
diff -r "$tmp/output-before" "$tmp/out"
reject() { local want="$1" code=0; shift; "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?; test "$code" = "$want"; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
reject 1 "$cli" media-replace "$tmp/site" "$name" "$version" "$tmp/replacement"
grep -Fq 'changed since it was read' "$tmp/stderr"
new="$(jq -r '.report.item.digest' "$tmp/changed")"
reject 1 "$cli" media-replace "$tmp/site" "$name" bad "$tmp/replacement"
for n in missing.png ../outside.png style.css .hidden.png; do
  reject 1 "$cli" media-read "$tmp/site" "$n"
  reject 1 "$cli" media-replace "$tmp/site" "$n" "$new" "$tmp/replacement"
done
ln -s "$tmp/replacement" "$tmp/link"
mkfifo "$tmp/pipe"
for path in "$tmp/link" "$tmp/pipe" "$tmp/site" "$tmp/missing"; do
  reject 1 timeout 5 "$cli" media-replace "$tmp/site" "$name" "$new" "$path"
done
for command in media-read media-replace; do
  "$cli" "$command" --help | grep -Fq "Usage: moonpress $command"
  reject 2 "$cli" "$command"
  grep -Fq "Usage: moonpress $command" "$tmp/stderr"
done
reject 2 "$cli" media-read "$tmp/site" "$name" --include-drafts
reject 2 "$cli" media-read "$tmp/site" "$name" --json --json
reject 2 "$cli" media-replace "$tmp/site" "$name" "$new" "$tmp/replacement" --include-drafts
reject 2 "$cli" media-replace "$tmp/site" "$name" "$new" "$tmp/replacement" --json --json
# Exact filenames may begin with -- without being mistaken for options.
cp "$asset" "$tmp/site/public/--image.png"
"$cli" media-read "$tmp/site" --image.png >/dev/null
"$cli" media-replace "$tmp/site" --image.png "$new" "$tmp/replacement" > "$tmp/text"
grep -Fq 'changed: false' "$tmp/text"
grep -Fq 'No build or deployment performed' "$tmp/text"
reject 2 "$cli" media-replace "$tmp/site" --image.png "$new" "$tmp/replacement" --bad
cmp "$asset" "$tmp/replacement"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cmp "$asset" "$tmp/out/$name"
test ! -e "$tmp/site/public/.moonpress-media-edit"
echo 'Media replacement CLI tests passed: binary metadata/replacement, stale versions, no-op inode/mtime, modes, strict grammar, unsafe files and separate clean/incremental builds.'
