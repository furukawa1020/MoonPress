#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
cleanup() { if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
mkdir "$tmp/site/public"
printf image > "$tmp/site/public/a.png"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
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
post() { curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" --data "token=$token&name=a.png&review_id=$id&ack=confirm-unscanned-removal" "$@" "$origin/remove-media"; }
cp -a "$tmp/site" "$tmp/before"
cp -a "$tmp/out" "$tmp/output"
test "$(get /media)" = 200
grep -Fq '/media-remove?name=a.png' "$tmp/page"
test "$(get '/media-remove?name=a.png')" = 200
grep -Fq 'No known references found' "$tmp/page"
grep -Fq 'permanent removal with no undo' "$tmp/page"
token="$(sed -n 's/.*name="token" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")"
id="$(sed -n 's/.*name="review_id" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")"
test "${#token}" = 64; test "${#id}" = 64
diff -r "$tmp/before" "$tmp/site"
test "$(post -H 'Origin: https://evil.test')" = 400
test "$(post --data extra=x)" = 400
test "$(post --data ack=duplicate)" = 400
saved="$token"; token=bad; test "$(post)" = 400; token="$saved"
test "$(curl -sS -o "$tmp/page" -w '%{http_code}' -H "Origin: $origin" --data "token=$token&name=a.png&review_id=$id" "$origin/remove-media")" = 400
diff -r "$tmp/before" "$tmp/site"
printf '\nChanged\n' >> "$tmp/site/content/index.md"
test "$(post)" = 400
grep -Fq 'Inspect removal again' "$tmp/page"
printf '%s\n' '---' '{"draft":true}' '---' '# Private' '' '![image](a.png)' > "$tmp/site/content/private.md"
test "$(get '/media-remove?name=a.png')" = 200
grep -Fq 'Removal blocked' "$tmp/page"
grep -Fq 'content/private.md' "$tmp/page"
! grep -Fq 'action="/remove-media"' "$tmp/page"
id="$("$cli" media-removal-plan "$tmp/site" a.png --json | jq -r '.report.review_id')"
test "$(post)" = 400
test -f "$tmp/site/public/a.png"
printf '# No image\n' > "$tmp/site/content/private.md"
test "$(get '/media-remove?name=a.png')" = 200
id="$(sed -n 's/.*name="review_id" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")"
test "$(post)" = 200
grep -Fq 'Media removed' "$tmp/page"
test ! -e "$tmp/site/public/a.png"
diff -r "$tmp/output" "$tmp/out"
test "$(post)" = 400
printf image > "$tmp/site/public/月&<b>.png"
test "$(get '/media-remove?name=%E6%9C%88%26%3Cb%3E.png')" = 200
grep -Fq '月&amp;&lt;b&gt;.png' "$tmp/page"
! grep -Fq '<b>.png' "$tmp/page"
test -f "$tmp/site/public/月&<b>.png"
echo 'Admin media removal passed: read-only inspection, strict protected confirmation, stale/blocked refusal and separate output lifecycle.'
