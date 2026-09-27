#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '<img src="/project/moon.svg" alt="Logo">{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '{"base_url":"https://example.org/project/"}' > "$tmp/site/site.json"
printf '# Home\n\n![月](moon.svg)\n\n- ![月](moon.svg)\n> ![月](moon.svg)\n\n`![example](ghost.png)`\n' > "$tmp/site/content/index.md"
printf '<svg xmlns="http://www.w3.org/2000/svg"/>' > "$tmp/site/public/moon.svg"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
grep -q '<img src="moon.svg" alt="月">' "$tmp/out/index.html"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
printf '\n' >> "$tmp/site/public/moon.svg"
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 1' "$tmp/log"
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" > /dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/before"
reject() {
  for command in build explain; do
    if "$cli" "$command" "$tmp/site" "$tmp/out" > /dev/null 2>"$tmp/error"; then exit 1; fi
    test -s "$tmp/error"
    diff -r "$tmp/out" "$tmp/before"
  done
}
rm "$tmp/site/public/moon.svg"
reject
printf '<svg/>' > "$tmp/site/public/moon.svg"
for src in missing.png mailto:x data:image/png javascript:x //host/x; do
  printf '# Home\n\n![x](%s)\n' "$src" > "$tmp/site/content/index.md"
  reject
done
printf '# Home\n' > "$tmp/site/content/index.md"
printf '<img src="missing.png">{{content}}' > "$tmp/site/layout.html"
reject
printf '<img src=moon.svg>{{content}}' > "$tmp/site/layout.html"
reject
echo 'Image tests passed: rendering, asset-only updates, clean equivalence and preflight Markdown/template source validation.'
