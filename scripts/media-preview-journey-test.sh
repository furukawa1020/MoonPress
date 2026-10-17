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
token="$(sed -n 's/.*name="token" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | head -n 1)"
test "$(post /prepare-media --data-urlencode "token=$token")" = 200
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP8z8DAwMDAxMDAwMDAAAANHQEDasKb6QAAAABJRU5ErkJggg==' | base64 -d > "$tmp/red.png"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGNkYPjPwMDAxMDAwMDAAAALHwEDmIWXfgAAAABJRU5ErkJggg==' | base64 -d > "$tmp/blue.png"
test "$(post /upload -H 'Expect:' -F "token=$token" -F name=photo.png -F "file=@$tmp/red.png")" = 200
old="$(sha256sum "$tmp/red.png" | cut -d ' ' -f1)"
old_url="/media-image?name=photo.png&version=$old"
test "$(get /media)" = 200
grep -Fq "src=\"/media-image?name=photo.png&amp;version=$old\"" "$tmp/page"
test "$(get "$old_url")" = 200
cmp "$tmp/red.png" "$tmp/page"
"$cli" build "$tmp/site" "$tmp/output" >/dev/null
cp -a "$tmp/output" "$tmp/output-before"
test "$(post /build-preview --data-urlencode "token=$token")" = 200
cp -a "$tmp/site/.moonpress-preview" "$tmp/preview-before"
# Integrated preview supports HEAD/revalidation while admin still rejects HEAD.
curl -sS -D "$tmp/headers" -o "$tmp/view" "$preview/photo.png"
tag="$(sed -n 's/^ETag: //p' "$tmp/headers" | tr -d '\r')"
test "$tag" = "\"$old\""
test "$(curl -sS -I -H "If-None-Match: $tag" -o "$tmp/headers" -w '%{http_code}' "$preview/photo.png")" = 304
test "$(curl -sS -I -o "$tmp/headers" -w '%{http_code}' "$origin/media")" = 400
test "$(post /replace-media -H 'Expect:' -F "token=$token" -F name=photo.png -F "version=$old" -F "file=@$tmp/blue.png")" = 200
new="$(sha256sum "$tmp/blue.png" | cut -d ' ' -f1)"
test "$(get "$old_url")" = 400
test "$(get '/media-replace?name=photo.png')" = 200
grep -Fq "src=\"/media-image?name=photo.png&amp;version=$new\"" "$tmp/page"
cp -a "$tmp/site" "$tmp/source-before-reads"
test "$(get "/media-image?name=photo.png&version=$new")" = 200
cmp "$tmp/blue.png" "$tmp/page"
diff -r "$tmp/site" "$tmp/source-before-reads"
diff -r "$tmp/output" "$tmp/output-before"
diff -r "$tmp/site/.moonpress-preview" "$tmp/preview-before"
test "$(view /photo.png)" = 200
cmp "$tmp/red.png" "$tmp/view"
test "$(post /build-preview --data-urlencode "token=$token")" = 200
test "$(view /photo.png)" = 200
cmp "$tmp/blue.png" "$tmp/view"
echo 'Media preview journey passed: actual PNG upload, thumbnails, replacement, stale/refreshed URLs, read-only viewing, independent generated preview and conditional HEAD.'
