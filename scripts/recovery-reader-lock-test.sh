#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
holder=''
cleanup() { if [[ -n "$holder" ]]; then kill "$holder" 2>/dev/null || true; wait "$holder" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/pause_lock.c -ldl -o "$tmp/pause.so"
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/sibling"
cp -a "$tmp/out" "$tmp/before"
blocked() {
  local status=0
  timeout 5 "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/stdout"
  grep -q busy "$tmp/stderr"
}
for command in recovery-plan recover; do
  rm -f "$tmp/ready" "$tmp/release"
  env LD_PRELOAD="$tmp/pause.so" MOONPRESS_TEST_PAUSE_SHARED=1 \
    MOONPRESS_TEST_LOCK_READY="$tmp/ready" MOONPRESS_TEST_LOCK_RELEASE="$tmp/release" \
    "$cli" "$command" "$tmp/out" --json > "$tmp/holder" 2> "$tmp/holder-error" &
  holder=$!
  for ((i=0; i<500; i++)); do [[ -f "$tmp/ready" ]] && break; sleep 0.01; done
  test -f "$tmp/ready"
  if [[ "$command" == recovery-plan ]]; then
    for output in out sibling; do
      "$cli" recovery-plan "$tmp/$output" --json | jq -e '.report.action == "clean"' >/dev/null
      blocked recover "$tmp/$output" --json
      blocked build "$tmp/site" "$tmp/$output"
    done
  else
    blocked recovery-plan "$tmp/out" --json
    blocked recovery-plan "$tmp/sibling" --json
  fi
  touch "$tmp/release"
  wait "$holder"; holder=''
  test ! -s "$tmp/holder-error"
  diff -r "$tmp/out" "$tmp/before"
  diff -r "$tmp/sibling" "$tmp/before"
done
echo 'Recovery locking passed: shared readers coexist, exclusive writers exclude readers and siblings.'
