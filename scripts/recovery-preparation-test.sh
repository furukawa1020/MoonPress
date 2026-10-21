#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/old" >/dev/null
printf '\nUpdated\n' >> "$tmp/site/content/index.md"
record="$tmp/.moonpress-recovery-$(printf out | sha256sum | cut -d' ' -f1).json"
for state in fresh existing; do
  for point in intent output stage journal payload manifest backup; do
    rm -rf "$tmp/out"
    if [[ "$state" == existing ]]; then cp -a "$tmp/old" "$tmp/out"; fi
    case "$point" in
      intent) injection="MOONPRESS_TEST_KILL_DURING_WRITE=$record" ;;
      output) [[ "$state" == existing ]] && continue; injection="MOONPRESS_TEST_KILL_AFTER_MKDIR=$tmp/out" ;;
      stage) injection="MOONPRESS_TEST_KILL_AFTER_MKDIR=$tmp/out/.moonpress-stage" ;;
      journal) injection="MOONPRESS_TEST_KILL_DURING_WRITE=$tmp/out/.moonpress-stage/journal" ;;
      payload) injection="MOONPRESS_TEST_KILL_DURING_WRITE=$tmp/out/.moonpress-stage/index.html" ;;
      manifest) injection="MOONPRESS_TEST_KILL_DURING_WRITE=$tmp/out/.moonpress-stage/.moonpress.json" ;;
      backup) injection="MOONPRESS_TEST_KILL_AFTER_MKDIR=$tmp/out/.moonpress-stage/backup" ;;
    esac
    status=0
    env LD_PRELOAD="$tmp/fault.so" "$injection" "$cli" build "$tmp/site" "$tmp/out" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
    test "$status" -eq 137
    test ! -s "$tmp/stdout"
    "$cli" recovery-plan "$tmp/out" --json > "$tmp/plan"
    "$cli" recover "$tmp/out" --json > "$tmp/actual"
    jq -S .report "$tmp/plan" > "$tmp/a"; jq -S .report "$tmp/actual" > "$tmp/b"; cmp "$tmp/a" "$tmp/b"
    if [[ "$state" == existing ]]; then diff -r "$tmp/old" "$tmp/out"; else test ! -e "$tmp/out"; fi
    test ! -e "$record"
    "$cli" build "$tmp/site" "$tmp/out" >/dev/null
    test ! -e "$record"
  done
done
echo 'Preparation recovery passed: anonymous intent/payload writes, output/stage/backup mkdir and fresh/existing retry.'
