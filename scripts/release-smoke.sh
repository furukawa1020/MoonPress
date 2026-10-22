#!/usr/bin/env bash
# Exercise a downloaded archive without any MoonBit installation.
set -euo pipefail
package="$(realpath "${1:?package directory required}")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
(cd "$package" && sha256sum --check SHA256SUMS)
tar -xzf "$package/moonpress-linux-x86_64.tar.gz" -C "$work"
bundle="$work/moonpress-linux-x86_64"
(cd "$bundle" && sha256sum --check EXECUTABLE.sha256)
cli="$bundle/moonpress"
env -i PATH=/usr/bin:/bin "$cli" --version
env -i PATH=/usr/bin:/bin "$cli" init "$work/site"
env -i PATH=/usr/bin:/bin "$cli" check "$work/site"
env -i PATH=/usr/bin:/bin "$cli" build "$work/site" "$work/dist"
env -i PATH=/usr/bin:/bin "$cli" build "$work/site" "$work/clean"
diff -r "$work/dist" "$work/clean"
printf '\nPackage update\n' >> "$work/site/content/index.md"
env -i PATH=/usr/bin:/bin "$cli" build "$work/site" "$work/dist"
env -i PATH=/usr/bin:/bin "$cli" recover "$work/dist"
printf 'Archive install/build/recovery smoke passed: %s / %s\n' "$(uname -m)" "$(getconf GNU_LIBC_VERSION)"

if [[ "${MOONPRESS_VERIFY_BROWSER:-0}" = 1 ]]; then
  MOONPRESS_BROWSER_CLI="$cli" python3 "$(dirname "$0")/browser-test.py"
fi
