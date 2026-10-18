#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
cleanup() { if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/site/.moonpress-build" >/dev/null
id="$("$cli" review "$tmp/site" "$tmp/site/.moonpress-build" --json | jq -r '.report.review_id')"
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
curl -fsS "$origin/workflow" > "$tmp/form"
token="$(sed -n 's/.*name="token" value="\([^"]*\)".*/\1/p' "$tmp/form" | head -1)"
test -n "$token"
post() { curl --max-time 10 -sS -D "$tmp/headers" -o "$tmp/body" -w '%{http_code}' -H "Origin: $origin" --data "token=$token&review_id=$id" "$@" "$origin/export-production"; }
cp -a "$tmp/site" "$tmp/before"
test "$(post)" = 200
cp "$tmp/body" "$tmp/site.zip"
for header in 'Content-Type: application/zip' 'Content-Disposition: attachment; filename="moonpress-site.zip"' 'Cache-Control: no-store' 'X-Content-Type-Options: nosniff' "default-src 'none'; sandbox allow-downloads;"; do grep -Fq "$header" "$tmp/headers"; done
grep -Fq "X-MoonPress-SHA256: $(sha256sum "$tmp/site.zip" | cut -d ' ' -f1)" "$tmp/headers"
unzip -q "$tmp/site.zip" -d "$tmp/unpacked"
cp -a "$tmp/site/.moonpress-build" "$tmp/expected"
rm "$tmp/expected/.moonpress.json"
diff -r "$tmp/expected" "$tmp/unpacked"
test "$(post)" = 200
cmp "$tmp/body" "$tmp/site.zip"
test "$(post --data extra=x)" = 400
test "$(post --data token=duplicate)" = 400
test "$(post -H 'Origin: https://evil.test')" = 400
test "$(post -H 'Sec-Fetch-Site: cross-site')" = 400
test "$(curl -sS -o "$tmp/body" -w '%{http_code}' "$origin/export-production")" = 400
saved="$token"; token=bad; test "$(post)" = 400; token="$saved"
diff -r "$tmp/before" "$tmp/site"
printf '# Changed\n' > "$tmp/site/content/index.md"
test "$(post)" = 400
grep -Fq 'Review production' "$tmp/body"
"$cli" build "$tmp/site" "$tmp/site/.moonpress-build" >/dev/null
id="$("$cli" review "$tmp/site" "$tmp/site/.moonpress-build" --json | jq -r '.report.review_id')"
printf 'manual edit' >> "$tmp/site/.moonpress-build/index.html"
cp -a "$tmp/site" "$tmp/edited"
test "$(post)" = 400
grep -Fq 'Edited export file' "$tmp/body"
diff -r "$tmp/edited" "$tmp/site"
test "$(find "$tmp/site" -name '*.zip' | wc -l)" = 0
echo 'Admin export passed: protected POST, binary ZIP parity/headers, deterministic no-write reads and stale review refusal.'
