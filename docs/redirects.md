# Static redirects

`resolve_redirects(mappings, planned_outputs)` validates safe flat `.html`
filenames, uniqueness and output collisions. It follows every mapping to a
terminal planned HTML output, rejecting self/multi-node cycles and dangling
paths. Resolution is iterative and deterministic; caller arrays are preserved.
Routes are literal output filenames, not URL strings, paths or fragments.

`render_redirect(target, base_url=None)` emits an escaped HTML meta refresh,
visible fallback link and noindex metadata. If supplied, the normalized HTTP(S)
base produces an absolute canonical link to the terminal target. Filename bytes
are percent-encoded in URLs. No JavaScript is emitted. Rendering alone does not
validate that a target exists: use graph resolution against the compiler plan.

These are static HTML redirects, not HTTP 301/308 responses. Server/browser
behavior and preservation of incoming query strings/fragments are not promised.
For server status redirects, configure your host separately.

## Site configuration

```json
{"base_url":"https://example.org/project/","redirects":{"old.html":"new.html","older.html":"old.html"}}
```

Omit `redirects` or use `{}` for no aliases. Null/non-object values, non-string
targets and unsafe names are errors. Each target must resolve to an actual planned
non-redirect HTML page or collection; excluded drafts do not qualify. Chains
compile directly to their terminal target. Names collide with all source, asset
and generated outputs; old source files must be removed or renamed first.

Generated aliases participate in ownership, dependency graphs, dry runs, staged
publication and recovery. Removing a mapping deletes its tracked file. Only
aliases whose resolved target or base URL changes rebuild; edits to unrelated
source bodies do not rebuild redirects. Dependencies describe effective mapping
values, not the entire config file. Redirects are omitted from the sitemap, and
redirect pages define no generated `mp-` anchors; link such anchors directly to
the target page. Validation happens before output mutation in every build mode.
