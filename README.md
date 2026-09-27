# MoonPress

A small static-site compiler written in **MoonBit**. Native executable in,
HTML + CSS out. No TypeScript, JavaScript, Node.js or npm in the application
or CI workflow. Experimental bootstrap, not a production-ready SSG.

## Quick start

Prerequisites: Linux x86_64, a C compiler, curl, Git and Bash.

```sh
bash scripts/setup.sh
export PATH="$HOME/.moon/bin:$PATH"
bash scripts/check.sh
moon run cmd/main --target native -- build site dist
# Or after release compilation:
_build/native/release/build/cmd/main/main.exe build site dist-new
```

The CLI reads `content/*.md`, `layout.html`, and `style.css` from the input
directory. It generates one `.html` per page, copies CSS, and adds `.nojekyll`.
A fresh output directory is initialized with `.moonpress.json`. Subsequent builds
update only changed artifacts and remove tracked outputs whose sources were deleted.
Unmanaged directories, unknown files, edited outputs and symlinks are rejected.
Templates are trusted project files; Markdown content and titles are escaped.

Supported Markdown: ATX headings 1–6, paragraphs, and triple-backtick code
fences, flat unordered/ordered lists and block quotes. Unsupported syntax is plain text.
Simple links, images and inline code are supported; no inline emphasis,
nested content directories yet. Optional `public/` assets are copied as bytes with
per-file incremental dependencies. JSON frontmatter,
article lists, tag pages, sitemap and preflight link checks are supported; see [content model](docs/content.md).
This is not a CommonMark implementation.

## Development

`moon check`, `moon test`, and `moon build --release` use the native target
configured in moon.mod. Run `moon info --target native && moon fmt` before PRs.
`scripts/check.sh` also tests deterministic output and error handling.

The verified toolchain is moon 0.1.20260920 / moonc v0.10.14+7d59c7ec9.
Setup currently downloads the official latest distribution **and rejects a
version mismatch**. It does not silently accept future versions. Archived,
checksum-pinned toolchain distribution is a follow-up reproducibility task.
The `moonbitlang/x` dependency is explicitly versioned at 0.5.5 for native I/O.
Toolchain and dependency packages may contain unused JS backends; MoonPress
never builds or invokes them.

## Issue roadmap

- [#1 Native environment and CI](../../issues/1)
- [#2 Minimal site compiler](../../issues/2)
- [#3 GitHub Pages deployment](../../issues/3)
- [#4 Dependency graph and incremental build explanations](../../issues/4)
- [#5 Reproducible size/performance measurements](../../issues/5)
- [#6 Metadata, lists, tags, sitemap and link validation](../../issues/6)

Work in small issue-linked branches and PRs; merge after checks pass.
“Ultra-lightweight” is a goal, not a verified comparative performance claim.

Apache-2.0. See LICENSE.

## Incremental builds and explanations

```sh
moonpress build site dist
moonpress explain site dist   # dry-run: no directories/files written
moonpress build site dist     # unchanged artifacts keep their mtime
```

Each output records explicit SHA-256 dependencies: a page depends on its source,
layout and renderer revision; CSS depends only on its source. Builds still read
and hash inputs and verify output integrity, but skip rendering/writing unchanged
pages. Changed pages are rendered; rename/delete removes tracked stale output.
The report names changed dependencies. Clean and incremental outputs are tested
for byte-for-byte equality, including the manifest.

Do not edit generated files or run concurrent builds into the same directory.
This version is not transactional across filesystem failures: after a partial
write failure, generate into a fresh directory. The manifest is written last.
A tiny POSIX C shim provides `lstat` checks; all dependency and compiler logic
is MoonBit. Linux x86_64 is the tested platform. Unmanaged contents are never
recursively removed. These checks are for trusted local projects, not a sandbox
against a concurrent hostile process changing filesystem paths.
