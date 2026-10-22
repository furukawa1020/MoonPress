#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
pid=''
cleanup() { if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
mkdir "$tmp/site/public"
asset="$tmp/site/public/a.png"
stage="$tmp/site/public/.moonpress-media-edit"
printf '\000\377old bytes' > "$asset"
printf '\377\000new bytes' > "$tmp/replacement"
printf 'second replacement' > "$tmp/second"
cp "$tmp/replacement" "$tmp/replacement-before"
chmod 640 "$asset"
touch -t 200001010000 "$asset"
cp -a "$tmp/site" "$tmp/before"
version="$("$cli" media-read "$tmp/site" a.png --json | jq -r '.report.digest')"
metadata="$(stat -c '%i %a %Y' "$asset")"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/pause_lock.c -ldl -o "$tmp/pause.so"
failure() { local expected="$1" code=0; shift; "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?; test "$code" = "$expected"; test ! -s "$tmp/stdout"; if [[ "$expected" != 137 ]]; then test -s "$tmp/stderr"; fi; }
unchanged() { diff -r "$tmp/before" "$tmp/site"; test "$(stat -c '%i %a %Y' "$asset")" = "$metadata"; }
for fault in OPEN WRITE FLUSH EXISTING_SYNC CLOSE; do
  failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$fault=$stage" "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement" --json
  test ! -e "$stage"
  unchanged
done
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_RENAME=$asset" "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement" --json
unchanged
# An exclusive-open race must preserve the file created by another writer.
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_CREATE_BEFORE_OPEN=$stage" "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement"
test "$(cat "$stage")" = 'competing writer'
cmp "$asset" "$tmp/before/public/a.png"
rm "$stage"
unchanged
# Cleanup failures retain evidence and block retry, even an identical-byte no-op.
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_WRITE=$stage" "MOONPRESS_TEST_FAIL_REMOVE=$stage" "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement"
grep -Fq 'cleanup incomplete' "$tmp/stderr"
test -f "$stage"
failure 1 "$cli" media-replace "$tmp/site" a.png "$version" "$asset"
grep -Fq 'staging path already exists' "$tmp/stderr"
cmp "$asset" "$tmp/before/public/a.png"
rm "$stage"
unchanged
# Unreadable staged evidence is retained, never published or deleted.
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_READ=$stage" "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement"
grep -Fq 'staging could not be verified' "$tmp/stderr"
cmp "$stage" "$tmp/replacement"
cmp "$asset" "$tmp/before/public/a.png"
rm "$stage"
unchanged
# A real process interruption before rename leaves old output and a refused remnant.
failure 137 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_KILL_BEFORE_RENAME=$asset" "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement"
cmp "$stage" "$tmp/replacement"
cmp "$asset" "$tmp/before/public/a.png"
failure 1 "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement"
rm "$stage"
unchanged
# Final target recheck preserves a noncooperating editor's observed change.
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_EDIT_ON_CLOSE=$stage" "MOONPRESS_TEST_EDIT_TARGET=$asset" "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement"
test "$(cat "$asset")" = '# External edit'
test ! -e "$stage"
cp "$tmp/before/public/a.png" "$asset"
pause_replace() {
  rm -f "$tmp/ready" "$tmp/release"
  env LD_PRELOAD="$tmp/pause.so" MOONPRESS_TEST_LOCK_READY="$tmp/ready" MOONPRESS_TEST_LOCK_RELEASE="$tmp/release" "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/replacement" --json > "$tmp/paused-out" 2> "$tmp/paused-err" &
  pid=$!
  for ((i=0; i<200; i++)); do
    test -e "$tmp/ready" && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.02
  done
  test -e "$tmp/ready"
}
release_replace() {
  local expected="$1" code=0
  touch "$tmp/release"
  wait "$pid" || code=$?
  pid=''
  test "$code" = "$expected"
}
# Two cooperative operations cannot publish concurrently; retry of the loser is stale.
pause_replace
failure 1 "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/second"
grep -Fq 'busy with another MoonPress operation' "$tmp/stderr"
release_replace 0
cmp "$asset" "$tmp/replacement"
failure 1 "$cli" media-replace "$tmp/site" a.png "$version" "$tmp/second"
grep -Fq 'changed since it was read' "$tmp/stderr"
cmp "$asset" "$tmp/replacement"
# Recheck after acquiring the lock catches external changes before staging too.
cp "$tmp/before/public/a.png" "$asset"
pause_replace
printf 'external edit while locked' > "$asset"
release_replace 1
test ! -s "$tmp/paused-out"
grep -Fq 'changed since it was read' "$tmp/paused-err"
test "$(cat "$asset")" = 'external edit while locked'
test ! -e "$stage"
current="$("$cli" media-read "$tmp/site" a.png --json | jq -r '.report.digest')"
"$cli" media-replace "$tmp/site" a.png "$current" "$tmp/replacement" --json > "$tmp/final"
cmp "$tmp/replacement" "$tmp/replacement-before"
test "$(jq -r '.report.item.digest' "$tmp/final")" = "$(sha256sum "$asset" | cut -d ' ' -f1)"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
current="$(jq -r '.report.item.digest' "$tmp/final")"
"$cli" media-replace "$tmp/site" a.png "$current" "$tmp/second" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cmp "$tmp/out/a.png" "$tmp/second"
echo 'Media replacement fault tests passed: preparation/rename/cleanup/read failures, exclusive races, SIGKILL remnant refusal, target edits, cooperative contention, locked recheck and clean/incremental equality.'
