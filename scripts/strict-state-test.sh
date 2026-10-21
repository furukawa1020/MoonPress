#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '# A\n' > "$tmp/site/content/a.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/valid"
reject() { local status=0; "$@" > "$tmp/stdout" 2> "$tmp/error" || status=$?; test "$status" = 1; test ! -s "$tmp/stdout"; grep -Fq 'unknown field' "$tmp/error"; }
for mutation in '.unexpected=true' '.artifacts[0].unexpected=true' '.artifacts[0].dependencies[0].unexpected=true'; do
  jq "$mutation" "$tmp/valid/.moonpress.json" > "$tmp/out/.moonpress.json"
  cp -a "$tmp/out" "$tmp/before"
  for command in build explain plan; do reject "$cli" "$command" "$tmp/site" "$tmp/out" --json; done
  reject "$cli" audit "$tmp/out" --json
  reject "$cli" diff "$tmp/valid/.moonpress.json" "$tmp/out/.moonpress.json" --json
  diff -r "$tmp/out" "$tmp/before"
  rm -rf "$tmp/before"
done
cp "$tmp/valid/.moonpress.json" "$tmp/out/.moonpress.json"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written==0' >/dev/null
# Leave a genuine interrupted publication, then extend journal fields and embedded state.
cc -Wall -Wextra -Werror -shared -fPIC tests/native/fail_publication.c -ldl -o "$tmp/fault.so"
printf '\nChanged\n' >> "$tmp/site/content/a.md"
status=0
env LD_PRELOAD="$tmp/fault.so" MOONPRESS_TEST_KILL_BEFORE_RENAME="$tmp/out/a.html" "$cli" build "$tmp/site" "$tmp/out" > "$tmp/stdout" 2> "$tmp/error" || status=$?
test "$status" = 137
journal="$tmp/out/.moonpress-stage/journal"
record="$tmp/.moonpress-recovery-$(printf out | sha256sum | cut -d' ' -f1).json"
cp "$journal" "$tmp/original-journal"
for mutation in '.unexpected=true' '.previous|=(fromjson|.unexpected=true|tojson)' '.next|=(fromjson|.artifacts[0].unexpected=true|tojson)' '.next|=(fromjson|.artifacts[0].dependencies[0].unexpected=true|tojson)'; do
  jq "$mutation" "$tmp/original-journal" > "$journal"
  cp "$journal" "$record"
  cp -a "$tmp/out" "$tmp/before"
  reject "$cli" recover "$tmp/out" --json
  diff -r "$tmp/out" "$tmp/before"
  rm -rf "$tmp/before"
done
cp "$tmp/original-journal" "$journal"
cp "$tmp/original-journal" "$record"
"$cli" recover "$tmp/out" >/dev/null
diff -r "$tmp/out" "$tmp/valid"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
echo 'Strict state tests passed: unknown top-level/nested/embedded fields refused before mutation, valid recovery and clean parity.'
