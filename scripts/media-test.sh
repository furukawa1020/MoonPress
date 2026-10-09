#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" media "$tmp/site" --json | jq -e '.schema==1 and .command=="media" and .report.items==[]' >/dev/null
mkdir "$tmp/site/public"
printf '\000\377\001binary' > "$tmp/site/public/画像 (a)&.PNG"
printf 'PDF bytes' > "$tmp/site/public/a.pdf"
cp -a "$tmp/site" "$tmp/before"
"$cli" media "$tmp/site" --json > "$tmp/report"
jq -e '.report.items | length==2' "$tmp/report" >/dev/null
jq -e '.report.items[0] | .source=="public/a.pdf" and .image==false and .bytes==9' "$tmp/report" >/dev/null
jq -e '.report.items[1] | .url=="%E7%94%BB%E5%83%8F%20%28a%29%26.PNG" and .image==true' "$tmp/report" >/dev/null
test "$(jq -r '.report.items[1].digest' "$tmp/report")" = "$(sha256sum "$tmp/site/public/画像 (a)&.PNG" | cut -d' ' -f1)"
"$cli" media "$tmp/site" > "$tmp/text"
grep -Fq 'Media: 2' "$tmp/text"
diff -r "$tmp/site" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cmp "$tmp/site/public/画像 (a)&.PNG" "$tmp/out/画像 (a)&.PNG"
reject() {
  local status=0
  timeout 5 "$cli" media "$tmp/site" --json > "$tmp/stdout" 2> "$tmp/stderr" || status=$?
  test "$status" = 1
  test ! -s "$tmp/stdout"
  test -s "$tmp/stderr"
}
printf 'bad' > "$tmp/site/public/bad.js"; reject; rm "$tmp/site/public/bad.js"
ln -s a.pdf "$tmp/site/public/link.pdf"; reject; rm "$tmp/site/public/link.pdf"
mkfifo "$tmp/site/public/pipe.txt"; reject; rm "$tmp/site/public/pipe.txt"
mkdir "$tmp/site/public/nested"; reject; rmdir "$tmp/site/public/nested"
mv "$tmp/site/public" "$tmp/public"
ln -s "$tmp/public" "$tmp/site/public"; reject; rm "$tmp/site/public"
mv "$tmp/public" "$tmp/site/public"
diff -r "$tmp/site" "$tmp/before"
"$cli" media --help | grep -Fq 'No --include-drafts option'
for option in --include-drafts --bad; do
  if "$cli" media "$tmp/site" "$option" > "$tmp/args" 2>&1; then exit 1; else test "$?" = 2; fi
done
echo 'Media tests passed: binary digests, URLs, optional public directory, strict sources, CLI grammar and no mutation.'
