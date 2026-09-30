#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/project/scripts"
cp scripts/setup.sh "$tmp/project/scripts/setup.sh"
cp .moon-version "$tmp/project/.moon-version"
export SETUP_TEST_ROOT="$tmp"
export SETUP_TEST_VERSION="$(cat .moon-version)"
export SETUP_TEST_COMPILER='v0.10.14+7d59c7ec9 (test)'
# Exported shell functions override the actual tools without changing HOME,
# installing software or contacting the network. Large trailing output makes
# premature pipe closure deterministic instead of relying on process scheduling.
moon() {
  if [[ "$1" == update ]]; then
    printf 'updated\n' > "$SETUP_TEST_ROOT/update"
    return 0
  fi
  [[ "$1" == version ]] || return 2
  trap '' PIPE
  printf 'moon %s (test)\n' "$SETUP_TEST_VERSION" || return 101
  local padding i
  printf -v padding '%4096s' ''
  for ((i=0; i<128; i++)); do
    printf '%s\n' "$padding" || return 101
  done
}
moonc() { printf '%s\n' "$SETUP_TEST_COMPILER"; }
curl() {
  printf 'installer requested\n' > "$SETUP_TEST_ROOT/install"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${@: -1}"
}
export -f moon moonc curl
# Reproduce the exact old early-closing pipeline in a copy of the script.
sed "s/sed -n '1p'/head -1/g" scripts/setup.sh > "$tmp/project/scripts/legacy.sh"
if bash "$tmp/project/scripts/legacy.sh" > "$tmp/legacy-out" 2> "$tmp/legacy-error"; then
  echo 'Expected legacy setup to fail on early pipe closure' >&2
  exit 1
fi
test ! -e "$tmp/update"
bash "$tmp/project/scripts/setup.sh" > "$tmp/output" 2> "$tmp/error"
test -s "$tmp/update"
test ! -e "$tmp/install"
test ! -s "$tmp/error"
rm "$tmp/update"
# A different moon still takes the installer path and fails exact validation.
export SETUP_TEST_VERSION='0.0.0-test'
if bash "$tmp/project/scripts/setup.sh" > "$tmp/output" 2> "$tmp/error"; then exit 1; fi
grep -Fq 'Expected moon' "$tmp/error"
test -s "$tmp/install"
test ! -e "$tmp/update"
rm "$tmp/install"
# Compiler mismatch also fails before updating package indexes.
export SETUP_TEST_VERSION="$(cat .moon-version)"
export SETUP_TEST_COMPILER='v0.0.0-test'
if bash "$tmp/project/scripts/setup.sh" > "$tmp/output" 2> "$tmp/error"; then exit 1; fi
test ! -e "$tmp/update"
test ! -e "$tmp/install"
echo 'Setup tests passed: legacy broken-pipe reproduction, full output consumption and strict moon/moonc mismatch rejection.'
