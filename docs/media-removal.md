# Reviewed media removal

`inspect_media_removal(site, name)` validates the complete saved site, including
drafts, and reports the asset's bytes/digest, known references and a review ID.
It writes no files. The ID binds exact site spelling, asset name/content and the
compiled draft-inclusive manifest. A changed relevant source invalidates it.

Known references include supported Markdown links/images, selected template
href/src attributes and configured redirects. A malformed source blocks
inspection instead of being silently omitted. CSS URLs, unsupported HTML and
external consumers are outside this graph: zero known references is not proof
that deletion is universally safe. Review these uses yourself and keep a backup.
Removal is permanent and has no undo. Generated output and hosting are updated
only by a separate reviewed build and deployment/removal procedure.
