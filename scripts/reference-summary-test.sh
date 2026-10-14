#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/public"
printf '{{content}}' > "$tmp/site/layout.html"
printf 'body{}' > "$tmp/site/style.css"
printf '<svg/>' > "$tmp/site/public/unused.svg"
printf '%s\n' '# Home' '[target](月.html)' '[target](月.html)' '[other](月.html?view=2)' '[self](#mp-home)' > "$tmp/site/content/index.md"
printf '%s\n' '---' '{"slug":"月","listed":false}' '---' '# Target' > "$tmp/site/content/target.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' '[target](月.html)' > "$tmp/site/content/draft.md"
cp -a "$tmp/site" "$tmp/before"
"$cli" reference-summary "$tmp/site" --json > "$tmp/summary"
"$cli" reference-summary "$tmp/site" --json > "$tmp/repeat"
cmp "$tmp/summary" "$tmp/repeat"
jq -e '.schema==1 and .command=="reference-summary" and (.include_drafts|not) and .report.pages==2 and .report.edges==3 and any(.report.routes[];.route.name=="月.html" and .incoming==2 and .referring_outputs==1) and any(.report.routes[];.route.name=="index.html" and .self_references==1 and .referring_outputs==0) and any(.report.routes[];.route.name=="unused.svg" and .incoming==0)' "$tmp/summary" >/dev/null
"$cli" reference-summary "$tmp/site" --include-drafts --json | jq -e '.include_drafts and .report.include_drafts and .report.pages==3 and any(.report.routes[];.route.name=="月.html" and .incoming==3 and .referring_outputs==2)' >/dev/null
"$cli" reference-summary "$tmp/site" --json --include-drafts >/dev/null
"$cli" reference-summary "$tmp/site" > "$tmp/text"
grep -Fq '"月.html"' "$tmp/text"
grep -Fq 'OTHER REFERRING OUTPUTS' "$tmp/text"
grep -Fq 'Zero counts do not prove deletion safety.' "$tmp/text"
"$cli" reference-summary --help | grep -Fq 'Usage: moonpress reference-summary'
reject() { local expected="$1" code=0; shift; "$cli" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || code=$?; test "$code" = "$expected"; test ! -s "$tmp/stdout"; test -s "$tmp/stderr"; }
reject 2 reference-summary
grep -Fq 'Usage: moonpress reference-summary' "$tmp/stderr"
reject 2 reference-summary "$tmp/site" extra
reject 2 reference-summary "$tmp/site" --json --json
reject 2 reference-summary "$tmp/site" --include-drafts --include-drafts
reject 2 reference-summary "$tmp/site" --bad
diff -r "$tmp/before" "$tmp/site"
printf '\n[broken](missing.html)\n' >> "$tmp/site/content/draft.md"
"$cli" reference-summary "$tmp/site" --json >/dev/null
reject 1 reference-summary "$tmp/site" --include-drafts --json
grep -Fq 'broken internal link' "$tmp/stderr"
test ! -e "$tmp/site/.moonpress-build"
echo 'Reference summary CLI tests passed: deduplication, self/other counts, zero routes, draft scopes, deterministic reads, strict grammar and validation failures.'
