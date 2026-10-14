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

## Incoming and outgoing references

`query_references(graph, output_name)` returns `RouteReferences` with route
metadata, draft scope, deduplicated incoming/outgoing edges and the scope note.
Self references appear in both directions. `inspect_backlinks(site, output_name,
include_drafts=false)` compiles one graph then queries it. Names are exact
decoded output filenames (for example `月.html`), not source paths or URL strings.
Unknown names are errors, while a known route with no incoming edges returns an
empty incoming array. Queries validate graph structure and preserve caller data;
they do not certify the provenance of externally constructed graph objects.

## CLI

```sh
moonpress references my-site --json
moonpress backlinks my-site guide.html
moonpress backlinks my-site 月.html --include-drafts --json
```

`references` prints the graph; `backlinks` prints a route query. JSON uses the
schema-1 command envelope with `include_drafts` and the corresponding report.
Text shows source/consumer/kind/original URL/target/fragment, with user text JSON
quoted. Each optional flag can appear once in either order. Success exits 0;
invalid sites/unknown routes exit 1 with empty stdout and stderr detail; incorrect
arguments exit 2 with command-specific usage. Run these before changing a slug
or deleting a source, while the current site is valid. A broken site produces
an error, not partial backlinks or a false zero-reference result.
