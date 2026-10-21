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
macOS/Windows, cross-distribution compatibility, release signing and automated
release-asset publication remain separate release gates.

## Downloadable candidates

The `Native release candidate` workflow builds and runs the full suite on
Ubuntu 22.04, stages a draft prerelease with the archive and SHA256SUMS, then
installs that exact archive on both Ubuntu 22.04 and 24.04. Installation checks
run with an empty environment and no MoonBit in PATH. Only success on both
platforms publishes the candidate; failed candidates remain drafts. Each tag
includes source revision, run and attempt, so retries do not overwrite assets.

Run `bash scripts/release-smoke.sh DOWNLOADED_ASSET_DIRECTORY` to repeat checksum,
extraction, initialization, build, clean-build parity and recovery checks.
Checksums are not authentication signatures. Candidate availability does not
close source-write durability, physical power-cut or browser authoring gates.
Native source interfaces and JSON schema 1 remain preview contracts; keep source
backups and rebuild outputs when upgrading. Never hand-edit recovery records or
use an older binary to recover a newer schema. Unsupported schemas fail closed.
