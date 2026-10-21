# Publishing MoonPress with GitHub Actions

The `Publish Pages` workflow checks and compiles MoonPress, generates `site/`,
and pushes only validated public artifacts (HTML, CSS, assets, feeds and
`.nojekyll`) to `gh-pages`. Local manifests and recovery state are excluded. All workflow steps are Bash; no Node
Actions, npm, JS or TS are used by the configured pipeline.

## One-time GitHub setting

After the first run creates the branch, open:
https://github.com/furukawa1020/MoonPress/settings/pages

Choose **Deploy from a branch**, branch **gh-pages**, folder **/ (root)**.
Save, then rerun `Publish Pages` from the Actions tab.

GitHub does not allow the workflow's GITHUB_TOKEN to create a Pages site.
The workflow intentionally fails with an actionable message if Pages has
not been enabled, rather than falsely reporting a successful deployment.
It uses only contents:write and pages:write; no personal token is needed.

The script explicitly requests a Pages build after publishing, because a
workflow-token push does not automatically trigger a build. It waits for
the expected commit to be built, then retrieves every packaged artifact and
compares its bytes before success. Git and API calls have finite timeouts, as do
individual HTTP requests and the complete verification step. A matching homepage
heading alone is insufficient.
Relative CSS/navigation links work under the `/MoonPress/` project prefix.

Expected site URL once deployment succeeds:
https://furukawa1020.github.io/MoonPress/

## Local preview

Use the admin **Build full preview files** action, then **Open built preview**.
The read-only preview uses a separate loopback port. Alternatively run
`moonpress preview OUTPUT PORT` for an already-built directory. Rebuild explicitly
and reload after edits. See [preview](preview.md).

The admin **Publish** screen validates local production readiness and provides a
hosting handoff. It does not upload files or verify the public URL.

## Current limits

The publish script targets GitHub.com and the MoonPress demonstration site.
It is infrastructure for this repository, not yet a general `moonpress deploy`
CLI command. The installed toolchain is guarded by an exact version check;
future upstream releases require an explicit toolchain update.

## Manual ZIP handoff

For a host-managed upload, build normal production output and use the admin
Publish page's **Download production ZIP**, or the native `export` command.
See [ZIP export](site-export.md). Extract the archive unless your host accepts
ZIP uploads, preserve filenames (including `.nojekyll`), synchronize deletions,
and verify the actual public URLs. A successful download does not establish
that hosting is configured or that a deployment succeeded.

Publication packaging is also available locally as
`bash scripts/prepare-pages.sh dist NEW_DIRECTORY`. It refuses unhealthy output
and copies only manifest-owned bytes. `bash scripts/verify-pages.sh DIRECTORY URL`
checks a prepared bundle against an HTTP(S) host. Local fixture success is not
evidence that the demonstration Pages site is configured or reachable.

## Verification status (2026-10-21)

The native compiler and local packaging/HTTP verification fixtures pass. The
[hosted workflow run](https://github.com/furukawa1020/MoonPress/actions/runs/39551215602)
compiled the demonstration site but received HTTP 404 from the repository Pages
API and stopped at the explicit setup gate. Enable Pages using the one-time
setting above before claiming a public deployment. A remote branch push and a
passing native CI run do not close that gate. Real-browser visual, keyboard and
download verification also remains outstanding.
