# Publishing MoonPress with GitHub Actions

The `Publish Pages` workflow checks and compiles MoonPress, generates `site/`,
and pushes only HTML/CSS to `gh-pages`. All workflow steps are Bash; no Node
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
the expected commit to be built and fetches the homepage before success.
Relative CSS/navigation links work under the `/MoonPress/` project prefix.

Expected site URL once deployment succeeds:
https://furukawa1020.github.io/MoonPress/

## Local preview

Generate a fresh output directory with the CLI. Open its index.html directly
in a browser. No development server or JavaScript is required.

## Current limits

The publish script targets GitHub.com and the MoonPress demonstration site.
It is infrastructure for this repository, not yet a general `moonpress deploy`
CLI command. The installed toolchain is guarded by an exact version check;
future upstream releases require an explicit toolchain update.
