# Article kinds

`"kind":"post"` is the default. `"kind":"page"` produces a public fixed page, included in the sitemap but excluded from article archives, tag archives and RSS. Draft and listed flags remain separate. Existing source URLs do not change when kind changes.

The editor offers a separate version-bound **Save type** form. Save the article first. The inventory Type filter distinguishes posts/pages. Native command: `moonpress post-kind SITE NAME.md EXPECTED_SHA post|page [--json]`. Enabled history keeps the prior source.
