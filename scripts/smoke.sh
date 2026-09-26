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
if "$cli" build site "$tmp/first" >"$tmp/error" 2>&1; then
  echo 'ERROR: existing output was accepted' >&2; exit 1
fi
if "$cli" build "$tmp/missing" "$tmp/absent" >"$tmp/error" 2>&1; then
  echo 'ERROR: missing input was accepted' >&2; exit 1
fi
test ! -e "$tmp/absent"
if "$cli" bogus >"$tmp/error" 2>&1; then
  echo 'ERROR: invalid command was accepted' >&2; exit 1
fi
if grep -REin '<script|javascript:|on(click|load|error)=' "$tmp/first"; then
  echo 'ERROR: executable JavaScript in generated sample' >&2; exit 1
fi
printf 'Native binary bytes: '
wc -c < "$cli"
echo 'Smoke tests passed: deterministic output, error handling, no JS in sample.'
