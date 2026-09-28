# Contributing to MoonPress

MoonPress is an experimental native MoonBit static-site compiler. Small,
reproducible improvements to correctness, diagnostics, documentation and measured
performance are welcome. See [the release roadmap](docs/roadmap.md) for current
gates and [AGENTS.md](AGENTS.md) for the development contract.

## Build and verify

The tested environment is Linux x86_64; CI uses Ubuntu 24.04. Install Bash,
Git, curl, a C compiler, jq and standard GNU command-line tools (including
coreutils/timeout, diffutils, findutils, grep and sed). No Node/npm is needed.

From your checkout:

```sh
bash scripts/setup.sh
export PATH="$HOME/.moon/bin:$PATH"
moon info --target native
moon fmt
bash scripts/check.sh
_build/native/release/build/cmd/main/main.exe check site --json
```

Setup checks the exact Moon/Moonc versions. It currently downloads from an
upstream latest URL: a mismatch is a deliberate failure, not permission to
silently update the pin. Record the error on [#11](https://github.com/furukawa1020/MoonPress/issues/11).
Version changes need a dedicated PR with native CI evidence.

The full check script runs native type checks, unit tests, release compilation
and shell integration suites. Use a fresh output directory when trying the CLI.
Never edit or place reports inside a managed output directory.

## Issues and pull requests

Search existing issues before filing a bug or proposing a feature. Include the
problem, intended behavior, scope, acceptance criteria and a reproducible fixture.
For bugs, provide the exact command, MoonPress commit, toolchain version,
OS/architecture, exit status and relevant diagnostics. Remove secrets and private
content from examples. The [bug template](.github/ISSUE_TEMPLATE/bug.md) helps.

Create an issue-linked branch such as `fix/123-output-validation` or
`feat/123-feature`. Keep each PR independently reviewable and use `Refs #123`;
use `Closes #123` only when every acceptance criterion is met. Explain behavior
changes, test evidence and remaining limitations. Maintainers merge after
validation; contributors should not assume merge permission.

For code changes, run the commands above and commit updated `pkg.generated.mbti`
interfaces. Include a regression that fails before a bug fix. Documentation-only
changes need accurate examples and valid local links; avoid tests that merely
repeat the implementation.

## Architecture

| Area | Files | Responsibility |
| --- | --- | --- |
| Build orchestration | `builder.mbt` | Validate inputs/output ownership, plan all artifacts, then apply changes |
| Incremental state | `incremental.mbt` | Hashes, dependencies, manifest validation and rebuild reasons |
| Content | `document.mbt`, `markdown.mbt`, `links.mbt`, `headings.mbt` | Metadata, shared parsers, references, rendering and anchors |
| Site outputs | `collections.mbt`, `sitemap.mbt`, `moonpress.mbt` | Lists, sitemap, escaping and one-pass layout substitution |
| CLI | `cmd/main/main.mbt` | Arguments, report format and exit status |
| Native boundary | `path_guard.c` | POSIX file-kind checks and directory lock lifecycle |
| Verification | `*_test.mbt`, `scripts/*-test.sh` | Pure-function tests and real CLI/filesystem regressions |

Keep compiler behavior in MoonBit and argument handling in the CLI. Shell handles
setup, CI and deployment. Do not introduce JavaScript, TypeScript, Node/npm,
generated JavaScript, or Node-based Actions. Use only the native MoonBit target.

## Correctness and compatibility

- Validate the complete plan before mutations. Unknown files, edited outputs
  and invalid input must not be overwritten to make a build pass.
- For build changes, compare clean and incremental outputs including manifests.
  Check no-op mtimes, deletions, missing output restoration and explain behavior
  where affected. Check must stay read-only.
- Use shared parsers for rendering, link validation, title discovery and TOC.
  Document new Markdown syntax as a subset, without claiming CommonMark support.
- Escape source text and never re-expand inserted template values. Public assets
  and templates are trusted project files, not sanitized uploads.
- Rendering changes require reviewing the relevant renderer dependency versions
  in builder/collections/sitemap so old cache entries cannot retain stale HTML.
- Review public API, manifest and CLI JSON schema changes explicitly. Preserve
  default text output and exit codes unless a documented change is intended.
  Explain migration/rebuild requirements for incompatible state.
- Keep ordering deterministic. Performance changes need measured evidence and
  correctness checks, not comparisons inferred from language choice.

For performance work, see [benchmarks/README.md](benchmarks/README.md). Report
revision, environment, toolchain, workload and repeated raw measurements. Prior
baseline numbers are historical evidence, not current guarantees.

Contributions are distributed under the repository's [Apache-2.0 license](LICENSE).
