# Authored reference graph

`inspect_references(site, include_drafts=false)` returns a read-only
`ReferenceGraph`: page count, draft scope, all compiled route metadata, local
reference edges and an explicit scope description. It uses the ordinary site
planner and must pass the same source, route and heading validation as a build.
Invalid sites fail; an empty result is never substituted for an error.

Each edge contains the source file/configuration key, consuming output filename,
kind, original URL, target output filename and optional fragment. Kinds are
`markdown-link`, `markdown-image`, `template-href`, `template-src`, and `redirect`.
Redirect URLs/targets describe the resolved terminal destination, not each
intermediate configuration hop. Target filenames are decoded names from the
route inventory. Queries are retained in `url` but do not change `target`.
Same-document fragments/query links point to the consuming output. Fragments
are percent-normalized where valid; opaque asset fragments with invalid percent
syntax are preserved without introducing stricter build validation.

The graph reuses parsed Markdown blocks and cached selected templates from
validation. Templates contribute one edge per consuming output; unused layouts
do not contribute edges, and redirect pages do not inherit layout references.
Identical edges are deduplicated, not counted as separate occurrences. Routes
and edges are deterministically sorted without modifying source data.

Only included articles contribute Markdown edges. Ready unlisted articles still
contribute; drafts require `include_drafts=true`. External URLs (including
absolute URLs pointing to the same host), generated archive/TOC/feed/sitemap
navigation, CSS URLs, and unsupported raw HTML are excluded. Inline/fenced code
does not contribute Markdown links. This is an authored-reference graph, not a
complete rendered-DOM crawl or a rebuild dependency graph. No incoming edges
does not prove that an output or asset is safe to delete.

Inspection performs no source/output writes and creates no output directory.
It describes observed source state, not a saved approval or deployment record.
