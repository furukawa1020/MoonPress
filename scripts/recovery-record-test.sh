#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/old"
printf '\nchanged\n' >> "$tmp/site/content/index.md"
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_BEFORE_RENAME="$tmp/out/.moonpress.json" "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 137
record="$tmp/.moonpress-recovery-$(printf out | sha256sum | cut -d' ' -f1).json"
cp "$record" "$tmp/good"
cp -a "$tmp/out" "$tmp/crashed"
for kind in conflict fifo symlink directory oversized; do
  rm -rf "$record"
  case "$kind" in
    conflict) printf '{}' > "$record" ;;
    fifo) mkfifo "$record" ;;
    symlink) ln -s "$tmp/good" "$record" ;;
    directory) mkdir "$record" ;;
    oversized) truncate -s 67108865 "$record" ;;
  esac
  for command in recovery-plan recover; do
    status=0
    timeout 10 "$cli" "$command" "$tmp/out" --json >/dev/null 2>&1 || status=$?
    test "$status" -eq 1
    diff -r "$tmp/crashed" "$tmp/out"
  done
done
rm "$record"
cp "$tmp/good" "$record"
mv "$tmp/out" "$tmp/missing-output"
for command in recovery-plan recover; do
  status=0
  "$cli" "$command" "$tmp/out" --json >/dev/null 2>&1 || status=$?
  test "$status" -eq 1
  test ! -e "$tmp/out"
  cmp "$record" "$tmp/good"
done
mv "$tmp/missing-output" "$tmp/out"
rm "$record"
# Legacy journals must remain recoverable without creating a parent hard link.
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_LINK="$record" MOONPRESS_TEST_FAIL_INSTALL="$record" "$cli" recover "$tmp/out" --json | jq -e '.report.action == "rolled_back"' >/dev/null
diff -r "$tmp/old" "$tmp/out"
test ! -e "$record"
echo 'Recovery records passed: unsafe/conflicting records fail without mutation; legacy recovery needs no parent write.'
# A legacy first-build rollback needs a retained record before removing output.
rm -r "$tmp/out"
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_BEFORE_RENAME="$tmp/out/.moonpress.json" "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 137
rm "$record"
cp -a "$tmp/out" "$tmp/fresh-crashed"
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_INSTALL="$record" "$cli" recover "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 1
diff -r "$tmp/fresh-crashed" "$tmp/out"
test ! -e "$record"
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_RMDIR="$tmp/out" "$cli" recover "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 1
test -s "$record"
test -d "$tmp/out"
test ! -e "$tmp/out/.moonpress-stage"
"$cli" recovery-plan "$tmp/out" --json | jq -e '.report.action == "rolled_back"' >/dev/null
"$cli" recover "$tmp/out" --json | jq -e '.report.action == "rolled_back"' >/dev/null
test ! -e "$tmp/out"
test ! -e "$record"
cp -a "$tmp/fresh-crashed" "$tmp/out"
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_AFTER_RMDIR="$tmp/out" "$cli" recover "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 137
test -s "$record"
test ! -e "$tmp/out"
"$cli" recover "$tmp/out" --json | jq -e '.report.action == "rolled_back"' >/dev/null
test ! -e "$record"
echo 'Legacy fresh rollback passed: parent denial preserves remnants; output removal failure retains retry authority.'
