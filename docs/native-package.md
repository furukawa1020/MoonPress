# Native preview package

After the pinned toolchain is installed, run:

```sh
bash scripts/package-native.sh /path/to/new-package-directory
```

The directory must not already exist. It receives a Linux x86_64 tar.gz and
SHA256SUMS. Archive and checksum are staged on the destination filesystem before
publishing the completed directory. Failed archive creation leaves the destination
absent so it can be retried; an occupied destination is preserved. Verify the checksum before extracting. The bundle contains the native
executable, startup guide, license/notices, executable checksum and BUILD.txt
(source commit, clean/modified source status, toolchain and builder glibc).

The unpacked executable runs without MoonBit or Node. Linux with compatible glibc
is required; BUILD.txt describes the builder, not a verified minimum glibc version.
The package test initializes, checks and builds a site in a clean environment.

This is an experimental preview distribution, not a signed stable release.
A checksum detects byte changes but does not authenticate an untrusted download.
macOS/Windows, cross-distribution compatibility and release signing remain
separate release gates. Candidate asset publication is automated below.

## Downloadable candidates

The `Native release candidate` workflow builds and runs the full suite on
Ubuntu 22.04, stages a draft prerelease with the archive and SHA256SUMS, then
installs that exact archive on both Ubuntu 22.04 and 24.04. Installation checks
run with an empty environment and no MoonBit in PATH. Only success on both
platforms, including real Chrome authoring against the unpacked executable,
publishes the candidate; failed candidates remain drafts. Each tag
includes source revision, run and attempt, so retries do not overwrite assets.

Run `bash scripts/release-smoke.sh DOWNLOADED_ASSET_DIRECTORY` to repeat checksum,
extraction, initialization, build, clean-build parity and recovery checks.
Checksums are not authentication signatures. Candidate availability does not
prove physical power-cut resilience or broad cross-browser compatibility.
Native source interfaces and JSON schema 1 remain preview contracts; keep source
backups and rebuild outputs when upgrading. Never hand-edit recovery records or
use an older binary to recover a newer schema. Unsupported schemas fail closed.

Set `MOONPRESS_VERIFY_BROWSER=1` when running release-smoke.sh to repeat the
real-browser journey against that extracted binary. Chrome and matching
ChromeDriver must be installed. The release workflow enables this on both
platforms; no MoonBit toolchain is installed in those installation jobs.

The archive includes `START-HERE-ja.txt` and `RECOVERY.txt` for offline room and
recovery guidance. Candidates are rebuilt for source, script and documentation
changes on main (site-only and benchmark-only changes are excluded).
The installation gate sets `MOONPRESS_EXPECT_REVISION` to the full workflow SHA:
before executing the candidate, BUILD.txt must contain exactly that revision and
one `source_tree=clean` entry. This checks consistency with the selected build;
it does not authenticate a maliciously replaced archive or provide signing.
