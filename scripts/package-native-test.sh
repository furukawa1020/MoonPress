#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bash scripts/package-native.sh "$tmp/package" > "$tmp/log"
(cd "$tmp/package" && sha256sum -c SHA256SUMS)
mkdir "$tmp/unpacked"
tar -xzf "$tmp/package/moonpress-linux-x86_64.tar.gz" -C "$tmp/unpacked"
bundle="$tmp/unpacked/moonpress-linux-x86_64"
(cd "$bundle" && sha256sum -c EXECUTABLE.sha256)
test -s "$bundle/licenses/MoonBit-NOTICE"
grep -Fq "source_commit=$(git rev-parse HEAD)" "$bundle/BUILD.txt"
env -i PATH=/usr/bin:/bin HOME="$tmp" "$bundle/moonpress" --help > "$tmp/help"
env -i PATH=/usr/bin:/bin HOME="$tmp" "$bundle/moonpress" init "$tmp/site" >/dev/null
env -i PATH=/usr/bin:/bin HOME="$tmp" "$bundle/moonpress" check "$tmp/site" >/dev/null
env -i PATH=/usr/bin:/bin HOME="$tmp" "$bundle/moonpress" build "$tmp/site" "$tmp/output" >/dev/null
test -s "$tmp/output/index.html"
cp "$tmp/package/SHA256SUMS" "$tmp/before"
if bash scripts/package-native.sh "$tmp/package" >/dev/null 2>&1; then exit 1; fi
cmp "$tmp/before" "$tmp/package/SHA256SUMS"
# Fail each archive phase after staging starts, then verify a normal retry.
mkdir "$tmp/bin"
for command in tar gzip sha256sum; do
  real_command="$(command -v "$command")"
  cat > "$tmp/bin/$command" <<'SH'
#!/usr/bin/env bash
if [[ "$(basename "$0")" != sha256sum || "${1:-}" = moonpress-linux-x86_64.tar.gz ]]; then
  echo 'Injected archive failure' >&2
  exit 71
fi
exec "$PACKAGE_REAL_COMMAND" "$@"
SH
  chmod +x "$tmp/bin/$command"
  if PACKAGE_REAL_COMMAND="$real_command" PATH="$tmp/bin:$PATH" bash scripts/package-native.sh "$tmp/failed-$command" >"$tmp/failure-log" 2>&1; then exit 1; fi
  grep -Fq 'Injected archive failure' "$tmp/failure-log"
  test ! -e "$tmp/failed-$command"
  test -z "$(find "$tmp" -maxdepth 1 -name '.moonpress-package.*' -print -quit)"
  mv "$tmp/bin/$command" "$tmp/used-$command"
  bash scripts/package-native.sh "$tmp/failed-$command" >/dev/null
  (cd "$tmp/failed-$command" && sha256sum -c SHA256SUMS)
done
# A target appearing immediately before publication must remain untouched.
real_mv="$(command -v mv)"
cat > "$tmp/bin/mv" <<'SH'
#!/usr/bin/env bash
mkdir -- "$PACKAGE_RACE_DESTINATION"
printf 'foreign\n' > "$PACKAGE_RACE_DESTINATION/keep"
exec "$PACKAGE_REAL_COMMAND" "$@"
SH
chmod +x "$tmp/bin/mv"
if PACKAGE_RACE_DESTINATION="$tmp/racing" PACKAGE_REAL_COMMAND="$real_mv" PATH="$tmp/bin:$PATH" bash scripts/package-native.sh "$tmp/racing" >"$tmp/race-log" 2>&1; then exit 1; fi
grep -Fq 'Package publication refused.' "$tmp/race-log" || { cat "$tmp/race-log"; exit 1; }
test "$(cat "$tmp/racing/keep")" = foreign
test "$(find "$tmp/racing" -mindepth 1 | wc -l)" = 1
test -z "$(find "$tmp" -maxdepth 1 -name '.moonpress-package.*' -print -quit)"
echo 'Native package tests passed: checksums/provenance/notices, unpacked CLI without MoonBit, init/check/build, occupied destination protection, archive failure cleanup and retry.'
