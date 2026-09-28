#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
for fault in WRITE FLUSH; do
  for mode in legacy-write write; do
    env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$fault=$tmp/probe" \
      MOONPRESS_IO_PROBE="$tmp/probe" MOONPRESS_IO_MODE="$mode" \
      moon test --target native --package furukawa1020/moonpress --file io_wbtest.mbt
  done
done
env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_CLOSE=$tmp/probe" \
  MOONPRESS_IO_PROBE="$tmp/probe" MOONPRESS_IO_MODE=write \
  moon test --target native --package furukawa1020/moonpress --file io_wbtest.mbt
echo 'I/O cleanup tests passed: reproduced legacy leaks; zero growth on write/flush/close errors.'
