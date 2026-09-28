# Release readiness

MoonPress currently supports a tested Linux x86_64 native workflow for trusted,
flat-content projects. It remains experimental. Passing CI establishes the
covered behavior; it does not establish production readiness, crash safety,
CommonMark compatibility or superiority to other site generators.

## Available and covered

- Markdown subset, JSON metadata, draft preview, heading anchors and TOC.
- Article/tag collections, optional sitemap and flat static assets.
- Preflight local reference checks and guarded incremental output ownership.
- Deterministic clean/incremental output, explain/check modes and versioned JSON reports.
- Output filename byte limits, manifest validation and source file-kind checks.
- Native tests and shell-only GitHub Actions workflows.

See [content semantics](content.md), [contributing](../CONTRIBUTING.md) and
[deployment](deployment.md) for the exact contracts and exclusions.

## Gates before a stable distribution

| Gate | Evidence required | Tracking |
| --- | --- | --- |
| Reproducible toolchain | Fixed official archive or permitted mirror, pinned checksums, clean-environment rebuild and mismatch tests | [#11](https://github.com/furukawa1020/MoonPress/issues/11) |
| Verified example deployment | Pages enabled and generated HTML/CSS retrieved from the public URL | [#3](https://github.com/furukawa1020/MoonPress/issues/3) |
| Filesystem failure recovery | Defined recovery contract and fault injection across artifact/manifest publication | [#49](https://github.com/furukawa1020/MoonPress/issues/49) |
| Concurrent writer protection | Exclusive writer lifecycle, alias policy, crash cleanup and two-process regressions | [#50](https://github.com/furukawa1020/MoonPress/issues/50) |
| Distribution and compatibility | Versioned native artifact/checksum process, install smoke test, supported-platform statement and API/schema migration policy | Plan after the reproducible toolchain gate |

Current builds are not transactional and concurrent writers are unsupported.
After a partial filesystem failure, use a fresh output directory. Neither
source/output checks nor the manifest authenticate untrusted projects or defend
against concurrent hostile path changes.

Linux x86_64 is the only tested platform. Do not advertise macOS, Windows or
other architectures until native CI, filesystem semantics and installation have
been verified there. The existing benchmark records must be remeasured on the
release revision before publishing new size/speed claims.

## Feature direction

Nested content/assets, additional Markdown syntax and richer diagnostics can be
proposed as separate issues with fixtures and compatibility criteria. Their
presence here is not an implementation or release-date promise. Core correctness
and a reproducible installation take priority over a larger feature checklist.

Promotion should link to a working, verified example and honest installation
instructions. A gh-pages branch push alone is not proof of a publicly deployed
site; keep the deployment gate open until the public endpoint is checked.
