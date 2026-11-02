# Related REST resources

MoonPress implements a public, one-level WordPress REST embedding subset in native MoonBit. JavaScript, TypeScript and PHP application runtimes are not required.

GET and HEAD under `/wp-json/wp/v2/` accept `_embed`, `_embed=author`, `_embed=author,wp:term`, and indexed/empty-bracket relation arrays. An absent selector leaves embedding off. Empty, `true`, `1`, and `0` request all supported relations; the string `false` selects an unknown relation and produces no embeddings. Unknown relation names are ignored. Selectors are bounded to 1,024 characters, 16 distinct relations and 128 characters per relation. OPTIONS advertises the read parameter. Mutating requests with `_embed` are refused before mutation, including `_embed=false`.

| Resource | Supported relations |
| --- | --- |
| Posts and pages | author, replies |
| Posts | wp:term (category first, post_tag second) |
| Comments | author, up (article), in-reply-to (parent), children (public direct replies only) |

Subrequests use internal routing with the authenticated principal and force `context=embed`. They do not fetch external URLs or recursively expand children. Existing publication, ancestor and user-visibility checks remain authoritative. Unavailable related resources appear as REST error objects; missing/empty relations do not manufacture resources. Native user privacy may return 404 where WordPress returns 401/403. Native comment writes require generated credentials and create moderated comments; anonymous-author creation remains unsupported. No implicit Uncategorized term is added to native articles.

Term and comment collection embeds request up to 100 records. This is a bounded, truncated collection, matching the route maximum used by WordPress embedding; it is not a completeness claim. CURIE relation selection uses the emitted `wp:term` name. `_fields=_embedded.wp:term` runs after authorization and embedding and preserves the category/tag slots.

Each request caches related URLs. Limits are 256 distinct internal subrequests, 8 MiB of cached JSON and 16 MiB of expanded output. Reused entries also count toward expansion bytes. Limit exhaustion returns a whole-request error without partial data, even if `_fields` would hide expanded data. These native safety bounds are intentional differences from WordPress.

Read responses without a source-version ETag use representation ETags after embedding and projection, so changes to related data invalidate them. Existing source-version ETags are preserved on embedded edit reads and writable comment reads, including `_embed=false`, and remain valid tokens for guarded writes. As before, those source-version responses do not use conditional representation revalidation. HEAD and `_envelope` preserve the same dispatch/authentication/projection behavior. Self `targetHints.allow` describes implemented route methods, not permission granted to a particular caller.

The disposable WordPress benchmark runs `benchmarks/wordpress/embed-oracle.py` against the actual version-pinned installation. It compares article/page/comment/author/term relationships and selector/error/empty-slot behavior with explicit ID mapping. Native HTTP tests additionally check private ancestors, forbidden mutations, cache exhaustion, byte accounting, conditional responses and field selection. This subset does not establish full WordPress/PHP plugin compatibility.
