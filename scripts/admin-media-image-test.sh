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
name='月&a.png'
asset="$tmp/site/public/$name"
printf '\211PNG\r\n\032\nimage' > "$asset"
printf '\377\000new' > "$tmp/replacement"
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
version="$(sha256sum "$asset" | cut -d ' ' -f1)"
route="/media-image?name=%E6%9C%88%26a.png&version=$version"
cp -a "$tmp/site" "$tmp/before"
test "$(get /media)" = 200
grep -Fq "src=\"/media-image?name=%E6%9C%88%26a.png&amp;version=$version\"" "$tmp/page"
grep -Fq 'loading="lazy"' "$tmp/page"
test "$(get '/media-replace?name=%E6%9C%88%26a.png')" = 200
grep -Fq "src=\"/media-image?name=%E6%9C%88%26a.png&amp;version=$version\"" "$tmp/page"
test "$(get "$route")" = 200
cmp "$asset" "$tmp/page"
curl -sS -D "$tmp/headers" -o /dev/null "$origin$route"
for header in 'Content-Type: image/png' 'Cache-Control: no-store' 'X-Content-Type-Options: nosniff' 'Cross-Origin-Resource-Policy: same-origin' "default-src 'none'; sandbox"; do grep -Fq "$header" "$tmp/headers"; done
for path in '/media-image' '/media-image?name=a.png' "$route&extra=x" "$route&name=x" '/media-image?name=..%2Fsecret&version=bad' '/media-image?name=a.svg&version=bad'; do test "$(get "$path")" = 400; done
test "$(curl -sS -H 'Host: evil' -o "$tmp/page" -w '%{http_code}' "$origin$route")" = 400
test "$(curl -sS -H 'Origin: https://evil.test' -o "$tmp/page" -w '%{http_code}' "$origin$route")" = 400
test "$(curl -sS -H 'Sec-Fetch-Site: cross-site' -o "$tmp/page" -w '%{http_code}' "$origin$route")" = 400
test "$(post "$route" --data token=bad)" = 400
diff -r "$tmp/before" "$tmp/site"
printf '\211PNG\r\n\032\nnew' > "$asset"
test "$(get "$route")" = 400
version="$(sha256sum "$asset" | cut -d ' ' -f1)"
test "$(get "/media-image?name=%E6%9C%88%26a.png&version=$version")" = 200
cmp "$asset" "$tmp/page"
printf '<html>wrong format</html>' > "$asset"
version="$(sha256sum "$asset" | cut -d ' ' -f1)"
test "$(get "/media-image?name=%E6%9C%88%26a.png&version=$version")" = 400
mv "$asset" "$tmp/unsafe-source"
ln -s "$tmp/unsafe-source" "$asset"
test "$(get "/media-image?name=%E6%9C%88%26a.png&version=$version")" = 400
echo 'Admin media image tests passed: guarded binary GET, strict version/query/origin, stale snapshots and unsafe files refused without read writes.'
