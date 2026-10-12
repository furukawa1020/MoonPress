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
