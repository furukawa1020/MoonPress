#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.lock
expected="$(cat .moon-version)"
[[ "$expected" == "$toolchain_moon" ]] || { echo 'Toolchain lock and .moon-version disagree; review both in a dedicated PR.' >&2; exit 1; }
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Pinned setup supports Linux x86_64 only.' >&2; exit 1; }
root="${MOON_HOME:-$HOME/.moon}"
[[ -n "$root" && ! -L "$root" ]] || { echo 'Toolchain root must be a real directory path.' >&2; exit 1; }
root="$(realpath -m "$root")"
[[ "$root" != / ]] || { echo 'Root cannot be a toolchain directory.' >&2; exit 1; }
export MOON_HOME="$root"
export PATH="$root/bin:$PATH"
verify_versions() {
  local location="$1" actual compiler
  [[ -x "$location/bin/moon" && -x "$location/bin/moonc" && -d "$location/lib/core" ]] || { echo 'Incomplete toolchain; choose a fresh MOON_HOME instead of overwriting existing files.' >&2; return 1; }
  # Consume all version output, including diagnostics after the first line.
  actual="$("$location/bin/moon" version | sed -n '1p' | cut -d' ' -f2)"
  [[ "$actual" == "$expected" ]] || { echo "Expected moon $expected, received $actual. Choose a fresh MOON_HOME; no automatic upgrades." >&2; return 1; }
  compiler="$("$location/bin/moonc" -v | sed -n '1p' | cut -d' ' -f1)"
  [[ "$compiler" == "$toolchain_compiler" ]] || { echo "Expected moonc $toolchain_compiler, received $compiler. No existing files changed." >&2; return 1; }
}
if [[ -e "$root" ]]; then
  verify_versions "$root"
else
  download="$(mktemp -d)"
  stage=''
  cleanup() { rm -rf "$download"; [[ -z "$stage" ]] || rm -rf "$stage"; }
  trap cleanup EXIT
  curl --fail --silent --show-error --location "https://cli.moonbitlang.com/binaries/$toolchain_version/moonbit-linux-x86_64.tar.gz" -o "$download/binary.tar.gz"
  curl --fail --silent --show-error --location "https://cli.moonbitlang.com/cores/core-$toolchain_version.tar.gz" -o "$download/core.tar.gz"
  # Both bytes are pinned before any extraction or executable invocation.
  printf '%s  %s\n' "$toolchain_binary_sha" "$download/binary.tar.gz" "$toolchain_core_sha" "$download/core.tar.gz" | sha256sum -c -
  parent="$(dirname "$root")"
  mkdir -p "$parent"
  stage="$(mktemp -d "$parent/.moonpress-toolchain.XXXXXX")"
  tar --no-same-owner -xf "$download/binary.tar.gz" -C "$stage"
  mkdir -p "$stage/lib"
  tar --no-same-owner -xf "$download/core.tar.gz" -C "$stage/lib"
  # Vendor archives store executables as non-executable files.
  for executable in "$stage/bin/"*; do
    if [[ -f "$executable" ]]; then chmod +x "$executable"; fi
  done
  if [[ -f "$stage/bin/internal/tcc" ]]; then chmod +x "$stage/bin/internal/tcc"; fi
  ln -sfn moon "$stage/bin/moonx"
  verify_versions "$stage"
  MOON_HOME="$stage" PATH="$stage/bin:$PATH" "$stage/bin/moon" -C "$stage/lib/core" bundle --target native --warn-list -a
  # Do not replace a directory another process/user created during preparation.
  if ! mv -T -n "$stage" "$root"; then
    if [[ -e "$root" || -L "$root" ]]; then
      echo 'Toolchain destination appeared during preparation; existing files preserved.' >&2
    else
      echo 'Cannot publish the prepared toolchain to its destination.' >&2
    fi
    exit 1
  fi
  [[ ! -e "$stage" ]] || { echo 'Toolchain destination appeared during preparation; existing files preserved.' >&2; exit 1; }
  stage=''
  verify_versions "$root"
fi
"$root/bin/moon" update
"$root/bin/moon" version --all
