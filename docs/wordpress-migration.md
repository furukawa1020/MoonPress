# WordPress content migration

`moonpress wxr-export SITE https://original.example/ --json` returns a private
WXR 1.2 document in `report.xml`, a count and warnings. Extract that string with
an appropriate JSON reader and keep the file private: it includes drafts and
exact source text. This command reads content under its authoring lock and never
writes a destination or changes publication. Limits are 4096 source files,
4 MiB per source, 16 MiB combined sources and 64 MiB encoded output.

The export maps titles, Markdown-rendered HTML, excerpts, flat categories/tags,
post/page types, slugs and UTC dates. Drafts remain drafts; future content uses
WordPress's future status. Unlisted maps to draft with a warning because WordPress
has no equivalent native visibility. Missing dates use a deterministic 1970-01-01
fallback. The exact native source and filename are retained as protected custom
metadata, including CRLF. Source with invalid XML characters is rejected.

Independent XML checks cover namespace/escaping/status/source fidelity. The
WordPress benchmark CI additionally imports an actual native fixture through the
official WordPress Importer 0.9.6 into its disposable WordPress 7.1.3 database and
checks resulting content, status, source and post taxonomies. Its plugin download
happens after timed experiments and its archive checksum is recorded in logs.
A CI configuration alone is not proof that this test has passed; inspect the run.

This is content interchange, not WordPress PHP theme/plugin/runtime compatibility.
No users, comments, attachment files, hierarchy or site options are exported.
WordPress core pages do not register categories/tags; those fields remain in native
source metadata. Relative links/assets and permalink differences need migration
review; media is not silently downloaded or rewritten. Review the resulting
WordPress site before making it public. Gutenberg/shortcodes/PHP extensions still
need their own supported implementations and interoperability tests.

Reference: https://developer.wordpress.org/reference/functions/export_wp/
