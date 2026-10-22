#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
mkdir "$tmp/destination"
export MOONPRESS_AUTHORING_ATOMIC_PROBE="$tmp/destination"
moon test --target native --filter 'anonymous authoring filesystem probe'
for operation in OPEN WRITE FLUSH SYNC CLOSE INSTALL; do
  env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$operation=$tmp/destination/atomic" MOONPRESS_ATOMIC_FAIL=1 moon test --target native --filter 'anonymous authoring filesystem probe'
done
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_UNSUPPORTED_ANONYMOUS=1 MOONPRESS_ATOMIC_FAIL=1 moon test --target native --filter 'anonymous authoring filesystem probe'
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_CREATE_BEFORE_LINK="$tmp/destination/atomic" MOONPRESS_ATOMIC_VISIBLE=race moon test --target native --filter 'anonymous authoring filesystem probe'
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_DIR_SYNC="$tmp/destination" MOONPRESS_ATOMIC_VISIBLE=commit moon test --target native --filter 'anonymous authoring filesystem probe'
code=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_DURING_WRITE="$tmp/destination/atomic" MOONPRESS_ATOMIC_FAIL=1 moon test --target native --filter 'anonymous authoring filesystem probe' > "$tmp/killed" 2>&1 || code=$?
test "$code" != 0
test ! -e "$tmp/destination/atomic"
# Restart can create normally: no named partial file, stale lock or staging debris.
moon test --target native --filter 'anonymous authoring filesystem probe'
echo 'Anonymous authoring passed: empty/binary/exclusive writes, pre-install failures and descriptor cleanup.'
