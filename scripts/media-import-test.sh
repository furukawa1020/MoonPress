#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
printf '\000\377\001source bytes' > "$tmp/source"
reject() {
  local status=0
  "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" = 1
  test ! -s "$tmp/stdout"
}
reject "$cli" import "$tmp/site" "$tmp/source" photo.png --json
test ! -e "$tmp/site/public"
mkdir "$tmp/site/public"
cp "$tmp/source" "$tmp/source-before"
"$cli" import "$tmp/site" "$tmp/source" '月 (a).PNG' --json > "$tmp/report"
jq -e '.command=="import" and .report.source=="public/月 (a).PNG" and .report.image==true' "$tmp/report" >/dev/null
cmp "$tmp/source" "$tmp/site/public/月 (a).PNG"
cp -a "$tmp/site" "$tmp/before"
reject "$cli" import "$tmp/site" "$tmp/source" '月 (a).PNG' --json
for name in '../bad.png' 'bad.js' 'style.css' 'sitemap.xml' 'rss.xml' '.hidden.png'; do
  reject "$cli" import "$tmp/site" "$tmp/source" "$name" --json
done
ln -s "$tmp/source" "$tmp/link"
mkfifo "$tmp/pipe"
for path in "$tmp/link" "$tmp/pipe" "$tmp/missing" "$tmp/site"; do
  reject timeout 5 "$cli" import "$tmp/site" "$path" bad.png --json
done
ln -s "$tmp/source" "$tmp/site/public/link.png"
reject "$cli" import "$tmp/site" "$tmp/source" link.png
rm "$tmp/site/public/link.png"
diff -r "$tmp/site" "$tmp/before"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
for fault in OPEN WRITE FLUSH SYNC CLOSE INSTALL; do
  reject env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$fault=$tmp/site/public/fail.png" "$cli" import "$tmp/site" "$tmp/source" fail.png --json
  test ! -e "$tmp/site/public/fail.png"
  diff -r "$tmp/site" "$tmp/before"
done
reject env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_CREATE_BEFORE_LINK=$tmp/site/public/race.png" "$cli" import "$tmp/site" "$tmp/source" race.png --json
test "$(cat "$tmp/site/public/race.png")" = 'competing writer'
rm "$tmp/site/public/race.png"
reject env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_WRITE=$tmp/site/public/fail.png" "MOONPRESS_TEST_FAIL_REMOVE=$tmp/site/public/fail.png" "$cli" import "$tmp/site" "$tmp/source" fail.png --json
test ! -e "$tmp/site/public/fail.png"
code=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_DURING_WRITE="$tmp/site/public/interrupted.png" "$cli" import "$tmp/site" "$tmp/source" interrupted.png >/dev/null 2>&1 || code=$?
test "$code" = 137
test ! -e "$tmp/site/public/interrupted.png"
"$cli" import "$tmp/site" "$tmp/source" interrupted.png >/dev/null
cmp "$tmp/source" "$tmp/site/public/interrupted.png"
rm "$tmp/site/public/interrupted.png"
reject env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_DIR_SYNC="$tmp/site/public" "$cli" import "$tmp/site" "$tmp/source" uncertain.png
grep -Fq 'Creation is visible, but durability is unconfirmed' "$tmp/stderr"
cmp "$tmp/source" "$tmp/site/public/uncertain.png"
rm "$tmp/site/public/uncertain.png"
cmp "$tmp/source" "$tmp/source-before"
diff -r "$tmp/site" "$tmp/before"
"$cli" import --help | grep -Fq 'No --include-drafts option'
for args in --include-drafts --bad; do
  if "$cli" import "$tmp/site" "$tmp/source" a.png "$args" > "$tmp/args" 2>&1; then exit 1; else test "$?" = 2; fi
done
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cmp "$tmp/source" "$tmp/out/月 (a).PNG"
echo 'Media import tests passed: binary preservation, exclusive creation, unsafe paths/names, fault cleanup, competing writer and CLI grammar.'
