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
printf '# Quoted\n' > "$tmp/site/content/月\".md"
printf '%s\n' '---' '{"draft":true}' '---' '# Draft' > "$tmp/site/content/draft.md"
cp -a "$tmp/site" "$tmp/source"
"$cli" check "$tmp/site" --json > "$tmp/check"
jq -e -s 'length == 1 and .[0] == {
  schema:1, command:"check", include_drafts:false, report:{pages:2, outputs:5}
}' "$tmp/check" >/dev/null
diff -r "$tmp/site" "$tmp/source"
test "$(find "$tmp/site" -type f | wc -l)" -eq 5
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/explain"
test ! -e "$tmp/out"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
jq -e -s 'length == 1 and (.[0] |
  .schema == 1 and .command == "build" and .include_drafts == false and
  .report.pages == 2 and .report.written == 5 and .report.skipped == 0 and
  .report.deleted == 0 and (.report.changes | length) == 6 and
  any(.report.changes[]; .action == "write" and .path == "月\".html") and
  any(.report.changes[]; .action == "skip" and .path == "content/draft.md" and .reason == "draft")
)' "$tmp/build" >/dev/null
diff <(jq -S '.report' "$tmp/build") <(jq -S '.report' "$tmp/explain")
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/noop"
jq -e '.report.written == 0 and .report.skipped == 5 and
  ([.report.changes[] | select(.action == "keep")] | length) == 5' "$tmp/noop" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/noop2"
cmp "$tmp/noop" "$tmp/noop2"
cp -a "$tmp/out" "$tmp/snapshot"
printf '# Changed\n' >> "$tmp/site/content/index.md"
rm "$tmp/site/content/月\".md"
"$cli" explain "$tmp/site" "$tmp/out" --json > "$tmp/explain"
jq -e '.command == "explain" and .report.deleted == 1 and
  any(.report.changes[]; .action == "delete" and .path == "月\".html") and
  any(.report.changes[]; .action == "write" and .path == "index.html" and
    (.reason | contains("content/index.md")))' "$tmp/explain" >/dev/null
diff -r "$tmp/out" "$tmp/snapshot"
"$cli" build "$tmp/site" "$tmp/out" --json > "$tmp/build"
diff <(jq -S '.report' "$tmp/build") <(jq -S '.report' "$tmp/explain")
"$cli" build "$tmp/site" "$tmp/clean" --json >/dev/null
diff -r "$tmp/out" "$tmp/clean"
for command in check build explain; do
  operands=("$tmp/site")
  if [[ "$command" != check ]]; then operands+=("$tmp/preview"); fi
  "$cli" "$command" "${operands[@]}" --include-drafts --json > "$tmp/first"
  # Only compare bytes for read-only commands; the first build changes state.
  "$cli" "$command" "${operands[@]}" --json --include-drafts > "$tmp/second"
  jq -e --arg command "$command" '.command == $command and .include_drafts and .report.pages == 2' "$tmp/first" >/dev/null
  jq -e --arg command "$command" '.command == $command and .include_drafts and .report.pages == 2' "$tmp/second" >/dev/null
  if [[ "$command" != build ]]; then cmp "$tmp/first" "$tmp/second"; fi
done
test -f "$tmp/preview/draft.html"
failure() {
  local expected="$1" status=0
  shift
  "$cli" "$@" > "$tmp/stdout" 2>"$tmp/stderr" || status=$?
  test "$status" -eq "$expected"
  test ! -s "$tmp/stdout"
  test -s "$tmp/stderr"
}
for command in check build explain; do
  operands=("$tmp/site")
  if [[ "$command" != check ]]; then operands+=("$tmp/out"); fi
  failure 2 "$command" "${operands[@]}" --json --json
  failure 2 "$command" "${operands[@]}" --json --include-drafts --include-drafts
  failure 2 "$command" "${operands[@]}" --unknown --json
done
failure 2 check --json
failure 2 build "$tmp/site" --json
failure 2 --json check "$tmp/site"
printf '\n[Missing](ghost.html)\n' >> "$tmp/site/content/index.md"
cp -a "$tmp/out" "$tmp/before-error"
failure 1 check "$tmp/site" --json
failure 1 explain "$tmp/site" "$tmp/out" --json
failure 1 build "$tmp/site" "$tmp/out" --json
diff -r "$tmp/out" "$tmp/before-error"
echo 'JSON report tests passed: schema, escaping, events, no-op, dry-run, clean parity, draft flags and error channels.'
