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
printf '\000\377old' > "$asset"
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
test "$(get '/media')" = 200
grep -Fq '/media-replace?name=%E6%9C%88%26a.png' "$tmp/page"
token="$(sed -n 's/.*name="token" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")"
test "${#token}" = 64
cp -a "$tmp/site" "$tmp/before"
test "$(get '/media-replace?name=%E6%9C%88%26a.png')" = 200
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")"
test "$version" = "$(sha256sum "$asset" | cut -d ' ' -f1)"
grep -Fq '月&amp;a.png' "$tmp/page"
grep -Fq 'scope=all&amp;output=%E6%9C%88%26a.png' "$tmp/page"
for path in '/media-replace?name=missing.png' '/media-replace?name=..%2Fsecret' '/media-replace?name=x.png&extra=x' '/media-replace?name=x.png&name=y.png'; do
  test "$(get "$path")" = 400
done
test "$(get '/月%26a.png')" = 404
diff -r "$tmp/before" "$tmp/site"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/output-before"
send_replace() {
  post /replace-media --form-string "token=$1" --form-string "name=$name" --form-string "version=$2" -F "file=@$3"
}
test "$(send_replace wrong "$version" "$tmp/replacement")" = 400
test "$(post /replace-media --form-string "token=$token" --form-string "name=$name" -F "file=@$tmp/replacement")" = 400
test "$(post /replace-media --form-string "token=$token" --form-string "name=$name" --form-string "version=$version" --form-string "version=$version" -F "file=@$tmp/replacement")" = 400
test "$(curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' -H 'Origin: https://evil.test' --form-string "token=$token" --form-string "name=$name" --form-string "version=$version" -F "file=@$tmp/replacement" "$origin/replace-media")" = 400
diff -r "$tmp/before" "$tmp/site"
test "$(send_replace "$token" "$version" "$tmp/replacement")" = 200
grep -Fq 'Replaced public/月&amp;a.png' "$tmp/page"
grep -Fq 'No build or deployment performed' "$tmp/page"
cmp "$asset" "$tmp/replacement"
diff -r "$tmp/output-before" "$tmp/out"
cp -a "$tmp/site" "$tmp/changed"
# A stale form remains stale; no automatic refresh/retry.
test "$(send_replace "$token" "$version" "$tmp/before/public/$name")" = 400
grep -Fq 'changed since it was read' "$tmp/page"
test "$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")" = "$version"
grep -Fq 'Reload current media version' "$tmp/page"
diff -r "$tmp/changed" "$tmp/site"
test "$(get '/media-replace?name=%E6%9C%88%26a.png')" = 200
new="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")"
test "$new" != "$version"
metadata="$(stat -c '%i %a %Y' "$asset")"
test "$(send_replace "$token" "$new" "$tmp/replacement")" = 200
grep -Fq 'Unchanged public/' "$tmp/page"
test "$(stat -c '%i %a %Y' "$asset")" = "$metadata"
# Normal upload still refuses existing names, and rejects replacement fields.
test "$(post /upload --form-string "token=$token" --form-string "name=$name" -F "file=@$tmp/replacement")" = 400
test "$(post /upload --form-string "token=$token" --form-string 'name=new.png' --form-string "version=$new" -F "file=@$tmp/replacement")" = 400
test ! -e "$tmp/site/public/new.png"
diff -r "$tmp/changed" "$tmp/site"
test ! -e "$tmp/site/public/.moonpress-media-edit"
echo 'Admin media replacement tests passed: versioned binary upload, escaped fixed filenames, read-only GET, token/origin/field rejection, stale form retention, no-op metadata and create-only upload preservation.'
