#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
printf '{{content}}' > "$tmp/site/layout.html"
printf '{{content}}' > "$tmp/site/layouts/post.html"
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
cp "$tmp/out/.moonpress.json" "$tmp/old.json"
cp -a "$tmp/out" "$tmp/out-before"
# Remove a real page, add another and change content in an existing page.
rm "$tmp/site/content/guide.md"
printf '# New\n' > "$tmp/site/content/new.md"
printf '# Home\n\nChanged body\n' > "$tmp/site/content/index.md"
"$cli" build "$tmp/site" "$tmp/next" >/dev/null
cp "$tmp/next/.moonpress.json" "$tmp/new.json"
cp -a "$tmp/site" "$tmp/site-before"
"$cli" diff "$tmp/old.json" "$tmp/new.json" --json > "$tmp/report"
"$cli" diff "$tmp/old.json" "$tmp/new.json" --json > "$tmp/repeat"
cmp "$tmp/report" "$tmp/repeat"
jq -e '.schema==1 and .command=="diff" and (.include_drafts|not) and .report.added>=1 and .report.removed>=1 and .report.changed>=1 and .report.unchanged>=1' "$tmp/report" >/dev/null
jq -e '.report.outputs[]|select(.name=="index.html")|.action=="changed" and .content_changed and any(.dependencies[];.name=="content/index.md" and .action=="changed")' "$tmp/report" >/dev/null
jq -e '.report.outputs[]|select(.name=="guide.html")|.action=="removed" and .new_digest==null and all(.dependencies[];.action=="removed")' "$tmp/report" >/dev/null
"$cli" diff "$tmp/old.json" "$tmp/new.json" | grep -Fq 'Manifest difference:'
# Dependency-only changes and ordering-only changes have distinct semantics.
jq '.artifacts|=reverse|.artifacts[].dependencies|=reverse' "$tmp/old.json" > "$tmp/reordered"
"$cli" diff "$tmp/old.json" "$tmp/reordered" --json | jq -e '.report.changed==0 and .report.added==0 and .report.removed==0' >/dev/null
jq '(.artifacts[]|select(.name=="index.html")|.dependencies[0].digest)="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "$tmp/old.json" > "$tmp/dependency"
"$cli" diff "$tmp/old.json" "$tmp/dependency" --json | jq -e '.report.outputs[]|select(.name=="index.html")|.action=="changed" and (.content_changed|not) and (.dependencies|length)==1' >/dev/null
reject() { local code="$1" status=0; shift; timeout 5 "$@" > "$tmp/stdout" 2> "$tmp/error" || status=$?; test "$status" = "$code"; test ! -s "$tmp/stdout"; test -s "$tmp/error"; }
reject 2 "$cli" diff "$tmp/old.json"
reject 2 "$cli" diff "$tmp/old.json" "$tmp/new.json" --json --json
reject 2 "$cli" diff "$tmp/old.json" "$tmp/new.json" --include-drafts
reject 2 "$cli" diff "$tmp/old.json" "$tmp/new.json" --bad
reject 2 "$cli" diff "$tmp/old.json" "$tmp/new.json" extra
printf '{}\n' > "$tmp/bad"
reject 1 "$cli" diff "$tmp/bad" "$tmp/new.json" --json
reject 1 "$cli" diff "$tmp/old.json" "$tmp/bad" --json
reject 1 "$cli" diff "$tmp/missing" "$tmp/new.json" --json
ln -s "$tmp/old.json" "$tmp/link"
reject 1 "$cli" diff "$tmp/link" "$tmp/new.json" --json
mkfifo "$tmp/fifo"
reject 1 "$cli" diff "$tmp/old.json" "$tmp/fifo" --json
printf '\377' > "$tmp/invalid-utf8"
reject 1 "$cli" diff "$tmp/invalid-utf8" "$tmp/new.json" --json
"$cli" diff --help | grep -Fq 'No --include-drafts option'
diff -r "$tmp/site" "$tmp/site-before"
diff -r "$tmp/out" "$tmp/out-before"
cmp "$tmp/old.json" "$tmp/out/.moonpress.json"
cmp "$tmp/new.json" "$tmp/next/.moonpress.json"
echo 'Manifest diff tests passed: real snapshots, dependency-only and ordering differences, JSON, strict grammar, special-file refusal and no mutation.'
