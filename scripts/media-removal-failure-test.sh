#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
mkdir "$tmp/site/public"
printf image > "$tmp/site/public/a.png"
plan() { "$cli" media-removal-plan "$tmp/site" a.png --json | jq -r '.report.review_id'; }
id="$(plan)"
cp -a "$tmp/site" "$tmp/before"
fail() { local status=0; "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?; test "$status" = 1; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
cc -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fail.so"
fail env LD_PRELOAD="$tmp/fail.so" MOONPRESS_TEST_FAIL_REMOVE="$tmp/site/public/a.png" "$cli" media-remove "$tmp/site" a.png "$id" confirm-unscanned-removal
diff -r "$tmp/before" "$tmp/site"
env LD_PRELOAD="$tmp/fail.so" MOONPRESS_TEST_FAIL_REMOVE="$tmp/site/public/a.png" MOONPRESS_REMOVAL_FAILURE_PROBE="$tmp" moon test --target native --filter 'media removal failure descriptor lifecycle probe'
# A failed post-unlink sync cannot be reported as if the image still existed.
fail env LD_PRELOAD="$tmp/fail.so" MOONPRESS_TEST_FAIL_DIR_SYNC="$tmp/site/public" "$cli" media-remove "$tmp/site" a.png "$id" confirm-unscanned-removal
grep -Fq 'Removal is visible, but durability is unconfirmed' "$tmp/stderr"
test ! -e "$tmp/site/public/a.png"
cp "$tmp/before/public/a.png" "$tmp/site/public/a.png"
for kind in symlink fifo directory; do
  rm "$tmp/site/public/a.png"
  case "$kind" in
    symlink) ln -s "$tmp/before/public/a.png" "$tmp/site/public/a.png" ;;
    fifo) mkfifo "$tmp/site/public/a.png" ;;
    directory) mkdir "$tmp/site/public/a.png" ;;
  esac
  fail timeout 10 "$cli" media-remove "$tmp/site" a.png "$id" confirm-unscanned-removal
  if [[ "$kind" = directory ]]; then rmdir "$tmp/site/public/a.png"; else rm "$tmp/site/public/a.png"; fi
  cp "$tmp/before/public/a.png" "$tmp/site/public/a.png"
done
cc -shared -fPIC tests/native/swap_authoring_directory.c -ldl -o "$tmp/swap.so"
for phase in open lock; do
  mkdir "$tmp/foreign-$phase"
  printf foreign > "$tmp/foreign-$phase/a.png"
  fail env LD_PRELOAD="$tmp/swap.so" MOONPRESS_SWAP_PHASE="$phase" MOONPRESS_SWAP_DIRECTORY="$tmp/site/public" MOONPRESS_SWAP_MOVED="$tmp/moved-$phase" MOONPRESS_SWAP_FOREIGN="$tmp/foreign-$phase" "$cli" media-remove "$tmp/site" a.png "$id" confirm-unscanned-removal
  cmp "$tmp/before/public/a.png" "$tmp/moved-$phase/a.png"
  test "$(cat "$tmp/foreign-$phase/a.png")" = foreign
  rm "$tmp/site/public"; mv "$tmp/moved-$phase" "$tmp/site/public"
done
mkdir "$tmp/foreign-cleanup"
printf foreign > "$tmp/foreign-cleanup/a.png"
env LD_PRELOAD="$tmp/swap.so" MOONPRESS_SWAP_PHASE=cleanup MOONPRESS_SWAP_DIRECTORY="$tmp/site/public" MOONPRESS_SWAP_MOVED="$tmp/moved-cleanup" MOONPRESS_SWAP_FOREIGN="$tmp/foreign-cleanup" "$cli" media-remove "$tmp/site" a.png "$id" confirm-unscanned-removal >/dev/null
test ! -e "$tmp/moved-cleanup/a.png"
test "$(cat "$tmp/foreign-cleanup/a.png")" = foreign
rm "$tmp/site/public"; mv "$tmp/moved-cleanup" "$tmp/site/public"
echo 'Media removal faults passed: unlink failure/descriptor closure, special-file refusal, observed directory changes and retained unlink target.'
