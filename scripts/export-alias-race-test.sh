#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/a" "$tmp/b"
"$cli" init "$tmp/a/site" >/dev/null
mkdir "$tmp/a/site/public"
cp -a "$tmp/a/site" "$tmp/b/site"
ln -s "$tmp/a" "$tmp/current"
"$cli" build "$tmp/current/site" "$tmp/out" >/dev/null
id="$("$cli" review "$tmp/current/site" "$tmp/out" --json | jq -r '.report.review_id')"
cc -shared -fPIC tests/native/retarget_source_alias.c -ldl -o "$tmp/retarget.so"
status=0
env LD_PRELOAD="$tmp/retarget.so" MOONPRESS_RETARGET_ALIAS="$tmp/current" MOONPRESS_RETARGET_TARGET="$tmp/b" "$cli" export "$tmp/current/site" "$tmp/out" "$id" "$tmp/b/site/public/release.zip" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
test "$status" = 1
test ! -s "$tmp/stdout"
grep -Fq 'Source directory changed' "$tmp/stderr"
test ! -e "$tmp/b/site/public/release.zip"
diff -r "$tmp/a/site" "$tmp/b/site"
echo 'Export alias revalidation passed: retargeting before creation refuses without source mutation.'
