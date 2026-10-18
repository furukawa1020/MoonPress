# Release readiness

MoonPress currently supports a tested Linux x86_64 native workflow for trusted,
flat-content projects. It remains experimental. Passing CI establishes the
covered behavior; it does not establish production readiness, crash safety,
CommonMark compatibility or superiority to other site generators.

## Available and covered

- Reviewed permanent media removal with draft/template reference checks, exact snapshot IDs, explicit acknowledgement, retained-directory unlink and CLI/browser confirmation. CSS/unsupported/external uses require manual review; no undo or implicit rebuild/deployment. See [media removal](media-removal.md).

- Verified current production ZIP export through native API, CLI and protected browser download, with review revalidation, deterministic UTF-8 archives, draft/internal-state exclusion and bounded output reads. Independent extraction, first-site handoff and destination failure/replacement regressions are covered; hosting remains separate. See [ZIP export](site-export.md).

- Versioned raster thumbnails in media/replacement screens using bounded no-follow source reads; no build needed to view saved PNG/JPEG/GIF/WebP images.
- Verified preview HEAD and digest-based conditional GET/HEAD with rebuild invalidation.

- Separate-origin local HTTP preview integrated with administration; generated HTML, CSS and images are viewed without serving project HTML on the editor origin.
- Read-only Publish readiness screen distinguishing missing/stale/current production output from actual deployment.
- Linux native preview packaging with checksum/provenance/notices and unpacked no-toolchain smoke test.
- End-to-end HTTP form journey from initialized site through images, draft preview, ready status and reviewed production build.

- Native `init` command producing a ready-to-check/build starter without overwriting existing targets.

- Markdown subset with task lists, strikethrough, explicit paragraph/quote breaks, single-line Setext headings and flat pipe tables.
- JSON metadata, draft preview, heading anchors and TOC.
- Per-page named layouts, article/tag collections, optional sitemap and flat static assets.
- Preflight local route/generated-heading reference checks and guarded incremental output ownership.
- Deterministic clean/incremental output, explain/check modes and versioned JSON reports.
- Read-only output integrity audit, compiled direct dependency graphs and exact-key impact queries with explicit unknowns.
- Validated snapshot comparison and detailed protected build plans with complete dependency deltas.
- Reviewed plan identities and locked build enforcement, shared by native CLI and browser production forms.
- Source-aware authored reference graphs, per-route incoming/outgoing queries and site-wide counts shared by compiler validation, native CLI and local browser output inspection. Self edges and distinct other referrers are separate; zero counts do not certify safe deletion.
- Versioned binary media replacement via native API, CLI and browser file picker;
  staged writes, exact-byte no-op, observed staging/target checks and fault/race
  regressions. Separate build/deployment, no undo journal or power-loss claim.
- Output filename byte limits, strict manifest/journal field validation and source file-kind checks.
- Staged preparation, per-file replacement and caught-error rollback; explicit recovery of journaled interruptions.
- Cooperative build/explain/plan/recover locking on local Linux filesystems, including new outputs.
- Native tests and shell-only GitHub Actions workflows.

See [content semantics](content.md), [contributing](../CONTRIBUTING.md) and
[deployment](deployment.md) for the exact contracts and exclusions.

## Gates before a stable distribution

| Gate | Evidence required | Tracking |
| --- | --- | --- |
| Reproducible toolchain | Fixed official binary/core archives with pinned checksums, native-only bundling, clean-install CI and tamper/version tests | [#11](https://github.com/furukawa1020/MoonPress/issues/11) |
| Verified example deployment | Pages enabled and generated HTML/CSS retrieved from the public URL | [#3](https://github.com/furukawa1020/MoonPress/issues/3) |
| Filesystem failure recovery | Journaled restart recovery implemented; pre-journal/final-cleanup gaps and power-loss durability remain open | [#49](https://github.com/furukawa1020/MoonPress/issues/49), [#53](https://github.com/furukawa1020/MoonPress/issues/53), [contract](publication.md) |
| Concurrent writer protection | Implemented for cooperative local Linux builds; parent-directory scope and tested limits documented | [#50](https://github.com/furukawa1020/MoonPress/issues/50), [contract](concurrency.md) |
| Distribution and compatibility | Versioned native artifact/checksum process, install smoke test, supported-platform statement and API/schema migration policy | Preview packaging/test implemented; signed stable assets, compatibility matrix and schema migration policy remain |

Current builds are not transactional. Cooperative writers use directory locks;
external tools and old MoonPress versions that do not lock remain unsupported.
After an interrupted publication, use explicit recovery with a complete journal;
unsupported remnants require a fresh output directory. Neither
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

## User-facing gates still open

- Actual browser visual/accessibility and first-time-user testing (HTTP integration is not a visual usability study).
- Verified public example deployment and general host integration/status. The Publish screen is local readiness only.
- Signed/versioned release assets and installation verification across supported Linux distributions; other operating systems remain unverified.
- Isolated preview intentionally disables project scripts/forms/external resource loads; it is not a full hosting emulator.
