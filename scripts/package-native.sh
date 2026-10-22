#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# != 1 ]]; then echo 'Usage: bash scripts/package-native.sh <new-output-directory>' >&2; exit 2; fi
[[ "$(uname -s)" = Linux && "$(uname -m)" = x86_64 ]] || { echo 'Only Linux x86_64 is tested.' >&2; exit 1; }
destination="$(realpath -m -- "$1")"
[[ ! -e "$destination" && ! -L "$destination" ]] || { echo 'Package destination must not exist.' >&2; exit 1; }
root="${MOON_HOME:-$HOME/.moon}"
expected="$(cat .moon-version)"
actual="$(moon version | sed -n '1p' | cut -d' ' -f2)"
[[ "$actual" = "$expected" ]] || { echo 'Use the pinned toolchain from scripts/setup.sh.' >&2; exit 1; }
moon build --target native --release
source_commit="$(git rev-parse HEAD)"
source_tree=clean
[[ -z "$(git status --porcelain)" ]] || source_tree=modified
stage="$(mktemp -d "$(dirname -- "$destination")/.moonpress-package.XXXXXXXX")"
trap 'rm -rf "$stage"' EXIT
bundle="$stage/moonpress-linux-x86_64"
mkdir -p "$bundle/licenses"
install -m 755 _build/native/release/build/cmd/main/main.exe "$bundle/moonpress"
cp LICENSE "$bundle/LICENSE"
cp docs/package-start-ja.txt "$bundle/START-HERE-ja.txt"
cp docs/package-recovery.txt "$bundle/RECOVERY.txt"
cp ui-assets/OFL-DotGothic16.txt "$bundle/licenses/OFL-DotGothic16.txt"
cp "$root/lib/core/LICENSE" "$bundle/licenses/MoonBit-LICENSE"
cp "$root/lib/core/NOTICE" "$bundle/licenses/MoonBit-NOTICE"
cp "$root/lib/core/moon.mod" "$bundle/licenses/core-package.txt"
cp .mooncakes/moonbitlang/x/moon.mod "$bundle/licenses/x-package.txt"
cp .mooncakes/moonbitlang/x/bcrypt/LICENSE.pyca-bcrypt "$bundle/licenses/x-bcrypt-LICENSE"
sed -n '1,16p' "$root/lib/runtime/runtime.c" > "$bundle/licenses/runtime-notice.txt"
cat > "$bundle/licenses/COMPONENTS.txt" <<'TEXT'
MoonPress: https://github.com/furukawa1020/MoonPress (Apache-2.0; see LICENSE)
DotGothic16: https://github.com/fontworks-fonts/DotGothic16 (SIL OFL 1.1; see OFL-DotGothic16.txt)
MoonBit core/runtime and moonbitlang/x: International Digital Economy Academy.
https://github.com/moonbitlang/core
https://github.com/moonbitlang/x
Apache-2.0, with third-party notices preserved in this folder.
Only the executable and documentation are bundled; no compiler, Node or JS backend.
TEXT
cat > "$bundle/START-HERE.txt" <<'TEXT'
MoonPress Linux x86_64 — experimental native preview build

No MoonBit installation is needed to run this executable. A compatible Linux
system with glibc is required; BUILD.txt records the tested build environment.
This is not a signed stable release, a hosting service, or a macOS/Windows build.

From this directory:
  ./moonpress init my-site
  ./moonpress admin my-site 8080

Open http://127.0.0.1:8080/rooms and keep the terminal open.
Create/save a draft, upload images from Media, then Build full preview files.
Choose Open built preview (port 8081). Mark finished articles ready, inspect
production changes, build the reviewed plan, then open Publish for next steps.
The browser language chooses Japanese or English. Use the language links to
override it or return to Auto; save edits before switching.
Port 8080 and 8081 must both be free. Ctrl-C stops both local listeners.

Use Publish > Download production ZIP to save verified public files. Extract
the ZIP and upload its contents through your host, including .nojekyll.
The ZIP excludes drafts and .moonpress.json; it does not deploy the site.
Keep .moonpress.json locally; never publish .moonpress-preview (contains drafts).
Check the actual public URL separately. Local build success is not deployment.

Article history is explicit opt-in. Review revisions before restoring. Trash
can restore an unoccupied original name; permanent purge is irreversible. Save
other edits before using the separate type/category forms. Fixed pages stay public
but leave article/tag/category/RSS lists. These actions never rebuild or deploy.
WordPress roles, comments and plugin compatibility are not implemented.

Japanese guide: START-HERE-ja.txt. Interrupted edits/builds: RECOVERY.txt.
Use ./moonpress --help for CLI commands. Back up your source files before use.
Documentation: https://github.com/furukawa1020/MoonPress
TEXT
{
  printf 'source_commit=%s\n' "$source_commit"
  printf 'source_tree=%s\n' "$source_tree"
  printf 'cli_version=%s\n' "$("$bundle/moonpress" --version)"
  printf 'tested_platform=Linux x86_64\n'
  printf 'builder_runtime=%s\n' "$(getconf GNU_LIBC_VERSION)"
  moon version
  moonc -v
} > "$bundle/BUILD.txt"
(cd "$bundle" && sha256sum moonpress > EXECUTABLE.sha256)
archive="$stage/archive"
mkdir -- "$archive"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C "$stage" -cf - moonpress-linux-x86_64 | gzip -n > "$archive/moonpress-linux-x86_64.tar.gz"
(cd "$archive" && sha256sum moonpress-linux-x86_64.tar.gz > SHA256SUMS)
# Same filesystem: publish the completed directory without replacing a racing target.
if ! mv -T --no-clobber -- "$archive" "$destination"; then
  echo 'Package publication refused.' >&2
  exit 1
fi
[[ ! -e "$archive" ]] || { echo 'Package publication refused.' >&2; exit 1; }
printf 'Native preview package: %s\n' "$destination/moonpress-linux-x86_64.tar.gz"
