#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/old"
printf '\nDurable update\n' >> "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/new" >/dev/null
record="$tmp/.moonpress-recovery-$(printf out | sha256sum | cut -d' ' -f1).json"
# output barriers: preparation, artifacts before manifest, committed manifest, cleanup.
for nth in 2 3 4; do
  rm -rf "$tmp/out"
  cp -a "$tmp/old" "$tmp/out"
  status=0
  env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_EXISTING_SYNC="$tmp/out" MOONPRESS_TEST_FAIL_SYNC_ON_CALL="$nth" "$cli" build "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
  test "$status" -eq 1
  if [[ "$nth" = 3 ]]; then
    test -f "$record"
    test -f "$tmp/out/.moonpress-stage/backup/index.html"
  fi
  "$cli" recover "$tmp/out" >/dev/null
  if [[ "$nth" = 2 ]]; then diff -r "$tmp/old" "$tmp/out"; else diff -r "$tmp/new" "$tmp/out"; fi
  test ! -e "$record"
done
for nth in 2 3 4; do
  rm -rf "$tmp/out"
  cp -a "$tmp/old" "$tmp/out"
  status=0
  env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_AFTER_SYNC="$tmp/out" MOONPRESS_TEST_KILL_SYNC_ON_CALL="$nth" "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
  test "$status" -eq 137
  "$cli" recover "$tmp/out" >/dev/null
  if [[ "$nth" = 2 ]]; then diff -r "$tmp/old" "$tmp/out"; else diff -r "$tmp/new" "$tmp/out"; fi
  test ! -e "$record"
done
# A failed recovery barrier retains intent and is retryable.
rm -rf "$tmp/out"
cp -a "$tmp/old" "$tmp/out"
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_AFTER_RENAME="$tmp/out/index.html" "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 137
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_DIR_SYNC="$tmp/out" "$cli" recover "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 1
test -f "$record"
"$cli" recover "$tmp/out" >/dev/null
diff -r "$tmp/old" "$tmp/out"
# Repeated cleanup barrier failure must not forget the record after stage removal.
rm -rf "$tmp/out"
cp -a "$tmp/old" "$tmp/out"
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_EXISTING_SYNC="$tmp/out" MOONPRESS_TEST_FAIL_SYNC_ON_CALL=4 MOONPRESS_TEST_FAIL_SYNC_FROM_CALL=1 "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 1
test -f "$record"
test ! -e "$tmp/out/.moonpress-stage"
"$cli" recover "$tmp/out" >/dev/null
diff -r "$tmp/new" "$tmp/out"
test ! -e "$record"
echo 'Commit synchronization passed: pre-commit rollback, uncertain commit retention, cleanup/recovery barriers and process restart.'
