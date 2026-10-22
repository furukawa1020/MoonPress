# Scheduled publication

Set `publish_at` in article JSON frontmatter to a canonical UTC instant such as
`2030-01-01T09:00:00Z`. Offsets, fractional seconds, leap seconds and invalid
calendar dates are rejected. `date` remains a calendar sorting/display field.

Production planning captures one current clock instant and excludes future
articles before generating their routes, archives, taxonomy indexes, feeds or
sitemap. Drafts remain excluded even after their due time. `--include-drafts`
includes both drafts and future articles for local preview; never publish it.
Links from published content to future routes fail the normal reference checks.
Once eligible content changes the output, a previously reviewed plan is stale.

Use the article editor's UTC schedule form, or:

```sh
moonpress read site article.md --json
moonpress post-schedule site article.md EXPECTED_SHA256 2030-01-01T09:00:00Z --json
moonpress post-schedule site article.md EXPECTED_SHA256 '' --json
```

Edits use current-source protection and retain history when enabled. No-op edits
preserve exact bytes. Removing a schedule makes a non-draft eligible immediately.
The plan uses the host clock, so keep it synchronized. This is a static compiler:
the timestamp alone cannot change already deployed bytes. Arrange a rebuild and
verified deployment at/after the due time. No background job, automatic deployment
or external scheduler is created by the editor. Approval/ready means not-draft;
a scheduled ready source still waits for its time during production planning.
