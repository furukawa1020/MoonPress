#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '# 月🌙\n\n本文\n' > "$tmp/site/content/index.md"
printf '{"base_url":"https://example.org/"}' > "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/site" "$tmp/valid"
cp -a "$tmp/out" "$tmp/before"
reject() {
  local command="$1" path="$2" status=0
  local args=("$command" "$tmp/site")
  if [[ "$command" != check ]]; then args+=("$tmp/out"); fi
  "$cli" "${args[@]}" --json >"$tmp/log" 2>"$tmp/error" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/log"
  grep -Fq "Invalid UTF-8 text: $path" "$tmp/error"
  diff -r "$tmp/out" "$tmp/before"
}
for bytes in '\xe3\x81' '\xc0\xaf' '\xe3x\x82' '\xff' '\xed\xa0\x80'; do
  for path in layout.html content/index.md site.json; do
    printf '%b' "$bytes" > "$tmp/site/$path"
    for command in check explain build; do reject "$command" "$tmp/site/$path"; done
    cmp <(printf '%b' "$bytes") "$tmp/site/$path"
    cp "$tmp/valid/$path" "$tmp/site/$path"
  done
done
# A corrupt manifest is output state: check remains independent of it.
printf '\xff' >> "$tmp/out/.moonpress.json"
cp "$tmp/out/.moonpress.json" "$tmp/before/.moonpress.json"
"$cli" check "$tmp/site" --json >/dev/null
reject explain "$tmp/out/.moonpress.json"
reject build "$tmp/out/.moonpress.json"
# Byte assets and CSS are never interpreted as UTF-8.
printf '\xff\xc0\x00' > "$tmp/site/public/raw.png"
printf '\xff\xc0\x00' > "$tmp/site/style.css"
printf '\xef\xbb\xbf{{content}}' > "$tmp/site/layout.html"
"$cli" build "$tmp/site" "$tmp/raw" >/dev/null
cmp "$tmp/site/public/raw.png" "$tmp/raw/raw.png"
cmp "$tmp/site/style.css" "$tmp/raw/style.css"
cmp <(printf '\xef\xbb\xbf') <(head -c 3 "$tmp/raw/index.html")
grep -q '月🌙' "$tmp/raw/index.html"
"$cli" build "$tmp/site" "$tmp/raw" --json | jq -e '.report.written == 0' >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/raw" "$tmp/clean"
echo 'UTF-8 input tests passed: invalid sequences, diagnostics, no mutation, BOM, Unicode and binary passthrough.'
