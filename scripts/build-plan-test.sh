#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
printf '{{content}}' > "$tmp/site/layout.html"
printf '{{content}}' > "$tmp/site/layouts/post.html"
cp -a "$tmp/site" "$tmp/site-before"
"$cli" plan "$tmp/site" "$tmp/out" --json > "$tmp/fresh-plan"
test ! -e "$tmp/out"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/explain"
jq -S '.report.summary' "$tmp/fresh-plan" > "$tmp/summary"
jq -S '.report' "$tmp/explain" > "$tmp/expected"
cmp "$tmp/summary" "$tmp/expected"
jq -e '.schema==1 and .command=="plan" and (.include_drafts|not) and all(.report.outputs[];.action=="write" and .old_digest==null and .new_digest!=null and all(.dependencies[];.action=="added"))' "$tmp/fresh-plan" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
jq -S '.report' "$tmp/build" > "$tmp/actual"
cmp "$tmp/summary" "$tmp/actual"
cp -a "$tmp/out" "$tmp/out-before"
"$cli" plan "$tmp/site" "$tmp/out" --json > "$tmp/noop"
jq -e '.report.summary.written==0 and .report.summary.deleted==0 and all(.report.outputs[];.action=="keep" and .old_digest==.new_digest and (.dependencies|length)==0)' "$tmp/noop" >/dev/null
diff -r "$tmp/site" "$tmp/site-before"
diff -r "$tmp/out" "$tmp/out-before"
# Missing owned output repairs have no dependency deltas.
rm "$tmp/out/style.css"
cp -a "$tmp/out" "$tmp/missing-before"
"$cli" plan "$tmp/site" "$tmp/out" --json | jq -e '.report.outputs[]|select(.name=="style.css")|.action=="write" and .reason=="output missing" and .old_digest==.new_digest and (.dependencies|length)==0' >/dev/null
diff -r "$tmp/out" "$tmp/missing-before"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
# Concurrent content, layout and stylesheet changes all appear; deletions retain old edges.
rm "$tmp/site/content/guide.md"
printf '# Home\n\nNew body\n' > "$tmp/site/content/index.md"
printf '\n<footer>Footer</footer>\n' >> "$tmp/site/layout.html"
printf '\nbody {color: navy}\n' >> "$tmp/site/style.css"
printf '# Another\n' > "$tmp/site/content/another.md"
cp -a "$tmp/site" "$tmp/edited-site"
"$cli" plan "$tmp/site" "$tmp/out" --json > "$tmp/plan"
"$cli" plan "$tmp/site" "$tmp/out" --json > "$tmp/repeat"
cmp "$tmp/plan" "$tmp/repeat"
jq -e '.report.outputs[]|select(.name=="index.html")|.action=="write" and any(.dependencies[];.name=="content/index.md" and .action=="changed") and any(.dependencies[];.name=="layout.html" and .action=="changed")' "$tmp/plan" >/dev/null
jq -e '.report.outputs[]|select(.name=="guide.html")|.action=="delete" and .new_digest==null and all(.dependencies[];.action=="removed")' "$tmp/plan" >/dev/null
jq -e '.report.outputs[]|select(.name=="another.html")|.old_digest==null and .action=="write"' "$tmp/plan" >/dev/null
"$cli" plan "$tmp/site" "$tmp/out" | grep -Fq 'Detailed plan:'
diff -r "$tmp/site" "$tmp/edited-site"
diff -r "$tmp/out" "$tmp/out-before"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
jq -S '.report.summary' "$tmp/plan" > "$tmp/summary"
jq -S '.report' "$tmp/build" > "$tmp/actual"
cmp "$tmp/summary" "$tmp/actual"
"$cli" build "$tmp/site" "$tmp/clean" >/dev/null
diff -r "$tmp/out" "$tmp/clean"
"$cli" new "$tmp/site" draft 'Private draft' >/dev/null
"$cli" plan "$tmp/site" "$tmp/out" --json > "$tmp/excluded-draft-plan"
jq -e 'any(.report.summary.changes[];.action=="skip" and .path=="content/draft.md") and all(.report.outputs[];.action=="write" or .action=="keep" or .action=="delete") and all(.report.outputs[];.name!="content/draft.md" and .name!="draft.html") and (.report.outputs|length)==(.report.summary.written+.report.summary.skipped+.report.summary.deleted)' "$tmp/excluded-draft-plan" >/dev/null
"$cli" plan "$tmp/site" "$tmp/preview" --json --include-drafts > "$tmp/preview-plan"
jq -e '.include_drafts and any(.report.outputs[];.name=="draft.html") and all(.report.summary.changes[];.action!="skip") and (.report.outputs|length)==(.report.summary.written+.report.summary.skipped+.report.summary.deleted)' "$tmp/preview-plan" >/dev/null
test ! -e "$tmp/preview"
reject() { local code="$1" status=0; shift; "$@" > "$tmp/stdout" 2> "$tmp/error" || status=$?; test "$status" = "$code"; test ! -s "$tmp/stdout"; test -s "$tmp/error"; }
reject 2 "$cli" plan "$tmp/site" "$tmp/out" --json --json
reject 2 "$cli" plan "$tmp/site" "$tmp/out" --include-drafts --include-drafts
reject 2 "$cli" plan "$tmp/site" "$tmp/out" --bad
reject 2 "$cli" plan "$tmp/site"
reject 2 "$cli" plan "$tmp/site" "$tmp/out" extra
"$cli" plan --help | grep -Fq 'complete dependency changes'
for problem in edited foreign stage link; do
  cp -a "$tmp/clean" "$tmp/invalid-$problem"
  case "$problem" in
    edited) printf '\nmanual edit\n' >> "$tmp/invalid-$problem/style.css";;
    foreign) printf 'foreign\n' > "$tmp/invalid-$problem/foreign.txt";;
    stage) mkdir "$tmp/invalid-$problem/.moonpress-stage";;
    link) rm "$tmp/invalid-$problem/style.css"; ln -s "$tmp/clean/style.css" "$tmp/invalid-$problem/style.css";;
  esac
  cp -a "$tmp/invalid-$problem" "$tmp/before-$problem"
  reject 1 "$cli" plan "$tmp/site" "$tmp/invalid-$problem" --json
  diff -r "$tmp/invalid-$problem" "$tmp/before-$problem"
done
reject 1 "$cli" plan "$tmp/site" / --json
printf '%s\n' '[Broken](missing.html)' > "$tmp/site/content/bad.md"
reject 1 "$cli" plan "$tmp/site" "$tmp/never-created" --json
test ! -e "$tmp/never-created"
echo 'Build plan tests passed: explain/build parity, no-op, missing output repair, complete deltas, drafts, clean equivalence, ownership protection and no mutation.'
