# Categories

Categories are distinct from tags. JSON frontmatter accepts `"categories":["Science","日記"]`, default empty. Names are trimmed, deduplicated and deterministically sorted; each is 1–96 UTF-8 bytes, with at most 64 entries. They are flat labels; hierarchy is not implemented.

`moonpress post-categories SITE NAME.md EXPECTED_SHA "newline-separated names" [--json]` saves only categories while retaining body and other metadata. An empty string clears categories. Stale versions are refused; enabled history retains the preimage.
