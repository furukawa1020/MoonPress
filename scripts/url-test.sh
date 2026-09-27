#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '<a href="%%67uide.html?q=12:30">Guide</a><img src="%%6doon.svg">{{content}}' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '# Home\n\n[Guide](%%67uide.html#part:x)\n![Moon](%%6doon.svg?q=12:30)\n[External](HTTPS://example.org)\n' > "$tmp/site/content/index.md"
printf '# Guide\n' > "$tmp/site/content/guide.md"
printf '<svg/>' > "$tmp/site/public/moon.svg"
"$cli" build "$tmp/site" "$tmp/out" > /dev/null
"$cli" build "$tmp/site" "$tmp/out" > "$tmp/log"
grep -q 'written: 0' "$tmp/log"
cp -a "$tmp/out" "$tmp/before"
for href in 'missing.html?q=https://example.org' '%67host.html#x:y' 'JaVaScRiPt:x' 'moon%2F.svg'; do
  printf '# Home\n\n[Broken](%s)\n' "$href" > "$tmp/site/content/index.md"
  for command in build explain; do
    if "$cli" "$command" "$tmp/site" "$tmp/out" > /dev/null 2>"$tmp/error"; then exit 1; fi
    test -s "$tmp/error"
    diff -r "$tmp/out" "$tmp/before"
  done
done
echo 'URL tests passed: canonical paths, query colons, case-insensitive schemes and preflight integrity.'
