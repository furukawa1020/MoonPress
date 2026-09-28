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
      moon test --target native --package furukawa1020/moonpress --file io_wbtest.mbt --index 0
  done
done
env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_CLOSE=$tmp/probe" \
  MOONPRESS_IO_PROBE="$tmp/probe" MOONPRESS_IO_MODE=write \
  moon test --target native --package furukawa1020/moonpress --file io_wbtest.mbt --index 0
echo 'I/O cleanup tests passed: reproduced legacy leaks; zero growth on write/flush/close errors.'
printf '0123456789abcdef' > "$tmp/probe"
for fault in READ SEEK SIZE; do
  for mode in legacy-read read; do
    env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$fault=$tmp/probe" \
      MOONPRESS_IO_PROBE="$tmp/probe" MOONPRESS_IO_MODE="$mode" \
      moon test --target native --package furukawa1020/moonpress --file io_wbtest.mbt --index 0
  done
done
env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_CLOSE=$tmp/probe" \
  MOONPRESS_IO_PROBE="$tmp/probe" MOONPRESS_IO_MODE=read \
  moon test --target native --package furukawa1020/moonpress --file io_wbtest.mbt --index 0
echo 'Reader cleanup tests passed: reproduced legacy leaks; zero growth on read/seek/size/close errors.'

# Cleanup failure must not replace the original read/write diagnostic.
for operation in READ WRITE; do
  mode="${operation,,}"
  env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$operation=$tmp/probe" \
    "MOONPRESS_TEST_FAIL_CLOSE=$tmp/probe" MOONPRESS_IO_PROBE="$tmp/probe" \
    MOONPRESS_IO_MODE="$mode" MOONPRESS_IO_EXPECT_ERROR="File $mode" \
    moon test --target native --package furukawa1020/moonpress --file io_wbtest.mbt --index 0
done
env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_SIZE_LIMIT=$tmp/probe" \
  MOONPRESS_IO_PROBE="$tmp/probe" MOONPRESS_IO_MODE=read \
  MOONPRESS_IO_EXPECT_ERROR="exceeds supported byte-buffer length" \
  moon test --target native --package furukawa1020/moonpress --file io_wbtest.mbt --index 0
