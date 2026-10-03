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
test "$(get /)" = 200
grep -Fq 'New draft' "$tmp/page"
token="$(sed -n 's/.*name="token" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page")"
test "${#token}" = 64
cp -a "$tmp/site" "$tmp/before"
test "$(post /new --data-urlencode token=wrong --data-urlencode slug=bad --data-urlencode title=Bad)" = 400
test "$(curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' -H 'Host: attacker.example' "$origin/")" = 400
test "$(post /new -H 'Origin: https://attacker.example' --data-urlencode "token=$token" --data-urlencode slug=bad --data-urlencode title=Bad)" = 400
test "$(curl --max-time 8 -sS -o "$tmp/page" -w '%{http_code}' --data-urlencode "token=$token" --data-urlencode slug=bad --data-urlencode title=Bad "$origin/new")" = 400
test "$(get '/new?slug=bad')" = 404
diff -r "$tmp/site" "$tmp/before"
test "$(post /new --data-urlencode "token=$token" --data-urlencode slug=first --data-urlencode 'title=<script>alert("月")</script>')" = 200
"$cli" posts "$tmp/site" --json | jq -e '[.report.posts[] | select(.source=="content/first.md")][0].draft' >/dev/null
test "$(get /)" = 200
grep -Fq '&lt;script&gt;' "$tmp/page"
if grep -Fq '<script>' "$tmp/page"; then exit 1; fi
test "$(get '/edit?name=first.md')" = 200
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | sort -u)"
printf '%s\n' '---' '{"title":"Changed","draft":true}' '---' '# Body' '</textarea><script>bad</script>' > "$tmp/replacement"
test "$(post /save --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode "content@$tmp/replacement")" = 200
cmp "$tmp/site/content/first.md" "$tmp/replacement"
test "$(post /save --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode 'content=Keep my unsaved text </textarea><script>')" = 400
grep -Fq 'Keep my unsaved text &lt;/textarea&gt;&lt;script&gt;' "$tmp/page"
cmp "$tmp/site/content/first.md" "$tmp/replacement"
test "$(get '/edit?name=first.md')" = 200
grep -Fq '&lt;/textarea&gt;&lt;script&gt;bad' "$tmp/page"
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | sort -u)"
test "$(post /status --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode state=ready)" = 200
"$cli" posts "$tmp/site" --json | jq -e '[.report.posts[] | select(.source=="content/first.md")][0].draft == false' >/dev/null
test "$(get '/edit?name=first.md')" = 200
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | sort -u)"
fields_post() { post /fields --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode 'title=Structured <title>' --data-urlencode 'description=Summary' --data-urlencode 'tags=Moon,Bit' --data-urlencode 'body=# Structured body' --data-urlencode "date=$1"; }
cp "$tmp/site/content/first.md" "$tmp/before-fields"
test "$(fields_post 2026-02-30)" = 400
grep -Fq 'Structured &lt;title&gt;' "$tmp/page"
grep -Fq '# Structured body' "$tmp/page"
cmp "$tmp/before-fields" "$tmp/site/content/first.md"
test "$(fields_post 2026-10-03)" = 200
"$cli" posts "$tmp/site" --json | jq -e '[.report.posts[] | select(.source=="content/first.md")][0] | .title=="Structured <title>" and .date=="2026-10-03" and .tags==["Moon,Bit"] and .draft==false' >/dev/null
cp "$tmp/site/content/first.md" "$tmp/after-fields"
test "$(fields_post 2026-10-04)" = 400
grep -Fq 'Post changed since' "$tmp/page"
cmp "$tmp/after-fields" "$tmp/site/content/first.md"
# Preview stale unsaved work without refreshing the version or touching files.
cp -a "$tmp/site" "$tmp/before-preview"
printf '%s\n' '# Preview heading' '' '**Unsaved** </textarea><script>bad</script>' '[next](guide.html) ![alt](image.png)' > "$tmp/preview-body"
test "$(post /preview --data-urlencode "token=$token" --data-urlencode name=first.md --data-urlencode "version=$version" --data-urlencode title=Unsaved --data-urlencode description=Summary --data-urlencode date=invalid --data-urlencode tags=Moon --data-urlencode "body@$tmp/preview-body")" = 200
grep -Fq '<strong>Unsaved</strong>' "$tmp/page"
grep -Fq '&lt;/textarea&gt;&lt;script&gt;bad&lt;/script&gt;' "$tmp/page"
grep -Fq 'data-preview-href="guide.html"' "$tmp/page"
grep -Fq "name=\"version\" value=\"$version\"" "$tmp/page"
grep -Fq '**Unsaved**' "$tmp/page"
if grep -Fq '<script>' "$tmp/page"; then exit 1; fi
diff -r "$tmp/before-preview" "$tmp/site"
test "$(fields_post 2026-10-04)" = 400
cmp "$tmp/after-fields" "$tmp/site/content/first.md"
test "$(post /preview --data-urlencode token=wrong)" = 400
test "$(post /preview --data-urlencode "token=$token" --data-urlencode name=../README.md --data-urlencode "version=$version" --data-urlencode title=Keep --data-urlencode description= --data-urlencode date= --data-urlencode tags= --data-urlencode body=Keep)" = 400
grep -Fq 'Keep' "$tmp/page"
printf '%s\n' '---' '{broken' '---' > "$tmp/site/content/broken.md"
test "$(get '/edit?name=broken.md')" = 200
grep -Fq 'Structured editor unavailable' "$tmp/page"
grep -Fq '{broken' "$tmp/page"
rm "$tmp/site/content/broken.md"
test ! -e "$tmp/site/dist"
test "$(get '/edit?name=..%2FREADME.md')" = 400
test "$(get '/edit?name=first.md&name=index.md')" = 400
# Site validation reuses the compiler without writing sources or output.
check_post() { post /check --data-urlencode "token=$token" --data-urlencode "mode=$1"; }
"$cli" build "$tmp/site" "$tmp/site/dist" >/dev/null
printf 'user-owned output' > "$tmp/site/dist/foreign.txt"
cp -a "$tmp/site" "$tmp/before-check"
test "$(check_post ready)" = 200
grep -Fq 'Site validation passed' "$tmp/page"
expected="$("$cli" check "$tmp/site" --json | jq -r '"Checked: \(.report.pages) pages, \(.report.outputs) planned outputs."')"
grep -Fq "$expected" "$tmp/page"
test "$(check_post drafts)" = 200
grep -Fq 'Including drafts' "$tmp/page"
diff -r "$tmp/before-check" "$tmp/site"
printf '%s\n' '---' '{"draft":true}' '---' '[missing](missing.html)' > "$tmp/site/content/draft-check.md"
cp -a "$tmp/site" "$tmp/before-check-error"
test "$(check_post ready)" = 200
test "$(check_post drafts)" = 400
grep -Fq 'Validation failed' "$tmp/page"
grep -Fq 'missing.html' "$tmp/page"
diff -r "$tmp/before-check-error" "$tmp/site"
test "$(check_post invalid)" = 400
test "$(post /check --data-urlencode token=wrong --data-urlencode mode=ready)" = 400
rm "$tmp/site/content/draft-check.md"
printf '%s\n' '---' '{"<script>":true}' '---' > "$tmp/site/content/bad-check.md"
test "$(check_post ready)" = 400
grep -Fq '&lt;script&gt;' "$tmp/page"
if grep -Fq '<script>' "$tmp/page"; then exit 1; fi
rm "$tmp/site/content/bad-check.md"
# A broken source must not hide good articles or permit unsafe repair reads.
printf '%s\n' '---' '{"<script>":true}' '---' > "$tmp/site/content/repair.md"
printf '\377' > "$tmp/site/content/invalid-utf8.md"
ln -s "$tmp/site/content/first.md" "$tmp/site/content/link.md"
mkdir "$tmp/site/content/nested.md"
mkfifo "$tmp/site/content/pipe.md"
cp -a "$tmp/site" "$tmp/before-inventory"
test "$(get /)" = 200
grep -Fq 'Structured &lt;title&gt;' "$tmp/page"
grep -Fq 'Sources needing attention' "$tmp/page"
grep -Fq '&lt;script&gt;' "$tmp/page"
grep -Fq '/edit?name=repair.md' "$tmp/page"
for name in invalid-utf8 link nested pipe; do
  grep -Fq "content/$name.md" "$tmp/page"
  if grep -Fq "/edit?name=$name.md" "$tmp/page"; then exit 1; fi
