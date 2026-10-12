# Compiler dependency inspection

`inspect_dependencies(site, include_drafts=false)` runs the existing in-memory
compiler planner and returns page count, draft mode and output artifacts with
exact output digests and direct dependency name/digest pairs. Artifacts and
edges are sorted deterministically without mutating planner or caller arrays.
The output digest describes the bytes a fresh build would generate.

This uses full saved-source compiler validation, including layouts, routes and
supported links. It creates no output directory, manifest, staging or source
files. It does render output in memory to calculate digests; no performance
advantage over ordinary validation is claimed. Drafts are excluded by default.

Dependency names are exact compiler keys. Some represent source files; others
represent compiler versions, configuration values or derived collections/routes.
This is a direct dependency graph, not a transitive source-provenance graph.
For example, changing an article's metadata can also change a collection's
synthetic key. The graph is not a complete prediction of an arbitrary future
edit. Use `explain` against existing output after saving changes to inspect the
actual rebuild plan. Inspection describes saved files as observed, without
locking external editors or validating an existing deployment.

## CLI

Run `moonpress deps <site-directory> [--include-drafts] [--json]`. Text reports
list outputs and direct edges; schema-1 JSON contains the native graph report.
Draft mode includes private draft nodes in the report, not any deployed output.
Both flags may appear once in either order. Successful reports exit 0; source
validation/I/O failures exit 1 with stderr and empty stdout, invalid arguments
exit 2. No output-directory argument or existing manifest is required.

## Direct dependency impact

`dependency_impact(graph, names)` is a pure query over a validated graph;
`inspect_impact(site, names, include_drafts=false)` composes it with saved-source
inspection. Requests must contain at least one nonempty exact compiler key.
Duplicate keys are removed and reports have deterministic requested/unknown
names and output order. Matched outputs include their digest and matched keys.
Externally constructed graphs use the shared manifest validation rules.

Unknown keys remain explicit. They do not prove that changing a file is safe or
irrelevant: a newly introduced/deleted input, excluded draft, derived collection
or future metadata edit can have effects outside direct edges of this graph.
Use `deps` to find actual keys and `explain` after saving changes for the real
incremental plan. Queries do not mutate arrays, sources or output, and do not
predict a transaction or deployed state.

Run `moonpress impact <site-directory> <dependency-name>
[--include-drafts] [--json]` for an exact-key query. For example:

```sh
moonpress deps my-site --json
moonpress impact my-site content/guide.md --json
moonpress impact my-site layouts/post.html
```

Unknown keys still produce a successful report (exit 0), with an explicit
`unknown` array or `UNKNOWN` text row. They are not silently treated as evidence
of no effect. Invalid queries or source validation/I/O failures exit 1 with
stderr/empty stdout; incorrect arguments exit 2. The native API can query several
keys together; this CLI accepts one key. Nothing is rebuilt or deployed.
