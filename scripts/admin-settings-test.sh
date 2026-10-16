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
rm "$tmp/site/site.json"
cp -a "$tmp/site" "$tmp/before"
test "$(get /site-settings)" = 200
grep -Fq 'No site.json exists' "$tmp/page"
grep -Fq 'name="version" value="absent"' "$tmp/page"
diff -r "$tmp/site" "$tmp/before"
token="$(sed -n 's/.*name="token" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")"
test "${#token}" = 64
save() { post /site-settings --data-urlencode "token=$token" --data-urlencode "version=$1" --data-urlencode "content=$2"; }
test "$(save absent '</textarea><script>bad</script>')" = 400
grep -Fq '&lt;/textarea&gt;&lt;script&gt;' "$tmp/page"
grep -Fq 'name="version" value="absent"' "$tmp/page"
! grep -Fq '<script>' "$tmp/page"
test ! -e "$tmp/site/site.json"
test "$(post /site-settings --data-urlencode token=bad --data-urlencode version=absent --data-urlencode 'content={}')" = 400
test "$(save absent '{"tag_index":true}')" = 200
grep -Fq 'Created site.json' "$tmp/page"
version="$(sha256sum "$tmp/site/site.json" | cut -d ' ' -f1)"
chmod 640 "$tmp/site/site.json"
touch -t 200001010000 "$tmp/site/site.json"
metadata="$(stat -c '%i %a %Y' "$tmp/site/site.json")"
test "$(save "$version" '{"tag_index":true}')" = 200
grep -Fq 'Settings unchanged' "$tmp/page"
test "$(stat -c '%i %a %Y' "$tmp/site/site.json")" = "$metadata"
test "$(save absent '{"tag_index":false}')" = 400
grep -Fq 'name="version" value="absent"' "$tmp/page"
grep -Fq '{&quot;tag_index&quot;:false}' "$tmp/page"
test "$(post /site-settings --data-urlencode "token=$token" --data-urlencode "version=$version" --data-urlencode 'content={}' --data-urlencode extra=bad)" = 400
# A schema-valid setting may still fail whole-site validation.
test "$(save "$version" '{"tag_index":true,"collection_layout":"missing.html"}')" = 200
grep -Fq 'schema validated only' "$tmp/page"
if "$cli" check "$tmp/site" > "$tmp/check" 2>&1; then exit 1; fi
printf '{broken\n' > "$tmp/site/site.json"
test "$(get /site-settings)" = 200
grep -Fq 'Current settings need repair' "$tmp/page"
version="$(sha256sum "$tmp/site/site.json" | cut -d ' ' -f1)"
grep -Fq "name=\"version\" value=\"$version\"" "$tmp/page"
test "$(save "$version" '{"tag_index":true}')" = 200
"$cli" check "$tmp/site" >/dev/null
test ! -e "$tmp/site/.moonpress-build"
test ! -e "$tmp/site/.moonpress-preview"
test ! -e "$tmp/site/.moonpress-settings-edit"
test "$(get /site-settings?extra=bad)" = 404
echo 'Admin settings tests passed: read-only absence, creation/repair, schema scope, token/field refusal, escaped retained conflicts and no-op metadata.'
