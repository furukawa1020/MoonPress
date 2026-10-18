#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
id="$("$cli" review "$tmp/site" "$tmp/out" --json | jq -r '.report.review_id')"
cp -a "$tmp/out" "$tmp/pristine"
cp -a "$tmp/site" "$tmp/source"
fail() { local status=0; "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?; test "$status" = 1; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
refuse() { fail timeout 10 "$cli" export "$tmp/site" "$tmp/out" "$id" "$tmp/refused.zip"; test ! -e "$tmp/refused.zip"; }
for unsafe in missing foreign edited symlink fifo oversized manifest; do
  rm -rf "$tmp/out"; cp -a "$tmp/pristine" "$tmp/out"
  case "$unsafe" in
    missing) rm "$tmp/out/index.html" ;;
    foreign) printf foreign > "$tmp/out/foreign.txt" ;;
    edited) printf manual > "$tmp/out/index.html" ;;
    symlink) rm "$tmp/out/index.html"; ln -s "$tmp/pristine/index.html" "$tmp/out/index.html" ;;
    fifo) rm "$tmp/out/index.html"; mkfifo "$tmp/out/index.html" ;;
    oversized) truncate -s 67108865 "$tmp/out/index.html" ;;
    manifest) truncate -s 4194305 "$tmp/out/.moonpress.json" ;;
  esac
  refuse
done
rm -rf "$tmp/out"; cp -a "$tmp/pristine" "$tmp/out"
cc -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fail.so"
for kind in WRITE FLUSH CLOSE; do
  fail env LD_PRELOAD="$tmp/fail.so" "MOONPRESS_TEST_FAIL_$kind=$tmp/fail.zip" "$cli" export "$tmp/site" "$tmp/out" "$id" "$tmp/fail.zip"
  test ! -e "$tmp/fail.zip"
done
for kind in WRITE FLUSH CLOSE; do
  env LD_PRELOAD="$tmp/fail.so" "MOONPRESS_TEST_FAIL_$kind=$tmp/failed.zip" MOONPRESS_EXPORT_FAILURE_PROBE="$tmp" moon test --target native --filter 'export failure descriptor lifecycle probe'
done
cc -shared -fPIC tests/native/swap_authoring_directory.c -ldl -o "$tmp/swap.so"
for phase in open lock create; do
  mkdir "$tmp/dest-$phase" "$tmp/foreign-$phase"
  printf foreign > "$tmp/foreign-$phase/keep"
  env LD_PRELOAD="$tmp/swap.so" MOONPRESS_SWAP_PHASE="$phase" MOONPRESS_SWAP_DIRECTORY="$tmp/dest-$phase" MOONPRESS_SWAP_MOVED="$tmp/moved-$phase" MOONPRESS_SWAP_FOREIGN="$tmp/foreign-$phase" "$cli" export "$tmp/site" "$tmp/out" "$id" "$tmp/dest-$phase/site.zip" >/dev/null
  unzip -t "$tmp/moved-$phase/site.zip" >/dev/null
  test "$(find "$tmp/foreign-$phase" -type f | wc -l)" = 1
  test "$(cat "$tmp/foreign-$phase/keep")" = foreign
done
mkdir "$tmp/cleanup" "$tmp/cleanup-foreign"
fail env LD_PRELOAD="$tmp/fail.so:$tmp/swap.so" MOONPRESS_TEST_FAIL_WRITE="$tmp/cleanup/site.zip" MOONPRESS_SWAP_PHASE=cleanup MOONPRESS_SWAP_DIRECTORY="$tmp/cleanup" MOONPRESS_SWAP_MOVED="$tmp/cleanup-moved" MOONPRESS_SWAP_FOREIGN="$tmp/cleanup-foreign" "$cli" export "$tmp/site" "$tmp/out" "$id" "$tmp/cleanup/site.zip"
test ! -e "$tmp/cleanup-moved/site.zip"
test -z "$(ls -A "$tmp/cleanup-foreign")"
diff -r "$tmp/source" "$tmp/site"
diff -r "$tmp/pristine" "$tmp/out"
echo 'Export failures passed: missing/foreign/edited/unsafe/oversized files, caught write/flush/close cleanup and retained destination across replacement.'
