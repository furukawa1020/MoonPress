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

`remove_media(site, name, review_id, acknowledge_unscanned=true)` requires an
explicit acknowledgement of the limitations and permanent deletion. It retains
and locks public/, recomputes the same plan, refuses known references or a stale
ID, rechecks directory identity and target bytes, then unlinks only that asset.
No force option bypasses references; replay after removal fails.

The public-directory lock coordinates media writers. It is not a transaction
across content/layout/settings editors or hostile external writers. The final
observed-state checks do not eliminate every subsequent race. Unlink failure
preserves the file; success has no undo journal or power-loss durability claim.
Generated files stay unchanged until an explicit build; already hosted copies
remain online until your host applies removal.

## CLI

```sh
moonpress media-removal-plan site image.png --json
moonpress media-remove site image.png REVIEW_ID confirm-unscanned-removal --json
```

Use the returned review ID and identical site path spelling. The required final
argument acknowledges permanent removal and your manual check of unscanned
uses. Both reports always include draft references (`include_drafts: true`);
there is no draft-exclusion or force flag. A blocked inspection is a successful
report; an attempted blocked/stale removal fails with exit 1. Argument errors
use exit 2. Failures have empty stdout and diagnostics on stderr.
