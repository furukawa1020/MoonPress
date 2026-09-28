#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/work"
printf 'unmanaged sentinel\n' > "$tmp/work/precious"
cp -a "$tmp/work" "$tmp/before"
# An empty/non-site working directory must not prevent help or version.
cd "$tmp/work"
success() {
  "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr"
  test -s "$tmp/stdout"
  test ! -s "$tmp/stderr"
  diff -r "$tmp/work" "$tmp/before"
}
success
cp "$tmp/stdout" "$tmp/global"
for flag in --help -h; do
  success "$flag"
  cmp "$tmp/stdout" "$tmp/global"
  for command in build check explain; do
    success "$command" "$flag"
    grep -Fq "Usage: moonpress $command <site-directory>" "$tmp/stdout"
    grep -Fq -- '--json' "$tmp/stdout"
    grep -Fq -- '--include-drafts' "$tmp/stdout"
    grep -Fq 'WILL contain draft pages' "$tmp/stdout"
    grep -Fq '0 success, 1 validation/I/O failure, 2 incorrect arguments' "$tmp/stdout"
  done
done
grep -Fq 'Commands:' "$tmp/global"
success --version
test "$(cat "$tmp/stdout")" = 'moonpress 0.1.0'
failure() {
  local status=0
  "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" -eq 2
  test ! -s "$tmp/stdout"
  grep -Fq 'Usage:' "$tmp/stderr"
  diff -r "$tmp/work" "$tmp/before"
}
for flag in --help -h; do
  failure "$flag" --json
  failure --version "$flag"
  failure unknown "$flag"
  for command in build check explain; do
    failure "$command" "$flag" --json
    failure "$command" "$flag" "$flag"
    failure "$command" "$flag" missing
    failure "$command" missing "$flag"
    failure "$command" missing absent "$flag"
  done
done
echo 'CLI help tests passed: global/command help, version, strict grammar, channels and no filesystem mutation.'
