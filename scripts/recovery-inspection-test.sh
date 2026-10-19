#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/old" >/dev/null
printf '\nUpdated\n' >> "$tmp/site/content/welcome.md"
for phase in BEFORE AFTER; do
  cp -a "$tmp/old" "$tmp/out"
  status=0
  env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_KILL_${phase}_RENAME=$tmp/out/.moonpress.json" \
    "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
  test "$status" -eq 137
  find "$tmp/out" -printf '%P %y %i %m %s %T@\n' | sort > "$tmp/before"
  find "$tmp/out" -type f -exec sha256sum {} + | sort >> "$tmp/before"
  MOONPRESS_INSPECT_ONLY=1 MOONPRESS_RECOVERY_INSPECTION="$tmp/out" moon test --target native --filter 'recovery inspection filesystem probe'
  find "$tmp/out" -printf '%P %y %i %m %s %T@\n' | sort > "$tmp/after"
  find "$tmp/out" -type f -exec sha256sum {} + | sort >> "$tmp/after"
  cmp "$tmp/before" "$tmp/after"
  MOONPRESS_RECOVERY_INSPECTION="$tmp/out" moon test --target native --filter 'recovery inspection filesystem probe'
  test ! -e "$tmp/out/.moonpress-stage"
  if [[ "$phase" == BEFORE ]]; then diff -r "$tmp/old" "$tmp/out"; fi
  rm -rf "$tmp/out"
done
MOONPRESS_RECOVERY_INSPECTION="$tmp/absent" moon test --target native --filter 'recovery inspection filesystem probe'
MOONPRESS_RECOVERY_INSPECTION="$tmp/old" moon test --target native --filter 'recovery inspection filesystem probe'
echo 'Recovery inspection API tests passed.'
