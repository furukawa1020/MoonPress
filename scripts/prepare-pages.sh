#!/usr/bin/env bash
# Prepare only validated, owned public artifacts. Never ship local build state.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cli="$root/_build/native/release/build/cmd/main/main.exe"
source_dir="$(realpath "${1:?source output required}")"
destination="${2:?new destination required}"
test ! -e "$destination"
"$cli" audit "$source_dir" --json >/dev/null
manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
cp -- "$source_dir/.moonpress.json" "$manifest"
# Validate names independently before shell path construction.
jq -e '(.artifacts | type == "array") and all(.artifacts[]; (.name | type == "string") and (.name | length > 0) and (.name | explode | all(. > 31 and . != 127 and . != 47 and . != 92)) and (.name != "." and .name != "..") and (.digest | test("^[0-9a-f]{64}$")))' "$manifest" >/dev/null
mkdir "$destination"
complete=false
trap 'rm -f "$manifest"; if [[ "$complete" != true ]]; then rm -rf -- "$destination"; fi' EXIT
while IFS=$'\t' read -r name digest; do
  test -f "$source_dir/$name" && test ! -L "$source_dir/$name"
  cp -- "$source_dir/$name" "$destination/$name"
  actual="$(sha256sum -- "$destination/$name")"
  test "${actual%% *}" = "$digest"
done < <(jq -r '.artifacts[] | [.name,.digest] | @tsv' "$manifest")
test -s "$destination/index.html"
test -f "$destination/.nojekyll"
test ! -e "$destination/.moonpress.json"
cmp -s -- "$manifest" "$source_dir/.moonpress.json"
"$cli" audit "$source_dir" --json >/dev/null
complete=true
