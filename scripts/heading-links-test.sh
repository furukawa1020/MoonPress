#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '<a href="guide.html#mp-guide">Guide</a>{{toc}}<main id="main">{{content}}</main>' > "$tmp/site/layout.html"
printf 'body {}' > "$tmp/site/style.css"
printf '{"base_url":"https://example.org/MoonPress/"}' > "$tmp/site/site.json"
printf '<svg/>' > "$tmp/site/public/image.svg"
cat > "$tmp/site/content/index.md" <<'MD'
---
{"tags":["core"]}
---
# Home
[Self](#mp-home) [Query](?x=12:30#mp-home)
[Guide](%67uide.html#mp-guide) [Repeat](guide.html#mp-repeat-2-2)
[日本語](/MoonPress/guide.html#mp-%e6%97%a5%e6%9c%ac%e8%aa%9e)
[Custom](#main) [External](https://example.org/#mp-unknown)
[SVG](image.svg#mp-symbol)
`[Ignored](#mp-unknown)`
~~~
[Ignored](guide.html#mp-unknown)
~~~
MD
printf '# Guide\n## Repeat\n## Repeat\n## Repeat-2\n## 日本語\n' > "$tmp/site/content/guide.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' '[Broken](#mp-unknown)' > "$tmp/site/content/draft.md"
cp -a "$tmp/site" "$tmp/original"
"$cli" check "$tmp/site" --json >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json >/dev/null
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
cp -a "$tmp/out" "$tmp/before"
reject_all() {
  for command in check explain build; do
    args=("$command" "$tmp/site")
    if [[ "$command" != check ]]; then args+=("$tmp/out"); fi
    status=0
    "$cli" "${args[@]}" --json >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
    test "$status" -eq 1
    test ! -s "$tmp/stdout"
    grep -q 'heading link\|fragment escape' "$tmp/stderr"
    diff -r "$tmp/out" "$tmp/before"
    test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
  done
}
# An unchanged referring page still fails when the target heading is renamed.
sed -i 's/## 日本語/## Changed/' "$tmp/site/content/guide.md"
reject_all
grep -q 'index.html' "$tmp/stderr"
cp "$tmp/original/content/guide.md" "$tmp/site/content/guide.md"
for href in '#mp-unknown' 'guide.html#mp-repeat-3' 'articles.html#mp-home' '#mp-%GG'; do
  cp "$tmp/original/content/index.md" "$tmp/site/content/index.md"
  printf '\n[Broken](%s)\n' "$href" >> "$tmp/site/content/index.md"
  reject_all
done
cp "$tmp/original/content/index.md" "$tmp/site/content/index.md"
# Static fragment-only layout links are checked on collections too.
for name in index guide; do printf '\n## Shared\n' >> "$tmp/site/content/$name.md"; done
printf '<a href="#mp-shared">Shared</a>{{content}}' > "$tmp/site/layout.html"
reject_all
grep -Fq 'layout.html (articles.html)' "$tmp/stderr"
for name in index guide; do cp "$tmp/original/content/$name.md" "$tmp/site/content/$name.md"; done
cp "$tmp/original/layout.html" "$tmp/site/layout.html"
# Excluded drafts are skipped; preview validates their headings and references.
status=0
"$cli" check "$tmp/site" --include-drafts --json >"$tmp/stdout" 2>"$tmp/stderr" || status=$?
test "$status" -eq 1
grep -q 'draft.html: broken heading link' "$tmp/stderr"
sed -i 's/#mp-unknown/#mp-draft/' "$tmp/site/content/draft.md"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
# Valid changes preserve the incremental/clean contract and unchanged page mtimes.
printf '\n## Added\n' >> "$tmp/site/content/guide.md"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/explain"
diff -r "$tmp/out" "$tmp/before"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/explain") <(jq -S '.report' "$tmp/build")
test "$(stat -c %Y "$tmp/out/index.html")" = 946684800
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
echo 'Heading link tests passed: same/cross-page anchors, Unicode, incremental invalidation, layouts, drafts, no mutation and clean parity.'
