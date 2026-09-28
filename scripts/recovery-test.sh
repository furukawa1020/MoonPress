#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
holder=''
cleanup() {
  if [[ -n "$holder" ]]; then kill -KILL "$holder" 2>/dev/null || true; wait "$holder" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
cc -Wall -Wextra -Werror -shared -fPIC tests/native/pause_lock.c -ldl -o "$tmp/pause.so"
mkdir -p "$tmp/site/content"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
for name in a z keep obsolete; do printf '# %s\nOld\n' "$name" > "$tmp/site/content/$name.md"; done
cp -a "$tmp/site" "$tmp/original-site"
"$cli" build "$tmp/site" "$tmp/old" >/dev/null
rm "$tmp/old/style.css"
for name in a z; do printf '\nNew\n' >> "$tmp/site/content/$name.md"; done
rm "$tmp/site/content/obsolete.md"
printf '# New\n' > "$tmp/site/content/n.md"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
reset_output() {
  rm -rf "$tmp/out"
  cp -a "$tmp/old" "$tmp/out"
  chmod 640 "$tmp/out/a.html"
  find "$tmp/out" -maxdepth 1 -type f -printf '%f %i %m %T@\n' | sort > "$tmp/metadata"
}
crash() {
  local status=0
  local injection="$1"
  shift
  env LD_PRELOAD="$tmp/fault.so" "$injection" "$cli" "$@" >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
  test "$status" -eq 137
  test ! -s "$tmp/stdout"
}
recover() {
  "$cli" recover "$tmp/out" --json >"$tmp/report" 2>"$tmp/stderr"
  test ! -s "$tmp/stderr"
  jq -e --arg action "$1" '.schema == 1 and .command == "recover" and
    .include_drafts == false and .report.action == $action' "$tmp/report" >/dev/null
  test ! -e "$tmp/out/.moonpress-stage"
}
for injection in \
  "MOONPRESS_TEST_KILL_BEFORE_RENAME=$tmp/out/a.html" \
  "MOONPRESS_TEST_KILL_AFTER_RENAME=$tmp/out/a.html" \
  "MOONPRESS_TEST_KILL_AFTER_RENAME=$tmp/out/z.html" \
  "MOONPRESS_TEST_KILL_AFTER_RENAME=$tmp/out/style.css" \
  "MOONPRESS_TEST_KILL_AFTER_REMOVE=$tmp/out/obsolete.html" \
  "MOONPRESS_TEST_KILL_BEFORE_RENAME=$tmp/out/.moonpress.json"; do
  reset_output
  crash "$injection" build "$tmp/site" "$tmp/out"
  recover rolled_back
  diff -r "$tmp/out" "$tmp/old"
  find "$tmp/out" -maxdepth 1 -type f -printf '%f %i %m %T@\n' | sort > "$tmp/after-metadata"
  cmp "$tmp/metadata" "$tmp/after-metadata"
  recover clean
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
  diff -r "$tmp/out" "$tmp/clean"
done
for injection in \
  "MOONPRESS_TEST_KILL_AFTER_RENAME=$tmp/out/.moonpress.json" \
  "MOONPRESS_TEST_KILL_AFTER_REMOVE=$tmp/out/.moonpress-stage/backup/a.html"; do
  reset_output
  crash "$injection" build "$tmp/site" "$tmp/out"
  recover finalized
  jq -e '.report.restored == 0 and .report.removed == 0' "$tmp/report" >/dev/null
  diff -r "$tmp/out" "$tmp/clean"
done
# Interrupted recovery itself is retryable while the complete journal remains.
for injection in \
  "MOONPRESS_TEST_KILL_AFTER_RENAME=$tmp/out/z.html" \
  "MOONPRESS_TEST_KILL_AFTER_REMOVE=$tmp/out/n.html" \
  "MOONPRESS_TEST_KILL_AFTER_RMDIR=$tmp/out/.moonpress-stage/backup"; do
  reset_output
  crash "MOONPRESS_TEST_KILL_BEFORE_RENAME=$tmp/out/.moonpress.json" build "$tmp/site" "$tmp/out"
  crash "$injection" recover "$tmp/out" --json
  recover rolled_back
  diff -r "$tmp/out" "$tmp/old"
done
# Fresh output rolls back to absence, or finalizes a committed complete build.
for phase in BEFORE AFTER; do
  rm -rf "$tmp/out"
  crash "MOONPRESS_TEST_KILL_${phase}_RENAME=$tmp/out/.moonpress.json" build "$tmp/site" "$tmp/out"
  if [[ "$phase" == BEFORE ]]; then
    recover rolled_back
    test ! -e "$tmp/out"
    recover absent
  else
    recover finalized
    diff -r "$tmp/out" "$tmp/clean"
  fi
done
# An unchanged manifest alone cannot establish commit after repairing missing files.
for phase in BEFORE AFTER; do
  reset_output
  crash "MOONPRESS_TEST_KILL_${phase}_RENAME=$tmp/out/style.css" build "$tmp/original-site" "$tmp/out"
  if [[ "$phase" == BEFORE ]]; then
    recover rolled_back
    diff -r "$tmp/out" "$tmp/old"
  else
    recover finalized
    cmp "$tmp/out/style.css" "$tmp/site/style.css"
  fi
done
# Recover also completes a failed ordinary rollback, without consulting sources.
reset_output
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_FAIL_RENAME="$tmp/out/.moonpress.json" \
  MOONPRESS_TEST_FAIL_ROLLBACK="$tmp/out/a.html" \
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null 2>"$tmp/stderr" || status=$?
test "$status" -eq 1
recover rolled_back
diff -r "$tmp/out" "$tmp/old"
reset_output
crash "MOONPRESS_TEST_KILL_BEFORE_RENAME=$tmp/out/.moonpress.json" build "$tmp/site" "$tmp/out"
cp -a "$tmp/out" "$tmp/crashed"
# Caught recovery I/O failures also leave enough state for a normal retry.
for injection in \
  "MOONPRESS_TEST_FAIL_RENAME=$tmp/out/z.html" \
  "MOONPRESS_TEST_FAIL_REMOVE=$tmp/out/n.html" \
  "MOONPRESS_TEST_FAIL_REMOVE=$tmp/out/.moonpress-stage/journal"; do
  rm -rf "$tmp/out"
  cp -a "$tmp/crashed" "$tmp/out"
  status=0
  env LD_PRELOAD="$tmp/fault.so" "$injection" "$cli" recover "$tmp/out" --json \
    >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/stdout"
  test -s "$tmp/out/.moonpress-stage/journal"
  recover rolled_back
  diff -r "$tmp/out" "$tmp/old"
done
inventory() {
  find "$tmp/out" -printf '%P %y %l %i %m %s %T@\n' | sort
  find "$tmp/out" -type f -exec sha256sum {} + | sort
}
reject() {
  local status=0
  inventory > "$tmp/before"
  timeout 5 "$cli" "$@" >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/stdout"
  test -s "$tmp/stderr"
  inventory > "$tmp/after"
  cmp "$tmp/before" "$tmp/after"
}
for bad in output backup stage unknown backup-unknown stage-unknown symlink backup-symlink journal-symlink fifo journal traversal missing-backup missing-unchanged marker; do
  rm -rf "$tmp/out"
  cp -a "$tmp/crashed" "$tmp/out"
  case "$bad" in
    output) printf 'edited' > "$tmp/out/z.html" ;;
    backup) printf 'edited' > "$tmp/out/.moonpress-stage/backup/z.html" ;;
    stage) printf 'edited' > "$tmp/out/.moonpress-stage/.moonpress.json" ;;
    unknown) printf 'precious' > "$tmp/out/precious" ;;
    backup-unknown) printf 'precious' > "$tmp/out/.moonpress-stage/backup/precious" ;;
    stage-unknown) mkdir "$tmp/out/.moonpress-stage/precious" ;;
    symlink) rm "$tmp/out/z.html"; ln -s "$tmp/clean/z.html" "$tmp/out/z.html" ;;
    backup-symlink) rm -rf "$tmp/out/.moonpress-stage/backup"; ln -s "$tmp/old" "$tmp/out/.moonpress-stage/backup" ;;
    journal-symlink) rm "$tmp/out/.moonpress-stage/journal"; ln -s "$tmp/crashed/.moonpress-stage/journal" "$tmp/out/.moonpress-stage/journal" ;;
    fifo) rm "$tmp/out/z.html"; mkfifo "$tmp/out/z.html" ;;
    journal) printf '{}' > "$tmp/out/.moonpress-stage/journal" ;;
    traversal) jq '.writes += ["../precious"]' "$tmp/out/.moonpress-stage/journal" > "$tmp/bad-journal"; cp "$tmp/bad-journal" "$tmp/out/.moonpress-stage/journal" ;;
    missing-backup) rm "$tmp/out/.moonpress-stage/backup/z.html" ;;
    missing-unchanged) rm "$tmp/out/keep.html" ;;
    marker) printf '{}' > "$tmp/out/.moonpress.json" ;;
  esac
  reject recover "$tmp/out" --json
