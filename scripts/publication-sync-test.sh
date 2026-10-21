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
printf '\nChanged\n' >> "$tmp/site/content/index.md"
record="$tmp/.moonpress-recovery-$(printf out | sha256sum | cut -d' ' -f1).json"
for injection in "MOONPRESS_TEST_FAIL_EXISTING_SYNC=$tmp/out/.moonpress-stage/backup/index.html" "MOONPRESS_TEST_FAIL_EXISTING_SYNC=$tmp/out/.moonpress.json" "MOONPRESS_TEST_FAIL_DIR_SYNC=$tmp/out/.moonpress-stage/backup" "MOONPRESS_TEST_FAIL_DIR_SYNC=$tmp/out" "MOONPRESS_TEST_FAIL_DIR_CLOSE=$tmp/out/.moonpress-stage/backup"; do
  status=0
  env LD_PRELOAD="$tmp/fault.so" "$injection" "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
  test "$status" -eq 1
  diff -r "$tmp/old" "$tmp/out"
  test ! -e "$record"
done
# The parent is synchronized once when intent is installed and again after preparation.
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_EXISTING_SYNC="$tmp" MOONPRESS_TEST_FAIL_SYNC_ON_CALL=2 "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 1
diff -r "$tmp/old" "$tmp/out"
test ! -e "$record"
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_AFTER_SYNC="$tmp/out/.moonpress-stage/backup" "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 137
"$cli" recover "$tmp/out" >/dev/null
diff -r "$tmp/old" "$tmp/out"
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_SYNC_TRACE="$tmp/trace" "$cli" build "$tmp/site" "$tmp/out" >/dev/null
python3 - "$tmp" <<'PY'
import sys
root=sys.argv[1]
lines=open(root+'/trace').read().splitlines()
first=next(i for i,line in enumerate(lines) if line.startswith('rename '))
positions=[]
for path in ['out/.moonpress-stage/backup/index.html','out/.moonpress.json','out/.moonpress-stage/backup','out/.moonpress-stage','out','']:
 positions.append(max(i for i,line in enumerate(lines[:first]) if line=='sync '+root+('/'+path if path else '')))
assert positions==sorted(positions) and len(set(positions))==len(positions), (positions,lines)
# Repeat the final staging-directory barrier failure, after all payload installs.
open(root+'/stage-sync-count','w').write(str(sum(line=='sync '+root+'/out/.moonpress-stage' for line in lines[:first])))
PY
cp -a "$tmp/out" "$tmp/new"
rm -r "$tmp/out"
cp -a "$tmp/old" "$tmp/out"
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_EXISTING_SYNC="$tmp/out/.moonpress-stage" MOONPRESS_TEST_FAIL_SYNC_ON_CALL="$(cat "$tmp/stage-sync-count")" "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>&1 || status=$?
test "$status" -eq 1
diff -r "$tmp/old" "$tmp/out"
test ! -e "$record"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
diff -r "$tmp/new" "$tmp/out"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/clean" "$tmp/out"
echo 'Publication synchronization passed: preparation ordering, failed barriers preserve old bytes, interrupted preparation recovers.'
