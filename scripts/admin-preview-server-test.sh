#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
other=''
cleanup() {
  if [[ -n "$other" ]]; then kill "$other" 2>/dev/null || true; wait "$other" 2>/dev/null || true; fi
  if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
for attempt in {1..10}; do
  port="$(shuf -i 20000-55000 -n 1)"
  "$cli" admin "$tmp/site" "$port" > "$tmp/log" 2> "$tmp/error" &
  server=$!
  for ((i=0; i<50; i++)); do
    grep -Fq 'MoonPress admin:' "$tmp/log" && break
    kill -0 "$server" 2>/dev/null || break
    sleep 0.02
  done
  if grep -Fq 'MoonPress admin:' "$tmp/log"; then break; fi
  wait "$server" || true
  server=''
done
test -n "$server"
origin="http://127.0.0.1:$port"
get() { curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' "$origin$1"; }
post() { local path="$1"; shift; curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" "$@" "$origin$path"; }
preview="http://127.0.0.1:$((port+1))"
view() { curl --max-time 8 -sS -o "$tmp/view" -w '%{http_code}' "$preview$1"; }
test "$(get /workflow)" = 200
grep -Fq "href=\"$preview/\"" "$tmp/page"
token="$(sed -n 's/.*name="token" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")"
test "$(view /)" = 400
test ! -e "$tmp/site/.moonpress-preview"
test "$(post /build-preview --data-urlencode "token=$token")" = 200
grep -Fq 'Open built preview' "$tmp/page"
test "$(view /)" = 200
cmp "$tmp/view" "$tmp/site/.moonpress-preview/index.html"
! grep -Fq "$token" "$tmp/view"
test "$(view /style.css)" = 200
test "$(get /index.html)" = 404
test "$(view /workflow)" = 404
test "$(curl -sS -o "$tmp/view" -w '%{http_code}' -H "Origin: $origin" --data-urlencode "token=$token" "$preview/build-preview")" = 400
"$cli" new "$tmp/site" private 'Private preview' >/dev/null
test "$(view /private.html)" = 404
test "$(post /build-preview --data-urlencode "token=$token")" = 200
test "$(view /private.html)" = 200
grep -Fq 'Private preview' "$tmp/view"
# Preview alone occupies the next port: admin must fail without leaving its listener.
other_port="$(shuf -i 20000-55000 -n 1)"
"$cli" preview "$tmp/site/.moonpress-preview" "$other_port" > "$tmp/other-log" 2> "$tmp/other-error" &
other=$!
for ((i=0;i<50;i++)); do grep -Fq 'MoonPress preview:' "$tmp/other-log" && break; sleep .02; done
code=0
"$cli" admin "$tmp/site" "$((other_port-1))" > "$tmp/failed-out" 2> "$tmp/failed-error" || code=$?
test "$code" = 1
grep -Fq 'Cannot bind preview' "$tmp/failed-error"
kill "$other"; wait "$other" || true; other=''
code=0; "$cli" admin "$tmp/site" 65535 > /dev/null 2>&1 || code=$?; test "$code" = 2
kill "$server"; wait "$server" || true; server=''
if curl --max-time 1 -s "$preview/" >/dev/null; then exit 1; fi
echo 'Admin preview tests passed: separate origins, build/open/rebuild, hidden token, no admin routes or writes on preview and shared lifecycle.'
