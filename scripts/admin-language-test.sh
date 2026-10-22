#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
server=''
cleanup() { if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
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
cp -a "$tmp/site" "$tmp/before"
request() { curl --max-time 10 -sS -D "$tmp/headers" -o "$tmp/page" -w '%{http_code}' "$@"; }
for language in en ja; do
  test "$(request -H "Accept-Language: $language" "$origin/rooms")" = 200
  grep -Fq "<html lang=\"$language\">" "$tmp/page"
  grep -Fq "Content-Language: $language" "$tmp/headers"
  grep -Fq 'Vary: Accept-Language, Cookie' "$tmp/headers"
  ! grep -Fq '<!--mp:' "$tmp/page"
  if [[ "$language" = en ]]; then grep -Fq '01 The beginning room' "$tmp/page"; ! grep -Fq 'もちもの' "$tmp/page"; else grep -Fq '01 はじまりのおへや' "$tmp/page"; fi
  for path in /rooms/write /rooms/preview /rooms/build /rooms/publish /authoring-recovery /edit?name=index.md; do
    test "$(request -H "Accept-Language: $language" "$origin$path")" = 200
    grep -Fq "<html lang=\"$language\">" "$tmp/page"
    ! grep -Fq '<!--mp:' "$tmp/page"
  done
done
test "$(request -H 'Accept-Language: en;q=0.2,ja-JP;q=0.9' "$origin/rooms")" = 200
grep -Fq '<html lang="ja">' "$tmp/page"
test "$(request -H 'Accept-Language: fr' "$origin/rooms")" = 200
grep -Fq '<html lang="en">' "$tmp/page"
test "$(request -H 'Accept-Language: ja' -H 'Cookie: moonpress-language=en' "$origin/rooms")" = 200
grep -Fq '<html lang="en">' "$tmp/page"
test "$(request -c "$tmp/cookies" "$origin/language/ja?return=%2Fedit%3Fname%3Dindex.md")" = 303
grep -Fq 'Location: /edit?name=index.md' "$tmp/headers"
grep -Fq 'HttpOnly; SameSite=Strict' "$tmp/headers"
test "$(request -b "$tmp/cookies" -H 'Accept-Language: en' "$origin/rooms")" = 200
grep -Fq '<html lang="ja">' "$tmp/page"
test "$(request -b "$tmp/cookies" -c "$tmp/cookies" "$origin/language/auto")" = 303
grep -Fq 'Max-Age=0' "$tmp/headers"
test "$(request -b "$tmp/cookies" -H 'Accept-Language: en' "$origin/rooms")" = 200
grep -Fq '<html lang="en">' "$tmp/page"
for target in '%2F%2Fevil.test' '%2Fedit%0D%0AX-Injected%3Ayes' '%2F%5Cevil.test'; do
  test "$(request "$origin/language/en?return=$target")" = 303
  grep -Fq 'Location: /rooms' "$tmp/headers"
done
test "$(request "$origin/language/xx")" = 400
test "$(request -H "Origin: $origin" --data token=invalid "$origin/language/en")" = 400
test "$(request -H 'Accept-Language: ja' "$origin/assets/unknown")" = 404
grep -Fq '<html lang="ja">' "$tmp/page"
grep -Fq 'Content-Language: ja' "$tmp/headers"
diff -r "$tmp/site" "$tmp/before"
# Application copy is marked explicitly. User text that resembles a marker is escaped.
"$cli" new "$tmp/site" language-data 'Media 日本語' >/dev/null
printf '\n<!--mp:ja-->私の本文<!--mp:en-->My content<!--mp:end-->\n' >> "$tmp/site/content/language-data.md"
cp "$tmp/site/content/language-data.md" "$tmp/user-data"
for language in en ja; do
  test "$(request -H "Accept-Language: $language" "$origin/edit?name=language-data.md")" = 200
  grep -Fq 'Media 日本語' "$tmp/page"
  grep -Fq '&lt;!--mp:ja--&gt;私の本文&lt;!--mp:en--&gt;My content&lt;!--mp:end--&gt;' "$tmp/page"
  cmp "$tmp/user-data" "$tmp/site/content/language-data.md"
done
echo 'Language HTTP checks passed: auto negotiation, persistent override, safe return paths, read-only preference and untouched user content.'
