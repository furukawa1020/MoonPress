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

The required `backlinks` output argument is positional data, so valid names such
as `--draft.html` are accepted. Options follow it: `backlinks site --draft.html
--json`. Unknown or repeated trailing options remain argument errors.

## Changing article URLs

Inspect the old output name before editing a slug, optionally including drafts.
Incoming edges identify authored links to update and selected template consumers.
After saving changes, validate again. A broken local link blocks both graph
inspection and publication before output changes. A configured static redirect
can preserve an old route; its edge records the resolved terminal destination.
Redirect pages do not inherit the destination page's Markdown or template edges.
Generated heading fragments must still pass the existing heading validator;
a redirect is not a promise that every old fragment will reach a heading.

Changing a selected layout changes template-reference evidence. Making a draft
ready adds its references to the normal graph; unlisting it does not remove
them. These facts describe navigation, not incremental content dependencies:
editing a linked page need not rewrite a referring page whose HTML is unchanged.
Use `plan`/`review` for the actual writes and `deps`/`impact` for rebuild edges.

`query_references` also rejects externally constructed redirect edges whose
origin is not a redirect or whose target/fragment contradicts route metadata,
and refuses Markdown/template consumption attributed to redirect output.
Structural checks are not source provenance authentication.

## Site-wide counts (native API)

`summarize_references(graph)` validates a public `ReferenceGraph` and returns a
`ReferenceSummary`. `inspect_reference_summary(input, include_drafts~)` compiles
the saved site once and returns the same report without writing files.

Every output route appears, sorted by decoded filename, including assets,
archives, redirects and markers with zero edges. Exact duplicate evidence is
counted once. Each row contains:

- `incoming`: authored edges targeting this output, including self references.
- `outgoing`: authored edges consumed by this output, including self references.
- `self_references`: edges whose consumer and target are this same output.
- `referring_outputs`: distinct **other** output filenames referring here.

Two URLs/fragments from one page count as two edges but one referring output.
A selected template can contribute edges for several consuming outputs.
Redirects contribute their own resolved terminal edge. Counts describe this
graph and draft scope, not unique people, external traffic, reachability from
the home page or deployment status. Zero other referrers does not prove that
an output is unused or safe to delete.

The summary validates graph structure through the same boundary as backlinks;
it does not authenticate caller-provided graphs or discover omitted evidence.

## Summary command

```sh
moonpress reference-summary my-site
moonpress reference-summary my-site --include-drafts --json
moonpress backlinks my-site 月.html --json
```

The summary command lists the counts above for every output. Text rows quote
filenames; JSON uses the schema-1 command envelope with a typed summary in
`report`. Options may appear once in either order after the site directory.
Exit 0 means a complete report, 1 means compilation/I/O failure, and 2 means
incorrect arguments. Failures use stderr with no partial stdout report.

## Reading counts during edits

1. Inspect the ready-only summary, then include saved drafts if they may refer to
   the URL or asset. Open backlinks for exact source and template evidence.
2. Save a slug change and inspect again. Existing references to the old route
   cause validation failure until you update the links or configure a redirect.
   With a redirect, the old route retains its incoming authored links and has
   one outgoing terminal edge; the terminal page has that redirect as a referrer.
3. Change the chosen layout or article status and inspect again. Unused layouts
   and excluded drafts contribute no edges; ready unlisted pages still do.
4. Use the protected build plan/review workflow to inspect actual writes and
   deletions. Changing an asset's bytes can require a build while leaving every
   reference count unchanged. The summary is not an incremental-build plan.

The transition suite independently derives counts from graph edges for every
route, cross-checks backlinks, verifies source/output snapshots stay untouched,
and compares incremental output with fresh builds after each valid change.
