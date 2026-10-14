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
mkdir -p "$tmp/site/content" "$tmp/publish"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '# Home\n\nBody\n' > "$tmp/site/content/index.md"
printf '# Other\n' > "$tmp/site/content/other.md"
out="$tmp/publish/out"
review() { "$cli" review "$tmp/site" "$out" --json > "$tmp/review"; jq -r '.report.review_id' "$tmp/review"; }
apply() { "$cli" build-reviewed "$tmp/site" "$out" "$1" --json > "$tmp/build"; }
reject() {
  local code=0
  "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?
  test "$code" = 1; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"
}
id="$(review)"; apply "$id"
# No-op IDs remain valid while all observed state remains identical.
id="$(review)"
apply "$id"; apply "$id"
jq -e '.report.written==0 and .report.deleted==0' "$tmp/build" >/dev/null
# Same HTML bytes, changed source dependency: old review must fail.
printf '%s\n' '---' '{"listed":true}' '---' '# Home' '' 'Body' > "$tmp/site/content/index.md"
cp -a "$out" "$tmp/before"
reject build-reviewed "$tmp/site" "$out" "$id"
diff -r "$tmp/before" "$out"
id="$(review)"
jq -e '.report.plan.outputs[]|select(.name=="index.html")|.action=="write" and .old_digest==.new_digest and any(.dependencies[];.name=="content/index.md" and .action=="changed")' "$tmp/review" >/dev/null
apply "$id"
# Missing output alters the action even when content and dependencies match.
id="$(review)"
rm "$out/style.css"
cp -a "$out" "$tmp/missing"
reject build-reviewed "$tmp/site" "$out" "$id"
diff -r "$tmp/missing" "$out"
id="$(review)"
jq -e '.report.plan.outputs[]|select(.name=="style.css")|.reason=="output missing" and .old_digest==.new_digest' "$tmp/review" >/dev/null
apply "$id"
# Deletions are reviewed; replaying the pre-delete ID cannot silently proceed.
id="$(review)"
rm "$tmp/site/content/other.md"
reject build-reviewed "$tmp/site" "$out" "$id"
test -f "$out/other.html"
id="$(review)"
jq -e '.report.plan.outputs[]|select(.name=="other.html")|.action=="delete"' "$tmp/review" >/dev/null
apply "$id"
test ! -e "$out/other.html"
reject build-reviewed "$tmp/site" "$out" "$id"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/clean" "$out"
# Review never grants authority to overwrite manual edits or foreign entries.
id="$(review)"
printf 'manual' > "$out/index.html"
reject build-reviewed "$tmp/site" "$out" "$id"
test "$(cat "$out/index.html")" = manual
cp "$tmp/clean/index.html" "$out/index.html"
printf 'foreign' > "$out/foreign"
reject build-reviewed "$tmp/site" "$out" "$id"
test "$(cat "$out/foreign")" = foreign
rm "$out/foreign"
# Pause the real reviewed CLI after its exclusive lock, before planning.
# A competing operation is refused; a source edit is seen by the locked recheck.
cc -Wall -Wextra -Werror -shared -fPIC tests/native/pause_lock.c -ldl -o "$tmp/pause.so"
id="$(review)"
MOONPRESS_TEST_LOCK_READY="$tmp/ready" MOONPRESS_TEST_LOCK_RELEASE="$tmp/release" \
  LD_PRELOAD="$tmp/pause.so" "$cli" build-reviewed "$tmp/site" "$out" "$id" --json > "$tmp/writer-out" 2> "$tmp/writer-error" &
writer=$!
for ((i=0; i<250; i++)); do
  [[ -f "$tmp/ready" ]] && break
  kill -0 "$writer"
  sleep 0.02
done
test -f "$tmp/ready"
reject review "$tmp/site" "$out"
grep -Fq 'Output parent is busy' "$tmp/stderr"
reject build "$tmp/site" "$out"
grep -Fq 'Output parent is busy' "$tmp/stderr"
printf '\nChanged under lock\n' >> "$tmp/site/content/index.md"
touch "$tmp/release"
code=0; wait "$writer" || code=$?; writer=''
test "$code" = 1
test ! -s "$tmp/writer-out"
grep -Fq 'Reviewed build plan changed' "$tmp/writer-error"
diff -r "$tmp/clean" "$out"
id="$(review)"; apply "$id"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/clean" "$out"
echo 'Reviewed transition tests passed: identical bytes/dependency changes, missing output, deletion, replay, ownership, exclusive lock recheck and clean parity.'
