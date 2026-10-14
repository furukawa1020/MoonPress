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
