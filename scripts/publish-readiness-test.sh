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
cp -a "$tmp/site" "$tmp/before"
test "$(get /publish)" = 200
grep -Fq 'Build needed before publishing' "$tmp/page"
grep -Fq 'No public base_url' "$tmp/page"
diff -r "$tmp/site" "$tmp/before"
"$cli" new "$tmp/site" private 'Private' >/dev/null
"$cli" build "$tmp/site" "$tmp/site/.moonpress-build" >/dev/null
cp -a "$tmp/site" "$tmp/built"
test "$(get /publish)" = 200
grep -Fq 'Production files match saved ready sources' "$tmp/page"
grep -Fq 'excluded drafts: 1' "$tmp/page"
grep -Fq 'not deployment confirmation' "$tmp/page"
diff -r "$tmp/site" "$tmp/built"
printf '\nChanged text\n' >> "$tmp/site/content/index.md"
test "$(get /publish)" = 200
grep -Fq 'Build needed before publishing' "$tmp/page"
"$cli" build "$tmp/site" "$tmp/site/.moonpress-build" >/dev/null
printf 'manual' >> "$tmp/site/.moonpress-build/index.html"
cp -a "$tmp/site" "$tmp/manual"
test "$(get /publish)" = 400
grep -Fq 'Publishing preparation blocked' "$tmp/page"
diff -r "$tmp/site" "$tmp/manual"
cp "$tmp/built/.moonpress-build/index.html" "$tmp/site/.moonpress-build/index.html"
printf '{broken' > "$tmp/site/site.json"
test "$(get /publish)" = 400
grep -Fq 'Site settings' "$tmp/page"
echo 'Publish readiness HTTP tests passed: missing/current/stale output, excluded drafts, configuration guidance, blocked edited/invalid output and read-only state.'
