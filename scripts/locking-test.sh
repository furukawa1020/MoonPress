#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
writer=''
cleanup() {
  if [[ -n "$writer" ]]; then
    kill -KILL "$writer" 2>/dev/null || true
    wait "$writer" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/pause_lock.c -ldl -o "$tmp/pause.so"
mkdir -p "$tmp/site/content" "$tmp/publish" "$tmp/reference"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '# Home\n' > "$tmp/site/content/index.md"
ln -s "$tmp/publish" "$tmp/alias"
start_writer() {
  rm -f "$tmp/ready" "$tmp/release"
  MOONPRESS_TEST_LOCK_READY="$tmp/ready" MOONPRESS_TEST_LOCK_RELEASE="$tmp/release" \
    LD_PRELOAD="$tmp/pause.so" "$cli" build "$tmp/site" "$tmp/publish/out" >"$tmp/first" 2>"$tmp/first-error" &
  writer=$!
  for ((i=0; i<250; i++)); do
    [[ -f "$tmp/ready" ]] && return
    kill -0 "$writer"
    sleep 0.02
  done
  echo 'Timed out waiting for actual CLI lock acquisition' >&2
  exit 1
}
busy() {
  local status=0
  "$cli" "$@" --json >"$tmp/log" 2>"$tmp/error" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/log"
  grep -q 'Output parent is busy' "$tmp/error"
}
start_writer
test ! -e "$tmp/publish/out"
busy build "$tmp/site" "$tmp/publish/./out"
busy build "$tmp/site" "$tmp/alias/out/"
busy explain "$tmp/site" "$tmp/publish/out"
# Conservative scope deliberately serializes siblings as well.
busy build "$tmp/site" "$tmp/publish/other"
"$cli" check "$tmp/site" --json | jq -e '.report.pages == 1' >/dev/null
test -z "$(find "$tmp/publish" -mindepth 1 -print -quit)"
touch "$tmp/release"
wait "$writer"
writer=''
"$cli" build "$tmp/site" "$tmp/reference/clean" >/dev/null
diff -r "$tmp/publish/out" "$tmp/reference/clean"
# Existing output aliases resolve to the same directory identity.
printf '\nChanged\n' >> "$tmp/site/content/index.md"
cp -a "$tmp/publish/out" "$tmp/before"
start_writer
busy build "$tmp/site" "$tmp/publish/out/."
busy build "$tmp/site" "$tmp/alias/out"
diff -r "$tmp/publish/out" "$tmp/before"
# Kernel cleanup on SIGKILL requires no stale-file deletion.
kill -KILL "$writer"
wait "$writer" 2>/dev/null || true
writer=''
diff -r "$tmp/publish/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/publish/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/reference/clean" >/dev/null
diff -r "$tmp/publish/out" "$tmp/reference/clean"
# A successful dry-run neither creates output nor lock metadata.
"$cli" explain "$tmp/site" "$tmp/publish/missing" >/dev/null
test ! -e "$tmp/publish/missing"
test "$(find "$tmp/publish" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1
"$cli" build "$tmp/site" "$tmp/publish/out" --json | jq -e '.report.written == 0' >/dev/null
echo 'Locking tests passed: real competing writers, aliases, shared scope, crash release, dry-run and clean parity.'
