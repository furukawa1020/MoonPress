#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '# Home\n' > "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/out" "$tmp/baseline"
reject() {
  local command="$1" status=0
  shift
  "$cli" "$command" "$tmp/site" "$@" --json >"$tmp/log" 2>"$tmp/error" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/log"
  test -s "$tmp/error"
}
printf -v stem '%*s' 250 ''
stem="${stem// /z}"
# 253-byte source name becomes exactly 255 bytes with the HTML suffix.
printf '# Boundary\n' > "$tmp/site/content/$stem.md"
"$cli" build "$tmp/site" "$tmp/boundary" >/dev/null
test -f "$tmp/boundary/$stem.html"
mv "$tmp/site/content/$stem.md" "$tmp/site/content/${stem}z.md"
reject check
reject explain "$tmp/out"
reject build "$tmp/out"
grep -q 'Invalid output name' "$tmp/error"
diff -r "$tmp/out" "$tmp/baseline"
reject build "$tmp/fresh"
test ! -e "$tmp/fresh"
rm "$tmp/site/content/${stem}z.md"
# Byte length, not character count, governs UTF-8 output names.
unicode=''
for ((i=0; i<83; i++)); do unicode+='月'; done
printf '# Unicode boundary\n' > "$tmp/site/content/${unicode}a.md"
"$cli" check "$tmp/site" >/dev/null
mv "$tmp/site/content/${unicode}a.md" "$tmp/site/content/${unicode}ab.md"
reject check
reject build "$tmp/out"
diff -r "$tmp/out" "$tmp/baseline"
rm "$tmp/site/content/${unicode}ab.md"
# Malformed manifests must fail before touching even otherwise valid output.
for mutation in \
  '.artifacts[0].digest = "bad"' \
  '.artifacts[0].dependencies[0].digest = "bad"' \
  '.artifacts[0].dependencies[0].name = ""' \
  '.artifacts[0].dependencies += [.artifacts[0].dependencies[0]]'; do
  jq "$mutation" "$tmp/baseline/.moonpress.json" > "$tmp/out/.moonpress.json"
  cp -a "$tmp/out" "$tmp/before"
  reject explain "$tmp/out"
  reject build "$tmp/out"
  grep -q 'manifest:' "$tmp/error"
  diff -r "$tmp/out" "$tmp/before"
  rm -rf "$tmp/before"
done
cp "$tmp/baseline/.moonpress.json" "$tmp/out/.moonpress.json"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
diff -r "$tmp/out" "$tmp/baseline"
echo 'Manifest preflight tests passed: byte boundaries, malformed state, no mutation and valid no-op.'
