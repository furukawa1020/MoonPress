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
printf '{"base_url":"https://example.org/"}' > "$tmp/site/site.json"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp -a "$tmp/site" "$tmp/valid"
cp -a "$tmp/out" "$tmp/before"
reject() {
  local input="$1" command status
  for command in check explain build; do
    local operands=("$input")
    if [[ "$command" != check ]]; then operands+=("$tmp/out"); fi
    status=0
    # A FIFO regression must fail promptly, not hang the test runner.
    timeout 5 "$cli" "$command" "${operands[@]}" --json >"$tmp/log" 2>"$tmp/error" || status=$?
    test "$status" -eq 1
    test ! -s "$tmp/log"
    grep -q 'Expected regular input' "$tmp/error"
    diff -r "$tmp/out" "$tmp/before"
  done
  status=0
  timeout 5 "$cli" build "$input" "$tmp/fresh" --json >"$tmp/log" 2>"$tmp/error" || status=$?
  test "$status" -eq 1
  test ! -e "$tmp/fresh"
}
reset_site() {
  rm -rf "$tmp/site"
  cp -a "$tmp/valid" "$tmp/site"
}
for path in layout.html style.css content; do
  reset_site
  rm -rf "$tmp/site/$path"
  reject "$tmp/site"
done
printf 'not a directory' > "$tmp/root-file"
reject "$tmp/root-file"
for path in layout.html style.css site.json content/index.md; do
  for kind in symlink dangling fifo directory; do
    reset_site
    rm "$tmp/site/$path"
    case "$kind" in
      symlink) ln -s "$tmp/valid/$path" "$tmp/site/$path" ;;
      dangling) ln -s "$tmp/missing" "$tmp/site/$path" ;;
      fifo) mkfifo "$tmp/site/$path" ;;
      directory) mkdir "$tmp/site/$path" ;;
    esac
    reject "$tmp/site"
  done
done
reset_site
mv "$tmp/site/content" "$tmp/moved-content"
ln -s "$tmp/moved-content" "$tmp/site/content"
reject "$tmp/site"
reset_site
ln -s "$tmp/site" "$tmp/site-link"
reject "$tmp/site-link/"
reset_site
mkdir "$tmp/site/content/nested"
printf '# Hidden article\n' > "$tmp/site/content/nested/article.md"
reject "$tmp/site"
reset_site
mkfifo "$tmp/site/content/editor.tmp"
reject "$tmp/site"
reset_site
ln -s "$tmp/missing" "$tmp/site/content/editor.tmp"
reject "$tmp/site"
reset_site
# Ordinary non-Markdown files stay ignored, optional config may be absent.
printf 'notes' > "$tmp/site/content/notes.txt"
rm "$tmp/site/site.json"
"$cli" check "$tmp/site/" --json | jq -e '.report.pages == 1' >/dev/null
"$cli" build "$tmp/site/" "$tmp/out" >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
echo 'Source preflight tests passed: required/optional inputs, dangling links, FIFO timeout protection, nested content and valid flat inputs.'
