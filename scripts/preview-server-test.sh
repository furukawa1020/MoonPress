#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
cleanup() {
  if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
mkdir "$tmp/site/public"
printf 'image\000bytes' > "$tmp/site/public/a.png"
printf font > "$tmp/site/public/font.ttf"
printf font > "$tmp/site/public/font.otf"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/before"
for attempt in {1..10}; do
  port="$(shuf -i 20000-55000 -n 1)"
  "$cli" preview "$tmp/out" "$port" > "$tmp/log" 2> "$tmp/error" &
  server=$!
  for ((i=0; i<50; i++)); do
    grep -Fq 'MoonPress preview:' "$tmp/log" && break
    kill -0 "$server" 2>/dev/null || break
    sleep 0.02
  done
  if grep -Fq 'MoonPress preview:' "$tmp/log"; then break; fi
  wait "$server" || true
  server=''
done
test -n "$server"
origin="http://127.0.0.1:$port"
get() { curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' "$origin$1"; }
post() { local path="$1"; shift; curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" "$@" "$origin$path"; }
test "$(get /)" = 200
cmp "$tmp/page" "$tmp/out/index.html"
test "$(get /style.css)" = 200
cmp "$tmp/page" "$tmp/out/style.css"
test "$(get /a.png)" = 200
cmp "$tmp/page" "$tmp/site/public/a.png"
curl -sS -D "$tmp/headers" -o /dev/null "$origin/"
grep -Fq "form-action 'none'" "$tmp/headers"
grep -Fq 'Cache-Control: no-store' "$tmp/headers"
for type in ttf otf; do
  curl -sS -D "$tmp/headers" -o "$tmp/view-font" "$origin/font.$type"
  grep -Fq "Content-Type: font/$type" "$tmp/headers"
  ! grep -Fq "Content-Disposition: attachment" "$tmp/headers"
done
test "$(get /missing.html)" = 404
for path in '/.moonpress.json' '/%2e%2e' '/a%2fb' '/%00' '/%FF'; do test "$(get "$path")" = 400; done
test "$(curl -sS -o "$tmp/page" -w '%{http_code}' -H 'Host: evil' "$origin/")" = 400
test "$(post /save --data 'token=anything')" = 400
diff -r "$tmp/out" "$tmp/before"
printf 'private' > "$tmp/out/foreign.html"
test "$(get /foreign.html)" = 404
printf 'manual edit' > "$tmp/out/index.html"
test "$(get /)" = 400
! grep -Fq 'manual edit' "$tmp/page"
rm "$tmp/out/index.html"
ln -s "$tmp/before/index.html" "$tmp/out/index.html"
test "$(get /)" = 400
rm "$tmp/out/index.html" "$tmp/out/foreign.html"
cp "$tmp/before/index.html" "$tmp/out/index.html"
"$cli" new "$tmp/site" private 'Private draft' >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --include-drafts >/dev/null
test "$(get /private.html)" = 200
grep -Fq 'Private draft' "$tmp/page"
for args in '--json' '--include-drafts'; do
  code=0; "$cli" preview "$tmp/out" "$port" "$args" >/dev/null 2>&1 || code=$?; test "$code" = 2
done
echo 'Preview HTTP tests passed: HTML/CSS/binary links, verified manifest-only serving, unsafe request/file refusal, no writes and refreshed builds.'
