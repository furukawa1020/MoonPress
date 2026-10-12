# Duplicating articles

The native `duplicate_post` service copies a saved, valid article into a new
filename with an explicit title. It always creates a draft and clears the old
slug and date, so the destination filename determines the route and the copy
has no inherited publication date. Description, tags, layout, listed state and
Markdown body are retained. Frontmatter is serialized as JSON and body line
endings are normalized to LF; the original source is never rewritten.

The expected source SHA-256 is checked again under the same content-directory
lock used by authoring writers. The destination uses the shared exclusive-create
service; existing files, links and special entries are refused. Caught write
failures use its cleanup behavior. External editors do not share the lock; edits
after the final version check are outside the cooperative guarantee. A process
crash may leave a partial destination, which subsequent creation refuses.

Links are copied literally, not retargeted. Validate and preview the copy before
marking it ready. This operation validates metadata, not the entire site's
routes, links or named layouts, and never deploys anything.

## CLI

```sh
version="$(moonpress read my-site original.md --json | jq -r '.report.digest')"
moonpress duplicate my-site original.md "$version" article-copy "Copy title"
```

`--json` returns a schema-1 `duplicate` report with source, output, title and
`draft:true`. Invalid arguments exit 2; metadata/version/I/O failures exit 1 with
empty stdout. Draft inclusion is not an option: copies are always drafts.
