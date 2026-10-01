#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" new "$tmp/site" article 'Article' >/dev/null
post="$tmp/site/content/article.md"
stage="$tmp/site/content/.moonpress-edit"
"$cli" read "$tmp/site" article.md --json > "$tmp/snapshot"
version="$(jq -r '.report.digest' "$tmp/snapshot")"
test "$version" = "$(sha256sum "$post" | cut -d ' ' -f1)"
jq -j '.report.content' "$tmp/snapshot" > "$tmp/replacement"
cmp "$post" "$tmp/replacement"
chmod 640 "$post"
touch -t 200001010000 "$post"
"$cli" save "$tmp/site" article.md "$version" "$tmp/replacement" --json | jq -e '.report.changed == false' >/dev/null
test "$(stat -c %Y "$post")" = 946684800
printf '\nNew body 月\n' >> "$tmp/replacement"
"$cli" save "$tmp/site" article.md "$version" "$tmp/replacement" --json | jq -e '.command == "save" and .report.changed == true' >/dev/null
cmp "$post" "$tmp/replacement"
test "$(stat -c %a "$post")" = 640
test ! -e "$stage"
failure() {
  local expected="$1" status=0
  shift
  "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" = "$expected"
  test ! -s "$tmp/stdout"
  test -s "$tmp/stderr"
}
cp -a "$tmp/site" "$tmp/before"
failure 1 "$cli" save "$tmp/site" article.md "$version" "$tmp/replacement"
grep -Fq 'changed since it was read' "$tmp/stderr"
diff -r "$tmp/site" "$tmp/before"
version="$("$cli" read "$tmp/site" article.md --json | jq -r '.report.digest')"
printf '%s\n' '---' '{"draft":"wrong"}' '---' > "$tmp/invalid"
failure 1 "$cli" save "$tmp/site" article.md "$version" "$tmp/invalid"
printf '\377' > "$tmp/invalid"
failure 1 "$cli" save "$tmp/site" article.md "$version" "$tmp/invalid"
failure 1 "$cli" save "$tmp/site" article.md wrong "$tmp/replacement"
failure 1 "$cli" read "$tmp/site" ../article.md
failure 1 "$cli" read "$tmp/site" missing.md
ln -s "$post" "$tmp/site/content/link.md"
failure 1 "$cli" read "$tmp/site" link.md
failure 1 "$cli" save "$tmp/site" link.md "$version" "$tmp/replacement"
rm "$tmp/site/content/link.md"
diff -r "$tmp/site" "$tmp/before"
printf '\nNext body\n' >> "$tmp/replacement"
printf sentinel > "$stage"
failure 1 "$cli" save "$tmp/site" article.md "$version" "$tmp/replacement"
test "$(cat "$stage")" = sentinel
rm "$stage"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
metadata="$(stat -c '%i %a %Y' "$post")"
for fault in OPEN WRITE FLUSH CLOSE; do
  failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_$fault=$stage" "$cli" save "$tmp/site" article.md "$version" "$tmp/replacement"
  test ! -e "$stage"
  diff -r "$tmp/site" "$tmp/before"
  test "$(stat -c '%i %a %Y' "$post")" = "$metadata"
done
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_RENAME=$post" "$cli" save "$tmp/site" article.md "$version" "$tmp/replacement"
diff -r "$tmp/site" "$tmp/before"
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_FAIL_WRITE=$stage" "MOONPRESS_TEST_FAIL_REMOVE=$stage" "$cli" save "$tmp/site" article.md "$version" "$tmp/replacement"
grep -Fq 'cleanup incomplete' "$tmp/stderr"
cmp "$post" "$tmp/before/content/article.md"
failure 1 "$cli" save "$tmp/site" article.md "$version" "$tmp/replacement"
rm "$stage"
# Simulate an external edit during staging; recheck must preserve that edit.
failure 1 env LD_PRELOAD="$tmp/fault.so" "MOONPRESS_TEST_EDIT_ON_CLOSE=$stage" "MOONPRESS_TEST_EDIT_TARGET=$post" "$cli" save "$tmp/site" article.md "$version" "$tmp/replacement"
test "$(cat "$post")" = '# External edit'
test ! -e "$stage"
version="$("$cli" read "$tmp/site" article.md --json | jq -r '.report.digest')"
"$cli" save "$tmp/site" article.md "$version" "$tmp/replacement" >/dev/null
"$cli" check "$tmp/site" --include-drafts >/dev/null
for command in read save; do
  "$cli" "$command" --help | grep -Fq "Usage: moonpress $command"
  failure 2 "$cli" "$command"
done
failure 2 "$cli" read "$tmp/site" article.md --include-drafts
failure 2 "$cli" save "$tmp/site" article.md "$version" "$tmp/replacement" --json --json
echo 'Post editor tests passed: snapshots, version conflicts, staging, permissions, no-op, fault cleanup and external edits before commit.'
