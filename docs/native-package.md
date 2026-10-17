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
