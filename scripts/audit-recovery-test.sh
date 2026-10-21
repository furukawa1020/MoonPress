#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cli="$PWD/_build/native/release/build/cmd/main/main.exe"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$cli" init "$tmp/site" >/dev/null
"$cli" build "$tmp/site" "$tmp/out" >/dev/null
record="$tmp/.moonpress-recovery-$(printf out | sha256sum | cut -d' ' -f1).json"
cp -a "$tmp/out" "$tmp/before"
for kind in file fifo symlink directory; do
  case "$kind" in
    file) printf foreign > "$record" ;;
    fifo) mkfifo "$record" ;;
    symlink) ln -s "$tmp/missing" "$record" ;;
    directory) mkdir "$record" ;;
  esac
  status=0
  timeout 5 "$cli" audit "$tmp/out" --json > "$tmp/report" 2> "$tmp/error" || status=$?
  test "$status" -eq 1
  test ! -s "$tmp/error"
  jq -e --arg path "$record" '.report.healthy == false and any(.report.findings[]; .path == $path and .status == "recovery" and .actual == null)' "$tmp/report" >/dev/null
  diff -r "$tmp/out" "$tmp/before"
  rm -rf "$record"
done
"$cli" audit "$tmp/out" --json | jq -e '.report.healthy' >/dev/null
echo 'Audit detects retained recovery records without reading unsafe or foreign contents.'
