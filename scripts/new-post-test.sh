#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
writer=''
cleanup() {
  if [[ -n "$writer" ]]; then kill -KILL "$writer" 2>/dev/null || true; wait "$writer" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" new "$tmp/site" 月 'Title "quoted"' --json > "$tmp/report"
jq -e '.schema == 1 and .command == "new" and .report == {source:"content/月.md",output:"月.html",title:"Title \"quoted\"",draft:true}' "$tmp/report" >/dev/null
"$cli" posts "$tmp/site" --json | jq -e '[.report.posts[] | select(.source == "content/月.md")][0] | .draft and .title == "Title \"quoted\""' >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/月.html"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
grep -Fq 'Title &quot;quoted&quot;' "$tmp/preview/月.html"
cp -a "$tmp/site" "$tmp/before"
failure() {
  local expected="$1" status=0
  shift
  "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" = "$expected"
  test ! -s "$tmp/stdout"
  test -s "$tmp/stderr"
}
failure 1 "$cli" new "$tmp/site" 月 overwrite
diff -r "$tmp/site" "$tmp/before"
for slug in '../escape' /absolute 'has space' .hidden 'a/b' 'bad%20'; do failure 1 "$cli" new "$tmp/site" "$slug" Title; done
failure 1 "$cli" new "$tmp/site" blank '  '
failure 1 "$cli" new "$tmp/missing" post Title
diff -r "$tmp/site" "$tmp/before"
mkdir "$tmp/site/content/dir.md"
ln -s "$tmp/site/content/月.md" "$tmp/site/content/link.md"
ln -s "$tmp/missing" "$tmp/site/content/dangling.md"
mkfifo "$tmp/site/content/fifo.md"
for slug in dir link dangling fifo; do failure 1 timeout 10 "$cli" new "$tmp/site" "$slug" Title; done
rmdir "$tmp/site/content/dir.md"
rm "$tmp/site/content/link.md" "$tmp/site/content/dangling.md" "$tmp/site/content/fifo.md"
for flag in --help -h; do "$cli" new "$flag" | grep -Fq 'Usage: moonpress new'; done
failure 2 "$cli" new
failure 2 "$cli" new "$tmp/site" post
failure 2 "$cli" new "$tmp/site" post Title --include-drafts
failure 2 "$cli" new "$tmp/site" post Title --json --json
failure 2 "$cli" new "$tmp/site" post Title extra
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
for fault in OPEN WRITE FLUSH CLOSE; do
  failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$fault=$tmp/site/content/fail.md" "$cli" new "$tmp/site" fail Title
  test ! -e "$tmp/site/content/fail.md"
  diff -r "$tmp/site" "$tmp/before"
done
# A competing creator between preflight and fopen must not be overwritten/deleted.
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_CREATE_BEFORE_OPEN=$tmp/site/content/race.md" "$cli" new "$tmp/site" race Title
test "$(cat "$tmp/site/content/race.md")" = 'competing writer'
rm "$tmp/site/content/race.md"
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_WRITE=$tmp/site/content/fail.md" "MOONPRESS_TEST_FAIL_REMOVE=$tmp/site/content/fail.md" "$cli" new "$tmp/site" fail Title
grep -Fq 'cleanup incomplete' "$tmp/stderr"
test -f "$tmp/site/content/fail.md"
failure 1 "$cli" new "$tmp/site" fail Title
rm "$tmp/site/content/fail.md"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/pause_lock.c -ldl -o "$tmp/pause.so"
MOONPRESS_TEST_LOCK_READY="$tmp/ready" MOONPRESS_TEST_LOCK_RELEASE="$tmp/release" LD_PRELOAD="$tmp/pause.so" "$cli" new "$tmp/site" first Title > "$tmp/first" 2> "$tmp/first-error" &
writer=$!
for ((i=0; i<250; i++)); do
  [[ -f "$tmp/ready" ]] && break
  kill -0 "$writer"
  sleep 0.02
done
test -f "$tmp/ready"
failure 1 "$cli" new "$tmp/site" second Title
grep -Fq 'busy' "$tmp/stderr"
test ! -e "$tmp/site/content/second.md"
touch "$tmp/release"
wait "$writer"
writer=''
test -f "$tmp/site/content/first.md"
"$cli" check "$tmp/site" --include-drafts >/dev/null
echo 'New post tests passed: default drafts, preview, existing-target protection, exclusive-create race, I/O cleanup, locking and CLI grammar.'
