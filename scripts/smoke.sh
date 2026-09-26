#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" --version
"$cli" build site "$tmp/first"
"$cli" build site "$tmp/second"
diff -r "$tmp/first" "$tmp/second"
grep -q '<h1>MoonPress</h1>' "$tmp/first/index.html"
grep -q 'href="style.css"' "$tmp/first/index.html"
test -s "$tmp/first/style.css"
expect_failure() {
  local expected="$1"
  shift
  local status=0
  "$cli" "$@" >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
  test "$status" -eq "$expected"
  test ! -s "$tmp/stdout"
  test -s "$tmp/stderr"
}
mkdir "$tmp/unmanaged"
expect_failure 1 build site "$tmp/unmanaged"
expect_failure 1 build "$tmp/missing" "$tmp/absent"
test ! -e "$tmp/absent"
expect_failure 2 bogus
if grep -REin '<script|javascript:|on(click|load|error)=' "$tmp/first"; then
  echo 'ERROR: executable JavaScript in generated sample' >&2; exit 1
fi
printf 'Native binary bytes: '
wc -c < "$cli"
echo 'Smoke tests passed: deterministic output, error handling, no JS in sample.'
