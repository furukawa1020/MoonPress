# Pinned native toolchain

Setup supports Linux x86_64. `scripts/toolchain.lock` records exact official
binary/core archive URLs (via the compiler version) and repository-pinned SHA-256
hashes. `.moon-version` must agree with the lock. Both archives are downloaded
and verified before extraction or execution; a changed remote archive fails
closed. No mutable upstream installer is downloaded or executed. The repository
setup script itself is versioned with the source. Core bundling uses only
`--target native`; unused backends inside the vendor distribution are not used
by the application or CI steps.

Default install root is `$HOME/.moon`; set `MOON_HOME` for an isolated root:

```sh
export MOON_HOME="$HOME/.moonpress-toolchain"
bash scripts/setup.sh
export PATH="$MOON_HOME/bin:$PATH"
bash scripts/check.sh
```

Use a fresh root when another MoonBit version is already installed. Existing
roots are checked for versions/core presence and reused, never automatically
overwritten/upgraded. Download pins do not reauthenticate files in an already
installed root. An incomplete root, symlink root, root directory `/`, version
mismatch or checksum mismatch fails explicitly. Fresh installation is prepared/bundled in a sibling
staging directory and then moved into the absent destination. If the destination
appears during preparation, it is preserved and setup fails. Caught failures
clean task-owned download/staging directories; this is not an installer
power-loss/restart-recovery guarantee. HOME is never reassigned.

Pinned compiler: v0.10.14+7d59c7ec9; moon: 0.1.20260920. Official sources:

- https://cli.moonbitlang.com/binaries/0.10.14%2B7d59c7ec9/moonbit-linux-x86_64.tar.gz
- https://cli.moonbitlang.com/cores/core-0.10.14%2B7d59c7ec9.tar.gz
- https://www.moonbitlang.com/download

Setup tests use tiny controlled archives to check tampering of either component
before extraction, exact-version checks, native-only bundling, output consumption
and preservation of existing paths. Fresh CI uses the real pinned archives and
runs the full native/CLI suite. Updating versions/hashes requires a dedicated
PR, official-source review and a clean-install CI run. Hash pins freeze the
reviewed downloads; they do not establish bit-for-bit reproducibility across C
compilers/operating systems, dependency availability or archive authenticity
beyond the reviewed official TLS source. Package dependency updates are separate.
