#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
record="$tmp/.moonpress-recovery-$(printf out | sha256sum | cut -d' ' -f1).json"
crash() {
  local injection="$1" status=0
  shift
  env LD_PRELOAD="$tmp/fault.so" "$injection" "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" -eq 137
}
for boundary in 'REMOVE=.moonpress-stage/journal' 'RMDIR=.moonpress-stage'; do
  kind="${boundary%%=*}"; path="${boundary#*=}"
  crash "MOONPRESS_TEST_KILL_AFTER_$kind=$tmp/out/$path" build "$tmp/site" "$tmp/out"
  test -s "$record"
  "$cli" recovery-plan "$tmp/out/" --json | jq -e '.report.action == "finalized"' >/dev/null
  "$cli" recover "$tmp/out/." --json | jq -e '.report.action == "finalized"' >/dev/null
  test ! -e "$record"
  diff -r "$tmp/clean" "$tmp/out"
  rm -rf "$tmp/out"
done
# Fresh rollback remains retryable even after the output itself disappears.
for path in "$tmp/out/.moonpress-stage" "$tmp/out"; do
  crash "MOONPRESS_TEST_KILL_BEFORE_RENAME=$tmp/out/.moonpress.json" build "$tmp/site" "$tmp/out"
  crash "MOONPRESS_TEST_KILL_AFTER_RMDIR=$path" recover "$tmp/out"
  test -s "$record"
  "$cli" recovery-plan "$tmp/out" --json | jq -e '.report.action == "rolled_back"' >/dev/null
  "$cli" recover "$tmp/out" --json | jq -e '.report.action == "rolled_back"' >/dev/null
  test ! -e "$tmp/out"
  test ! -e "$record"
done
# A foreign sibling record is never overwritten, including for a new output.
printf precious > "$record"
for command in 'build' 'recover' 'recovery-plan'; do
  status=0
  if [[ "$command" == build ]]; then
    "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
  else
    "$cli" "$command" "$tmp/out" >/dev/null 2>&1 || status=$?
  fi
  test "$status" -eq 1
  test "$(cat "$record")" = precious
  test ! -e "$tmp/out"
done
echo 'Recovery cleanup windows passed: journal unlink, stage rmdir, fresh output rmdir, aliases and foreign-record protection.'
