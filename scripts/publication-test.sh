#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
mkdir -p "$tmp/site/content"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
for name in a z obsolete; do printf '# %s\n\nOriginal\n' "$name" > "$tmp/site/content/$name.md"; done
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/old"
for name in a z; do printf '\nChanged\n' >> "$tmp/site/content/$name.md"; done
rm "$tmp/site/content/obsolete.md"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
reset_output() {
  rm -rf "$tmp/out"
  cp -a "$tmp/old" "$tmp/out"
}
fail() {
  local status=0
  env LD_PRELOAD="$tmp/fault.so" "$@" "$cli" build "$tmp/site" "$tmp/out" --json >"$tmp/log" 2>"$tmp/error" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/log"
  test ! -e "$tmp/out/.moonpress-stage"
}
# Late-stage short writes and manifest preparation failures preserve all old files.
for injection in \
  "MOONPRESS_TEST_FAIL_WRITE=$tmp/out/.moonpress-stage/z.html" \
  "MOONPRESS_TEST_FAIL_OPEN=$tmp/out/.moonpress-stage/.moonpress.json"; do
  reset_output
  fail "$injection"
  grep -q 'Staging failed before existing artifacts were changed' "$tmp/error"
  diff -r "$tmp/out" "$tmp/old"
  # The lock and stage have been released, allowing a normal retry.
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
  diff -r "$tmp/out" "$tmp/clean"
done
# Each rename exposes a complete old or new file, but the batch is not atomic.
reset_output
fail "MOONPRESS_TEST_FAIL_RENAME=$tmp/out/z.html"
grep -q 'Publication failed' "$tmp/error"
cmp "$tmp/out/a.html" "$tmp/clean/a.html"
cmp "$tmp/out/z.html" "$tmp/old/z.html"
cmp "$tmp/out/.moonpress.json" "$tmp/old/.moonpress.json"
test -f "$tmp/out/obsolete.html"
cp -a "$tmp/out" "$tmp/partial"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
grep -q 'Output was edited outside MoonPress' "$tmp/error"
diff -r "$tmp/out" "$tmp/partial"
# Failure deleting stale output also leaves the previous manifest uncommitted.
reset_output
fail "MOONPRESS_TEST_FAIL_REMOVE=$tmp/out/obsolete.html"
test -f "$tmp/out/obsolete.html"
cmp "$tmp/out/.moonpress.json" "$tmp/old/.moonpress.json"
# A failed manifest rename cannot truncate the previously committed state.
reset_output
fail "MOONPRESS_TEST_FAIL_RENAME=$tmp/out/.moonpress.json"
cmp "$tmp/out/.moonpress.json" "$tmp/old/.moonpress.json"
cmp "$tmp/out/a.html" "$tmp/clean/a.html"
test ! -e "$tmp/out/obsolete.html"
# Never delete a preexisting staging entry, even if it resembles crash debris.
reset_output
mkdir "$tmp/out/.moonpress-stage"
printf 'keep me' > "$tmp/out/.moonpress-stage/precious"
if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/error"; then exit 1; fi
test "$(cat "$tmp/out/.moonpress-stage/precious")" = 'keep me'
# Fresh-output staging failures clean the newly-created empty output too.
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_OPEN="$tmp/fresh/.moonpress-stage/.moonpress.json" \
  "$cli" build "$tmp/site" "$tmp/fresh" >/dev/null 2>"$tmp/error" || status=$?
test "$status" -eq 1
test ! -e "$tmp/fresh"
# Failure creating staging cannot leave a newly-created empty output behind.
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_MKDIR="$tmp/fresh/.moonpress-stage" \
  "$cli" build "$tmp/site" "$tmp/fresh" >/dev/null 2>"$tmp/error" || status=$?
test "$status" -eq 1
test ! -e "$tmp/fresh"
# Successful no-op builds preserve file mtimes and do not allocate staging.
reset_output
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_OPEN="$tmp/out/.moonpress-stage/.moonpress.json" \
  "$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
test "$(stat -c %Y "$tmp/out/a.html")" -eq 946684800
test "$(stat -c %Y "$tmp/out/.moonpress.json")" -eq 946684800
test ! -e "$tmp/out/.moonpress-stage"
echo 'Publication tests passed: short-write preservation, retry, rename/delete/manifest faults, owned cleanup, no-op and clean parity.'
