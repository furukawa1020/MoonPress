#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
MOONPRESS_ATOMIC_PROBE="$tmp/atomic" moon test --target native --filter 'anonymous publication filesystem probe'
for operation in OPEN WRITE FLUSH CLOSE INSTALL; do
  env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$operation=$tmp/atomic" MOONPRESS_ATOMIC_FAIL=1 MOONPRESS_ATOMIC_PROBE="$tmp/atomic" \
    moon test --target native --filter 'anonymous publication filesystem probe'
done
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_UNSUPPORTED_ANONYMOUS=1 MOONPRESS_ATOMIC_FAIL=1 MOONPRESS_ATOMIC_PROBE="$tmp/atomic" \
  moon test --target native --filter 'anonymous publication filesystem probe'
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/before"
printf '\nChanged\n' >> "$tmp/site/content/index.md"
record="$tmp/.moonpress-recovery-$(printf out | sha256sum | cut -d' ' -f1).json"
for injection in MOONPRESS_TEST_UNSUPPORTED_ANONYMOUS=1 "MOONPRESS_TEST_FAIL_INSTALL=$record"; do
  status=0
  env LD_PRELOAD="$tmp/fault.so" "$injection" "$cli" build "$tmp/site" "$tmp/out" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/stdout"
  test ! -e "$record"
  diff -r "$tmp/out" "$tmp/before"
done
echo 'Anonymous publication passed: binary/empty/exclusive writes, repeated I/O faults, descriptor cleanup and pre-mutation capability failure.'