done
# No journal means no authority to remove even an empty foreign stage.
reset_output
mkdir "$tmp/out/.moonpress-stage"
reject recover "$tmp/out"
# The new manifest alone never permits cleanup of an incomplete committed tree.
reset_output
crash "MOONPRESS_TEST_KILL_AFTER_RENAME=$tmp/out/.moonpress.json" build "$tmp/site" "$tmp/out"
rm "$tmp/out/n.html"
reject recover "$tmp/out" --json
# Killing final cleanup after journal deletion deliberately requires a fresh output.
reset_output
crash "MOONPRESS_TEST_KILL_AFTER_REMOVE=$tmp/out/.moonpress-stage/journal" build "$tmp/site" "$tmp/out"
reject recover "$tmp/out"
# A real competing process holds the same output-parent lock during recovery.
rm -rf "$tmp/out"
cp -a "$tmp/crashed" "$tmp/out"
env LD_PRELOAD="$tmp/pause.so" MOONPRESS_TEST_LOCK_READY="$tmp/ready" \
  MOONPRESS_TEST_LOCK_RELEASE="$tmp/release" "$cli" recover "$tmp/out" >"$tmp/holder" 2>&1 &
holder=$!
for ((i=0; i<500; i++)); do [[ -f "$tmp/ready" ]] && break; sleep 0.01; done
test -f "$tmp/ready"
reject recover "$tmp/out" --json
grep -q 'busy' "$tmp/stderr"
touch "$tmp/release"
wait "$holder"
holder=''
diff -r "$tmp/out" "$tmp/old"
for flag in --help -h; do
  "$cli" recover "$flag" > "$tmp/help"
  grep -q 'Usage: moonpress recover <output-directory>' "$tmp/help"
done
for args in 'recover' 'recover --json' 'recover nowhere --include-drafts' 'recover nowhere --json --json' 'recover nowhere extra'; do
  status=0
  # Intentional splitting: each literal fixture is an argument vector.
  "$cli" $args >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
  test "$status" -eq 2
  test ! -s "$tmp/stdout"
done
echo 'Recovery tests passed: SIGKILL phases, repeated recovery, metadata, fresh/equal manifests, preflight integrity, locks and native CLI reports.'
