#!/usr/bin/env bash
set -euo pipefail
export TZ=UTC
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/layouts" "$tmp/site/public"
printf '<main data-layout="default">{{title}}{{toc}}{{content}}</main>' > "$tmp/site/layout.html"
printf '<article data-layout="post"><a href="#mp-shared">Jump</a><img src="moon.svg">{{title}}{{toc}}{{content}}</article>' > "$tmp/site/layouts/post.html"
printf 'invalid unused template' > "$tmp/site/layouts/unused.html"
printf '<svg/>' > "$tmp/site/public/moon.svg"
printf 'body {}' > "$tmp/site/style.css"
printf '{"base_url":"https://example.org/project/"}' > "$tmp/site/site.json"
printf '# Home\n' > "$tmp/site/content/index.md"
for page in a b; do
  printf '%s\n' '---' '{"layout":"post.html","tags":["core"]}' '---' '# Shared' > "$tmp/site/content/$page.md"
done
printf '%s\n' '---' '{"draft":true,"layout":"missing.html"}' '---' '# Draft' > "$tmp/site/content/draft.md"
"$cli" check "$tmp/site" --json | jq -e '.report.pages == 3' >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
for page in a b; do
  grep -Fq 'data-layout="post"' "$tmp/out/$page.html"
  jq -e --arg page "$page.html" '[.artifacts[] | select(.name == $page) | .dependencies[].name] | index("layouts/post.html") != null and index("layout.html") == null' "$tmp/out/.moonpress.json" >/dev/null
done
for page in index articles tag-636f7265; do
  grep -Fq 'data-layout="default"' "$tmp/out/$page.html"
done
# The same template's fragment must exist in every page that selects it.
cp "$tmp/site/content/b.md" "$tmp/b.md"
cp -a "$tmp/out" "$tmp/shared-valid"
sed -i 's/# Shared/# Different/' "$tmp/site/content/b.md"
for command in explain build; do
  if "$cli" "$command" "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
  grep -Fq 'layouts/post.html (b.html)' "$tmp/stderr"
  diff -r "$tmp/out" "$tmp/shared-valid"
done
cp "$tmp/b.md" "$tmp/site/content/b.md"
# Unused template contents neither get read nor enter dependencies.
printf '\377' > "$tmp/site/layouts/unused.html"
find "$tmp/out" -type f -exec touch -t 200001010000 {} +
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 0' >/dev/null
test "$(stat -c %Y "$tmp/out/a.html")" = 946684800
sed -i 's/data-layout="post"/data-layout="updated"/' "$tmp/site/layouts/post.html"
cp -a "$tmp/out" "$tmp/before"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/plan"
diff -r "$tmp/out" "$tmp/before"
jq -e '.report.written == 2 and ([.report.changes[] | select(.action == "write") | .path] | sort == ["a.html","b.html"])' "$tmp/plan" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/plan") <(jq -S '.report' "$tmp/build")
test "$(stat -c %Y "$tmp/out/articles.html")" = 946684800
sed -i 's/default/default-updated/' "$tmp/site/layout.html"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 3' >/dev/null
sed -i 's/"layout":"post.html",//' "$tmp/site/content/b.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
grep -Fq 'data-layout="default-updated"' "$tmp/out/b.html"
sed -i 's/updated/again/' "$tmp/site/layouts/post.html"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
cp -a "$tmp/out" "$tmp/valid"
cp "$tmp/site/layouts/post.html" "$tmp/post.html"
assert_rejected() {
  if timeout 10 "$cli" check "$tmp/site" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; else test "$?" = 1; fi
  for command in explain build; do
    if timeout 10 "$cli" "$command" "$tmp/site" "$tmp/out" >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; else test "$?" = 1; fi
    test -s "$tmp/stderr"
    diff -r "$tmp/out" "$tmp/valid"
  done
}
for bad in 'no content placeholder' '<a href="missing.html">bad</a>{{content}}' '<a href="#mp-missing">bad</a>{{content}}' '<img src="missing.svg">{{content}}' '<a href="{{title}}">bad</a>{{content}}' '<a href="javascript:bad">bad</a>{{content}}'; do
  printf '%s' "$bad" > "$tmp/site/layouts/post.html"
  assert_rejected
done
printf '\377{{content}}' > "$tmp/site/layouts/post.html"
assert_rejected
rm "$tmp/site/layouts/post.html"
assert_rejected
ln -s "$tmp/post.html" "$tmp/site/layouts/post.html"
assert_rejected
rm "$tmp/site/layouts/post.html"
mkfifo "$tmp/site/layouts/post.html"
assert_rejected
rm "$tmp/site/layouts/post.html"
mkdir "$tmp/site/layouts/post.html"
assert_rejected
rmdir "$tmp/site/layouts/post.html"
cp "$tmp/post.html" "$tmp/site/layouts/post.html"
mv "$tmp/site/layouts" "$tmp/layouts"
ln -s "$tmp/layouts" "$tmp/site/layouts"
assert_rejected
rm "$tmp/site/layouts"
mv "$tmp/layouts" "$tmp/site/layouts"
# Draft selection is lazy, but preview must load its missing layout.
if "$cli" build "$tmp/site" "$tmp/out" --include-drafts >"$tmp/stdout" 2>"$tmp/stderr"; then exit 1; fi
diff -r "$tmp/out" "$tmp/valid"
printf '<aside>{{title}}{{content}}</aside>' > "$tmp/site/layouts/missing.html"
"$cli" build "$tmp/site" "$tmp/preview" --include-drafts >/dev/null
grep -Fq '<aside>Draft' "$tmp/preview/draft.html"
"$cli" build "$tmp/site" "$tmp/preview" >/dev/null
diff -r "$tmp/out" "$tmp/preview"
# A Unicode filename uses the same literal filesystem/dependency identity.
cp "$tmp/site/layouts/post.html" "$tmp/site/layouts/記事.html"
sed -i 's/post.html/記事.html/' "$tmp/site/content/a.md"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.written == 1' >/dev/null
jq -e '[.artifacts[] | select(.name == "a.html") | .dependencies[].name] | index("layouts/記事.html") != null' "$tmp/out/.moonpress.json" >/dev/null
# Removing the final consumer permits removing its layout.
rm "$tmp/site/content/a.md" "$tmp/site/layouts/post.html" "$tmp/site/layouts/記事.html"
"$cli" build "$tmp/site" "$tmp/out" --json | jq -e '.report.deleted == 1' >/dev/null
test ! -e "$tmp/out/a.html"
"$cli" build "$tmp/site" "$tmp/final-clean" >/dev/null
diff -r "$tmp/out" "$tmp/final-clean"
echo 'Layout tests passed: selection, scoped dependencies, template references, filesystem/UTF-8 preflight, drafts, removal, no-op and clean parity.'
