# Generated route inventory

`inspect_routes(site, include_drafts=false)` compiles and validates sources in
memory once, using the same site plan as build/check/deps. It writes no files
and needs no output directory. The report includes source-page count, draft
scope and deterministically sorted route records. Each record has `name`, `kind`,
optional `source` and optional terminal redirect `target`.

Kinds are `page`, `archive`, `asset`, `marker`, `feed`, `sitemap`, `redirect`.
Source pages retain their actual content filename even with metadata slugs;
public assets retain their source path. Generated collections/feeds/markers
have no single source file. Redirects identify their effective config key and
resolved target. Output names are literal filenames; URL-encode them for links.

Every planned artifact appears exactly once, including CSS and `.nojekyll`.
The ownership manifest and staging/journal files are bookkeeping, not routes.
Excluded draft source events do not enter the inventory. Draft-inclusive reports
show private draft routes but never publish them. Current output integrity and
future edits are outside this source-only report; use audit/plan for those.

## CLI

```sh
moonpress routes site
moonpress routes site --json
moonpress routes site --include-drafts --json
```

Text rows show kind/name/source/target; optional values are printed as JSON null
or quoted strings. JSON uses the common schema-1 envelope with command `routes`,
draft scope and the inventory in `report`. Both flags may appear once in either
order. A valid inventory exits 0; source/validation/I/O errors exit 1 with empty
stdout; incorrect arguments exit 2. Inspection performs current compiler
preflight, including redirects and layout links. No hosting/deployment check.