done
if "$cli" posts "$tmp/site" > "$tmp/strict" 2>&1; then exit 1; fi
# Compare regular files/links and check FIFO type without reading it.
test -p "$tmp/site/content/pipe.md"
diff -r --exclude=pipe.md "$tmp/before-inventory" "$tmp/site" > "$tmp/inventory-diff" || { cat "$tmp/inventory-diff"; exit 1; }
test "$(get '/edit?name=repair.md')" = 200
version="$(sed -n 's/.*name="version" value="\([a-f0-9]*\)".*/\1/p' "$tmp/page" | sort -u)"
test "$(post /save --data-urlencode "token=$token" --data-urlencode name=repair.md --data-urlencode "version=$version" --data-urlencode 'content=# Repaired article')" = 200
rm "$tmp/site/content/invalid-utf8.md" "$tmp/site/content/link.md" "$tmp/site/content/pipe.md"
rmdir "$tmp/site/content/nested.md"
test "$(get /)" = 200
grep -Fq 'Repaired article' "$tmp/page"
if grep -Fq 'Sources needing attention' "$tmp/page"; then exit 1; fi
raw() { timeout 8 bash -c 'exec 3<>/dev/tcp/127.0.0.1/"$1"; printf "%b" "$2" >&3; cat <&3 2>/dev/null || true' _ "$port" "$1" > "$tmp/raw"; }
raw "GET / HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nHost: evil\r\n\r\n"
grep -Fq '400 Bad Request' "$tmp/raw"
raw "POST /new HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nContent-Length: 262145\r\n\r\n"
grep -Fq '400 Bad Request' "$tmp/raw"
raw "GET / HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nTransfer-Encoding: chunked\r\n\r\n"
grep -Fq '400 Bad Request' "$tmp/raw"
printf -v padding '%17000s' ''
raw "GET / HTTP/1.1\r\nHost: 127.0.0.1:$port\r\nX-Padding:$padding"
grep -Fq '400 Bad Request' "$tmp/raw"
# Idle/incomplete clients cannot monopolize the single-user server indefinitely.
raw 'GET / HTTP/1.1\r\n'
grep -Fq '400 Bad Request' "$tmp/raw"
test "$(get /)" = 200
"$cli" admin --help | grep -Fq 'Ctrl-C'
for portarg in 0 80 65536 abc 1.2; do
  if "$cli" admin "$tmp/site" "$portarg" > "$tmp/args" 2>&1; then exit 1; else test "$?" = 2; fi
done
if "$cli" admin "$tmp/site" "$port" --json > "$tmp/args" 2>&1; then exit 1; else test "$?" = 2; fi
if "$cli" admin "$tmp/site" "$port" > "$tmp/args" 2>&1; then exit 1; else test "$?" = 1; fi
"$cli" check "$tmp/site" >/dev/null
echo 'Admin tests passed: HTTP forms, token/origin/host checks, escape safety, stale input recovery, framing limits, timeouts and lifecycle.'
