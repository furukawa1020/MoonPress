# Categories

Categories are distinct from tags. JSON frontmatter accepts `"categories":["Science","日記"]`, default empty. Names are trimmed, deduplicated and deterministically sorted; each is 1–96 UTF-8 bytes, with at most 64 entries. They are flat labels; hierarchy is not implemented.

`moonpress post-categories SITE NAME.md EXPECTED_SHA "newline-separated names" [--json]` saves only categories while retaining body and other metadata. An empty string clears categories. Stale versions are refused; enabled history retains the preimage.

The browser editor offers a separate **Save categories** form; save other edits first. Public listed posts generate `category-<UTF8 hex>.html` archives and `categories.html`; fixed pages, unlisted posts and normal-build drafts do not enter them. `tag_page_size` also controls category pagination. The starter Tags & categories navigation goes to `tags.html`, which includes category links and counts when `tag_index` is enabled. Projects without `tag_index` can link `categories.html` after assigning a published listed category. Removing the last category removes its generated index/archives; stale authored links are rejected before output changes.
