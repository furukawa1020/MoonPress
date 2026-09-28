#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
mkdir -p "$tmp/site/content"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
for name in a z obsolete; do printf '# %s\nOld\n' "$name" > "$tmp/site/content/$name.md"; done
"$cli" build "$tmp/site" "$tmp/old" >/dev/null
rm "$tmp/old/style.css"
printf '\nNew\n' >> "$tmp/site/content/a.md"
rm "$tmp/site/content/obsolete.md"
printf '# New\n' > "$tmp/site/content/n.md"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
reset_output() {
  rm -rf "$tmp/out"
  cp -a "$tmp/old" "$tmp/out"
}
for operation in OPEN WRITE CLOSE; do
  reset_output
  status=0
  env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$operation=$tmp/out/.moonpress-stage/journal" \
    "$cli" build "$tmp/site" "$tmp/out" --json >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/stdout"
  grep -q 'Staging failed before existing artifacts were changed' "$tmp/stderr"
  diff -r "$tmp/old" "$tmp/out"
done
for phase in BEFORE AFTER; do
  reset_output
  status=0
  env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_KILL_${phase}_RENAME=$tmp/out/a.html" \
    "$cli" build "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
  test "$status" -eq 137
  journal="$tmp/out/.moonpress-stage/journal"
  jq -e '.schema == 1 and (.writes | index("a.html") != null) and
    (.writes | index("style.css") != null) and (.present | index("style.css") == null) and
    (.present | index("obsolete.html") != null)' "$journal" >/dev/null
  jq -rj '.previous' "$journal" > "$tmp/previous"
  jq -rj '.next' "$journal" > "$tmp/next"
  cmp "$tmp/previous" "$tmp/old/.moonpress.json"
  cmp "$tmp/next" "$tmp/clean/.moonpress.json"
  cmp "$tmp/out/.moonpress-stage/backup/a.html" "$tmp/old/a.html"
  cmp "$tmp/out/.moonpress-stage/backup/obsolete.html" "$tmp/old/obsolete.html"
  if [[ "$phase" == BEFORE ]]; then
    diff -r --exclude=.moonpress-stage "$tmp/out" "$tmp/old"
  else
    cmp "$tmp/out/a.html" "$tmp/clean/a.html"
  fi
  # A journal alone does not grant permission to build over crash remnants.
  cp -a "$tmp/out" "$tmp/snapshot-$phase"
  if "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/stderr"; then exit 1; fi
  diff -r "$tmp/out" "$tmp/snapshot-$phase"
done
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_BEFORE_RENAME="$tmp/fresh/a.html" \
  "$cli" build "$tmp/site" "$tmp/fresh" >/dev/null 2>"$tmp/stderr" || status=$?
test "$status" -eq 137
jq -e '.previous == null and .present == []' "$tmp/fresh/.moonpress-stage/journal" >/dev/null
test ! -e "$tmp/fresh/.moonpress.json"
echo 'Journal tests passed: complete pre-publication state, fresh/missing/stale files, write failures and SIGKILL boundaries.'
