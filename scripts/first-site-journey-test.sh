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
test "${#token}" = 64
test "$(post /new --data-urlencode "token=$token" --data-urlencode slug=first --data-urlencode 'title=First article')" = 200
test "$(post /prepare-media --data-urlencode "token=$token")" = 200
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=' | base64 -d > "$tmp/image.png"
test "$(post /upload -H 'Expect:' -F "token=$token" -F name=moon.png -F "file=@$tmp/image.png")" = 200
test "$(get '/edit?name=first.md')" = 200
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | head -n 1)"
printf '# First article\n\nMy first saved page.\n\n![Moon](moon.png)\n\n[Home](index.html)\n' > "$tmp/body"
test "$(post /fields --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode 'title=First article' --data-urlencode description=Welcome --data-urlencode date=2026-01-01 --data-urlencode tags=news --data-urlencode "body@$tmp/body")" = 200
test "$(post /check --data-urlencode "token=$token" --data-urlencode mode=drafts)" = 200
test "$(post /build-preview --data-urlencode "token=$token")" = 200
test "$(view /first.html)" = 200
grep -Fq 'My first saved page' "$tmp/view"
grep -Fq 'src="moon.png"' "$tmp/view"
test "$(view /moon.png)" = 200
cmp "$tmp/image.png" "$tmp/view"
test "$(view /style.css)" = 200
plan() {
  test "$(post /plan-production --data-urlencode "token=$token")" = 200
  review="$(sed -n 's/.*name="review_id" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | head -n 1)"
  test "${#review}" = 64
}
build() { post /build-production --data-urlencode "token=$token" --data-urlencode "review_id=$review"; }
plan
test "$(build)" = 200
test ! -e "$tmp/site/.moonpress-build/first.html"
test "$(get /publish)" = 200
grep -Fq 'excluded drafts: 1' "$tmp/page"
test "$(get '/edit?name=first.md')" = 200
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | head -n 1)"
test "$(post /status --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode state=ready)" = 200
test "$(get /publish)" = 200
grep -Fq 'Build needed before publishing' "$tmp/page"
cp -a "$tmp/site/.moonpress-build" "$tmp/before-stale"
test "$(build)" = 400
diff -r "$tmp/before-stale" "$tmp/site/.moonpress-build"
plan
test "$(build)" = 200
test -s "$tmp/site/.moonpress-build/first.html"
cp -a "$tmp/site" "$tmp/before-readiness"
test "$(get /publish)" = 200
grep -Fq 'Production files match saved ready sources' "$tmp/page"
grep -Fq 'excluded drafts: 0' "$tmp/page"
grep -Fq 'not deployment confirmation' "$tmp/page"
diff -r "$tmp/site" "$tmp/before-readiness"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/clean" "$tmp/site/.moonpress-build"
echo 'First-site journey passed: browser forms create/edit/upload/check, isolated linked preview, draft exclusion, ready transition, stale review refusal and current deterministic production output.'
