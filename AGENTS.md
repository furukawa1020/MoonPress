# MoonPress development contract

## Product
A small static-site compiler written in MoonBit. No TypeScript, JavaScript,
Node.js, npm, frontend framework, or generated JS in our sources, application,
or workflow steps. Toolchain distributions may contain unused backends;
compile and test only with `--target native`. Shell is allowed for setup/CI.
Do not use Node-based GitHub Actions; use shell and GitHub APIs.

## Issue-based workflow
1. Create or pick a GitHub Issue with concrete acceptance criteria.
2. Work on `feat/<issue>-<topic>` or `fix/<issue>-<topic>`.
3. Keep PRs small. Link `Refs #N`; use `Closes #N` only when ALL criteria pass.
4. Run native checks, meaningful tests and the CLI smoke test.
5. Merge frequently after validation, as explicitly requested by the owner.
6. Update issue progress honestly. Never mark deployment complete before checking it.

## Commands
- `bash scripts/setup.sh` then add `$HOME/.moon/bin` to PATH.
- `bash scripts/check.sh` checks, tests, compiles and tests the executable.
- `moon info --target native && moon fmt` before submitting changes.
- `moon run cmd/main --target native -- build site dist` (dist must not exist).

## Architecture and correctness
- Root library: pure render functions and site compilation.
- `cmd/main`: argument handling only; keep business logic in the library.
- Markdown is an explicitly documented subset, not CommonMark compatibility.
- Escape untrusted content, never evaluate source templates or shell commands.
- Do not delete or overwrite existing user directories.
- Deterministic ordering/output. Incremental output must equal a clean build.
- Generated `.mbti` interfaces must be committed and reviewed.
- Measure size and performance; do not claim superiority without evidence.
- No need to delegate; keep changes understandable and easy to review.
