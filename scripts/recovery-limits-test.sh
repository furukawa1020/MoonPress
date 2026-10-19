#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp "$tmp/out/.moonpress.json" "$tmp/marker"
reject() {
  local status=0
  timeout 5 "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/stdout"
  grep -q 'exceeds' "$tmp/stderr"
}
# Sparse files exercise the size guard without requiring a large allocation.
truncate -s 4194305 "$tmp/out/.moonpress.json"
cp -a "$tmp/out" "$tmp/before"
reject recovery-plan "$tmp/out" --json
reject recover "$tmp/out" --json
reject build "$tmp/site" "$tmp/out"
diff -r "$tmp/out" "$tmp/before"
cp "$tmp/marker" "$tmp/out/.moonpress.json"
mkdir "$tmp/out/.moonpress-stage"
truncate -s 67108865 "$tmp/out/.moonpress-stage/journal"
for command in recovery-plan recover; do reject "$command" "$tmp/out" --json; done
test "$(stat -c %s "$tmp/out/.moonpress-stage/journal")" = 67108865
cmp "$tmp/marker" "$tmp/out/.moonpress.json"
echo 'Recovery state size limits passed.'
