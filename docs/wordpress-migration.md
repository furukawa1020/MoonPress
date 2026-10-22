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

## Reviewed native intake

```sh
moonpress wxr-inspect private.xml --json
moonpress wxr-import SITE private.xml INSPECTED_DIGEST POST_ID new-filename-stem --json
```

Inspection is read-only and returns each item's proposed source or an explicit
error. Import selects exactly one inspected ID, verifies the WXR digest, refuses
existing files/unsafe stems and writes a new mode-0600 draft under the retained
content directory lock. It never overwrites, downloads attachments, builds or
publishes. Imported articles need review before ready status; native slugs are
removed so the selected new filename is authoritative. Existing private/native
visibility metadata is retained. Source normalization and the forced draft edit
are deliberate changes; the exported raw source is still available in the WXR.

The native reader supports canonical WXR 1.2 wp/content prefixes, UTF-8 XML,
CDATA and built-in/numeric entities. It rejects DTDs/external entities, nested
namespace declarations, malformed nesting/duplicates, invalid characters and
excessive depth/nodes. Input is bounded to 16 MiB before file allocation, 100,000
nodes, depth 32, 64 attributes/element and 4,096 items; imported sources must fit
the 4 MiB editor limit. It is a bounded WXR reader, not a general XML processor.

Without native source metadata, plain text and attribute-free p/h1-h6 HTML with
text-only children are supported. Inline/complex HTML, Gutenberg, shortcodes,
private/password posts, comments, custom fields/taxonomies and nested page
hierarchy produce explicit item errors. Authors, original URLs/GUIDs, discussion
settings, ordering and site options are not applied and are reported as warnings.
Native source metadata must agree with exported content/title/type/taxonomy/date/
route fields; stale metadata is refused. No lossy fallback is applied silently.

CI checks actual core WordPress export -> native inspection -> private draft
intake in addition to native export -> official WordPress importer. The official
Importer 0.9.6 archive is pinned to SHA256
`85cfad65e24eb3b25ed536f52ce52c3971bd42a852d6f2c6a5bea8c5c429c323`.
