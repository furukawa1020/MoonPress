#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/content" "$tmp/site/layouts" "$tmp/site/public"
printf '{{content}}' > "$tmp/site/layout.html"
printf '<img src="a.svg">{{content}}' > "$tmp/site/layouts/post.html"
printf 'body{}' > "$tmp/site/style.css"
printf '<svg/>' > "$tmp/site/public/a.svg"
printf '%s\n' '# Home' '[target](old.html)' '[second](old.html?view=2)' '[self](#mp-home)' > "$tmp/site/content/index.md"
printf '%s\n' '---' '{"slug":"old","layout":"post.html","listed":false}' '---' '# Target' > "$tmp/site/content/target.md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' '![asset](a.svg)' > "$tmp/site/content/draft.md"
inspect() {
  local scope="$1"
  local flags=()
  if [[ "$scope" = all ]]; then flags+=(--include-drafts); fi
  cp -a "$tmp/site" "$tmp/snapshot-source"
  cp -a "$tmp/out" "$tmp/snapshot-output"
  "$cli" references "$tmp/site" "${flags[@]}" --json > "$tmp/graph"
  "$cli" reference-summary "$tmp/site" "${flags[@]}" --json > "$tmp/summary"
  "$cli" reference-summary "$tmp/site" "${flags[@]}" --json > "$tmp/repeat"
  cmp "$tmp/summary" "$tmp/repeat"
  # Derive each count independently from graph evidence. Check route order and
  # coverage, not merely totals that could conceal a swapped target.
  jq -es '
    .[0].report as $g | .[1].report as $s |
    $s.pages==$g.pages and $s.include_drafts==$g.include_drafts and
    $s.edges==($g.references|length) and
    ([$s.routes[].route])==$g.routes and
    all($s.routes[];
      . as $row |
      $row.incoming==([$g.references[]|select(.target==$row.route.name)]|length) and
      $row.outgoing==([$g.references[]|select(.output==$row.route.name)]|length) and
      $row.self_references==([$g.references[]|select(.output==$row.route.name and .target==$row.route.name)]|length) and
      $row.referring_outputs==([$g.references[]|select(.target==$row.route.name and .output!=$row.route.name)|.output]|unique|length)
    ) and ([$s.routes[].incoming]|add)==$s.edges and ([$s.routes[].outgoing]|add)==$s.edges
  ' "$tmp/graph" "$tmp/summary" >/dev/null
  "$cli" backlinks "$tmp/site" a.svg "${flags[@]}" --json > "$tmp/query"
  jq -es '.[0].report as $s | .[1].report as $q |
    any($s.routes[];.route.name=="a.svg" and .incoming==($q.incoming|length) and .outgoing==($q.outgoing|length))' "$tmp/summary" "$tmp/query" >/dev/null
  diff -r "$tmp/snapshot-source" "$tmp/site"
  diff -r "$tmp/snapshot-output" "$tmp/out"
  rm -rf "$tmp/snapshot-source" "$tmp/snapshot-output"
}
build_parity() {
  "$cli" build "$tmp/site" "$tmp/out" >/dev/null
  "$cli" build "$tmp/site" "$tmp/clean" >/dev/null
  diff -r "$tmp/out" "$tmp/clean"
  rm -rf "$tmp/clean"
}
build_parity
inspect ready
jq -e 'any(.report.routes[];.route.name=="old.html" and .incoming==2 and .referring_outputs==1) and any(.report.routes[];.route.name=="a.svg" and .incoming==1)' "$tmp/summary" >/dev/null
inspect all
jq -e 'any(.report.routes[];.route.name=="a.svg" and .incoming==2 and .referring_outputs==2)' "$tmp/summary" >/dev/null
# URL changes fail explicitly until an old-route redirect is supplied.
sed -i 's/"old"/"new"/' "$tmp/site/content/target.md"
cp -a "$tmp/out" "$tmp/prior"
code=0
"$cli" reference-summary "$tmp/site" --json > "$tmp/stdout" 2> "$tmp/stderr" || code=$?
test "$code" = 1
test ! -s "$tmp/stdout"
grep -Fq 'broken internal link' "$tmp/stderr"
diff -r "$tmp/prior" "$tmp/out"
printf '%s\n' '{"redirects":{"old.html":"new.html"}}' > "$tmp/site/site.json"
build_parity
inspect ready
jq -e 'any(.report.routes[];.route.name=="old.html" and .route.kind=="redirect" and .incoming==2 and .outgoing==1) and any(.report.routes[];.route.name=="new.html" and .incoming==1 and .referring_outputs==1)' "$tmp/summary" >/dev/null
# Switching away from a selected layout removes its asset evidence.
sed -i 's/,"layout":"post.html"//' "$tmp/site/content/target.md"
build_parity
inspect ready
jq -e 'any(.report.routes[];.route.name=="a.svg" and .incoming==0)' "$tmp/summary" >/dev/null
# Ready unlisted articles still contribute. Repeated Markdown evidence counts once.
sed -i 's/"draft":true/"draft":false,"listed":false/' "$tmp/site/content/draft.md"
printf '\n![asset](a.svg)\n' >> "$tmp/site/content/draft.md"
build_parity
inspect ready
jq -e 'any(.report.routes[];.route.name=="a.svg" and .incoming==1 and .referring_outputs==1)' "$tmp/summary" >/dev/null
# Asset content changes affect build bytes, not reference counts.
cp "$tmp/summary" "$tmp/pre-asset"
printf '<svg><title>Changed</title></svg>' > "$tmp/site/public/a.svg"
build_parity
inspect ready
cmp "$tmp/pre-asset" "$tmp/summary"
# Removing authored evidence retains an explicit zero row for the existing asset.
sed -i '/!\[asset\]/d' "$tmp/site/content/draft.md"
build_parity
inspect ready
jq -e 'any(.report.routes[];.route.name=="a.svg" and .incoming==0 and .referring_outputs==0)' "$tmp/summary" >/dev/null
echo 'Reference summary transition tests passed: independent count derivation, query parity, drafts/listing, slug/redirect repair, layout/asset changes, deterministic no-write inspection and clean build parity.'
