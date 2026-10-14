#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/project/scripts" "$tmp/binary/bin" "$tmp/core/core"
cp scripts/setup.sh scripts/toolchain.lock "$tmp/project/scripts/"
cp .moon-version "$tmp/project/"
export SETUP_TEST_ROOT="$tmp"
export SETUP_TEST_VERSION="$(cat .moon-version)"
export SETUP_TEST_COMPILER='v0.10.14+7d59c7ec9'
cat > "$tmp/binary/bin/moon" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == update ]]; then printf 'updated\n' > "$SETUP_TEST_ROOT/update"; exit 0; fi
if [[ "$1" == -C ]]; then
  [[ "$3" == bundle && "$4" == --target && "$5" == native ]]
  if [[ -n "${SETUP_TEST_APPEAR_ROOT:-}" ]]; then
    mkdir -p "$SETUP_TEST_APPEAR_ROOT"
    printf 'keep\n' > "$SETUP_TEST_APPEAR_ROOT/sentinel"
  fi
  printf 'native\n' > "$MOON_HOME/bundle-proof"
  exit 0
fi
[[ "$1" == version ]] || exit 2
trap '' PIPE
printf 'moon %s (test)\n' "$SETUP_TEST_VERSION" || exit 101
printf -v padding '%4096s' ''
for ((i=0;i<128;i++)); do printf '%s\n' "$padding" || exit 101; done
MOCK
cat > "$tmp/binary/bin/moonc" <<'MOCK'
#!/usr/bin/env bash
printf '%s (test)\n' "$SETUP_TEST_COMPILER"
MOCK
chmod 644 "$tmp/binary/bin/moon" "$tmp/binary/bin/moonc"
printf 'fixture core\n' > "$tmp/core/core/README"
tar -cf "$tmp/binary.tar.gz" -C "$tmp/binary" .
tar -cf "$tmp/core.tar.gz" -C "$tmp/core" .
binary_sha="$(sha256sum "$tmp/binary.tar.gz" | cut -d' ' -f1)"
core_sha="$(sha256sum "$tmp/core.tar.gz" | cut -d' ' -f1)"
sed -i "s/^toolchain_binary_sha=.*/toolchain_binary_sha='$binary_sha'/;s/^toolchain_core_sha=.*/toolchain_core_sha='$core_sha'/" "$tmp/project/scripts/toolchain.lock"
export SETUP_TEST_TAMPER=''
curl() {
  local url="${@: -3:1}" destination="${@: -1}" file
  printf '%s\n' "$url" >> "$SETUP_TEST_ROOT/downloads"
  if [[ "$url" == *'/binaries/0.10.14%2B7d59c7ec9/moonbit-linux-x86_64.tar.gz' ]]; then file=binary
  elif [[ "$url" == *'/cores/core-0.10.14%2B7d59c7ec9.tar.gz' ]]; then file=core
  else echo 'Unexpected setup URL' >&2; return 1; fi
  cp "$SETUP_TEST_ROOT/$file.tar.gz" "$destination"
  if [[ "$SETUP_TEST_TAMPER" == "$file" ]]; then printf 'tamper' >> "$destination"; fi
}
export -f curl
export MOON_HOME="$tmp/toolchain"
bash "$tmp/project/scripts/setup.sh" > "$tmp/stdout" 2> "$tmp/error"
test -s "$tmp/update"; test ! -s "$tmp/error"
test "$(cat "$MOON_HOME/bundle-proof")" = native
[[ "$(wc -l < "$tmp/downloads")" == 2 ]]
rm "$tmp/update" "$tmp/downloads"
bash "$tmp/project/scripts/setup.sh" > "$tmp/stdout" 2> "$tmp/error"
test -s "$tmp/update"; test ! -e "$tmp/downloads"
rm "$tmp/update"
# Reproduce the old broken-pipe behavior with an installed fixture.
sed "s/sed -n '1p'/head -1/g" "$tmp/project/scripts/setup.sh" > "$tmp/project/scripts/legacy.sh"
if bash "$tmp/project/scripts/legacy.sh" > "$tmp/stdout" 2> "$tmp/error"; then exit 1; fi
test ! -e "$tmp/update"
for mismatch in moon moonc; do
  if [[ "$mismatch" == moon ]]; then export SETUP_TEST_VERSION='0.0.0-test'; else export SETUP_TEST_COMPILER='v0.0.0-test'; fi
  if bash "$tmp/project/scripts/setup.sh" > "$tmp/stdout" 2> "$tmp/error"; then exit 1; fi
  grep -Fq "Expected $mismatch" "$tmp/error"
  test ! -e "$tmp/update"; test ! -e "$tmp/downloads"
  export SETUP_TEST_VERSION="$(cat .moon-version)" SETUP_TEST_COMPILER='v0.10.14+7d59c7ec9'
done
# Either archive mismatch must fail before target creation or executable invocation.
for component in binary core; do
  export MOON_HOME="$tmp/fresh-$component" SETUP_TEST_TAMPER="$component"
  if bash "$tmp/project/scripts/setup.sh" > "$tmp/stdout" 2> "$tmp/error"; then exit 1; fi
  grep -Fq 'FAILED' "$tmp/stdout"
  test ! -e "$MOON_HOME"; test ! -e "$tmp/update"
done
export SETUP_TEST_TAMPER='' MOON_HOME="$tmp/appeared" SETUP_TEST_APPEAR_ROOT="$tmp/appeared"
if bash "$tmp/project/scripts/setup.sh" > "$tmp/stdout" 2> "$tmp/error"; then exit 1; fi
grep -Fq 'destination appeared' "$tmp/error"
test "$(cat "$MOON_HOME/sentinel")" = keep
unset SETUP_TEST_APPEAR_ROOT
export MOON_HOME="$tmp/foreign"
mkdir "$MOON_HOME"
printf 'keep\n' > "$MOON_HOME/sentinel"
if bash "$tmp/project/scripts/setup.sh" > "$tmp/stdout" 2> "$tmp/error"; then exit 1; fi
test "$(cat "$MOON_HOME/sentinel")" = keep
export MOON_HOME="$tmp/link"
ln -s "$tmp/toolchain" "$MOON_HOME"
if bash "$tmp/project/scripts/setup.sh" > "$tmp/stdout" 2> "$tmp/error"; then exit 1; fi
grep -Fq 'real directory' "$tmp/error"
echo 'Setup tests passed: fixed archive URLs/hashes, both tamper cases before extraction, native-only bundling, no downloads on reuse, exact versions, broken-pipe regression and existing-path preservation.'
