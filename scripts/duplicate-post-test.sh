#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
writer=''
cleanup() { if [[ -n "$writer" ]]; then kill -KILL "$writer" 2>/dev/null || true; wait "$writer" 2>/dev/null || true; fi; rm -rf "$tmp"; }
trap cleanup EXIT
"$cli" init "$tmp/site" >/dev/null
printf '%s\n' '---' '{"title":"Original","slug":"original-url","date":"2026-10-12","listed":false,"tags":["tag"],"description":"Summary"}' '---' '# Body' > "$tmp/site/content/original.md"
version="$("$cli" read "$tmp/site" original.md --json | jq -r '.report.digest')"
cp "$tmp/site/content/original.md" "$tmp/original"
"$cli" duplicate "$tmp/site" original.md "$version" 月 'Copied <title>' --json > "$tmp/report"
jq -e '.schema==1 and .command=="duplicate" and .report.source=="content/月.md" and .report.output=="月.html" and .report.draft and .report.title=="Copied <title>"' "$tmp/report" >/dev/null
"$cli" posts "$tmp/site" --json | jq -e '.report.posts[] | select(.source=="content/月.md") | .draft and (.listed|not) and .date==null and .tags==["tag"]' >/dev/null
cmp "$tmp/original" "$tmp/site/content/original.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
test ! -e "$tmp/out/月.html"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
grep -Fq 'Copied &lt;title&gt;' "$tmp/preview/月.html"
grep -Fq '<h1 id="mp-body">Body</h1>' "$tmp/preview/月.html"
cp -a "$tmp/site" "$tmp/before"
reject() { local expected="$1" status=0; shift; "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?; test "$status" = "$expected"; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
reject 1 "$cli" duplicate "$tmp/site" original.md "$version" 月 Overwrite
reject 1 "$cli" duplicate "$tmp/site" original.md "$(printf '%064d' 0)" stale Stale
reject 1 "$cli" duplicate "$tmp/site" original.md "$version" bad '  '
reject 1 "$cli" duplicate "$tmp/site" original.md "$version" ../escape Title
reject 1 "$cli" duplicate "$tmp/site" ../original.md "$version" bad Title
diff -r "$tmp/before" "$tmp/site"
ln -s original.md "$tmp/site/content/link.md"
mkfifo "$tmp/site/content/fifo.md"
for name in link.md fifo.md; do reject 1 timeout 5 "$cli" duplicate "$tmp/site" "$name" "$version" bad Title; done
rm "$tmp/site/content/link.md" "$tmp/site/content/fifo.md"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
for fault in OPEN WRITE FLUSH CLOSE; do
  reject 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$fault=$tmp/site/content/fail.md" "$cli" duplicate "$tmp/site" original.md "$version" fail Title
  test ! -e "$tmp/site/content/fail.md"
  diff -r "$tmp/before" "$tmp/site"
done
reject 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_CREATE_BEFORE_OPEN=$tmp/site/content/race.md" "$cli" duplicate "$tmp/site" original.md "$version" race Title
test "$(cat "$tmp/site/content/race.md")" = 'competing writer'
rm "$tmp/site/content/race.md"
# Recheck source after the real authoring lock has been acquired.
cc -Wall -Wextra -Werror -shared -fPIC tests/native/pause_lock.c -ldl -o "$tmp/pause.so"
MOONPRESS_TEST_LOCK_READY="$tmp/ready" MOONPRESS_TEST_LOCK_RELEASE="$tmp/release" LD_PRELOAD="$tmp/pause.so" "$cli" duplicate "$tmp/site" original.md "$version" changed Title > "$tmp/stdout" 2> "$tmp/stderr" &
writer=$!
for ((i=0; i<250; i++)); do [[ -f "$tmp/ready" ]] && break; kill -0 "$writer"; sleep 0.02; done
test -f "$tmp/ready"
printf '\nExternal edit\n' >> "$tmp/site/content/original.md"
touch "$tmp/release"
status=0
wait "$writer" || status=$?
writer=''
test "$status" = 1
grep -Fq 'Post changed since' "$tmp/stderr"
test ! -e "$tmp/site/content/changed.md"
cp "$tmp/original" "$tmp/site/content/original.md"
diff -r "$tmp/before" "$tmp/site"
"$cli" duplicate --help | grep -Fq 'No --include-drafts option'
reject 2 "$cli" duplicate "$tmp/site" original.md "$version" copy Title --include-drafts
reject 2 "$cli" duplicate "$tmp/site" original.md "$version" copy Title --json --json
reject 2 "$cli" duplicate "$tmp/site" original.md "$version" copy
"$cli" duplicate "$tmp/site" original.md "$version" text Title | grep -Fq 'Duplicated draft:'
echo 'Duplicate tests passed: draft copy, metadata reset, source versions, exclusive destinations, I/O failures, locked recheck and strict CLI.'
