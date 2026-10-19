#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
cleanup() { if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
for attempt in {1..10}; do
  port="$(shuf -i 20000-55000 -n 1)"
  "$cli" admin "$tmp/site" "$port" > "$tmp/log" 2> "$tmp/error" & server=$!
  for ((i=0; i<50; i++)); do grep -Fq 'MoonPress admin:' "$tmp/log" && break; kill -0 "$server" 2>/dev/null || break; sleep 0.02; done
  if grep -Fq 'MoonPress admin:' "$tmp/log"; then break; fi
  wait "$server" || true; server=''
done
test -n "$server"
origin="http://127.0.0.1:$port"
get() { curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' "$origin$1"; }
test "$(get /recovery)" = 200
grep -Fq 'No production output exists yet' "$tmp/page"
test ! -e "$tmp/site/.moonpress-build"
"$cli" build "$tmp/site" "$tmp/site/.moonpress-build" >/dev/null
test "$(get /recovery)" = 200
grep -Fq 'No interrupted publication was found' "$tmp/page"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
printf '# Added\n' > "$tmp/site/content/added.md"
status=0
env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_KILL_BEFORE_RENAME=$tmp/site/.moonpress-build/.moonpress.json" \
  "$cli" build "$tmp/site" "$tmp/site/.moonpress-build" >/dev/null 2>&1 || status=$?
test "$status" -eq 137
cp -a "$tmp/site" "$tmp/before"
test "$(get /recovery)" = 200
grep -Fq 'Recovery would restore the previous output state' "$tmp/page"
grep -Fq 'No files were changed' "$tmp/page"
! grep -Fq '<form' "$tmp/page"
test "$(get /publish)" = 400
grep -Fq 'href="/recovery"' "$tmp/page"
test "$(get '/recovery?output=elsewhere')" = 404
test "$(curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" --data token=invalid "$origin/recovery")" = 400
diff -r "$tmp/site" "$tmp/before"
printf unknown > "$tmp/site/.moonpress-build/<script>.html"
test "$(get /recovery)" = 400
grep -Fq '&lt;script&gt;.html' "$tmp/page"
! grep -Fq '<script>' "$tmp/page"
test -f "$tmp/site/.moonpress-build/<script>.html"
rm "$tmp/site/.moonpress-build/<script>.html"
"$cli" recover "$tmp/site/.moonpress-build" >/dev/null
test "$(get /recovery)" = 200
grep -Fq 'No interrupted publication was found' "$tmp/page"
echo 'Admin recovery diagnostics passed: absent/clean/interrupted/refused states, escaping and read-only routing.'
