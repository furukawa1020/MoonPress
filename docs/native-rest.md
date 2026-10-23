# Native WordPress REST subset

`moonpress rest SITE PORT` starts a separate MoonBit-native listener at
`http://127.0.0.1:PORT/wp-json/`. It shares no editor session or mutation routes.
This is an explicitly limited API, not full WordPress REST compatibility.
Reference schemas: [posts](https://developer.wordpress.org/rest-api/reference/posts/),
[pages](https://developer.wordpress.org/rest-api/reference/pages/),
[users](https://developer.wordpress.org/rest-api/reference/users/).

| Route | Current behavior |
| --- | --- |
| `/wp-json/` | Discovery declares the implemented subset and omissions |
| `/wp-json/wp/v2/posts` | Public post list, default 10 items, date descending |
| `/wp-json/wp/v2/pages` | Public fixed-page list with the same filters |
| `/wp-json/wp/v2/posts/ID`, `/wp-json/wp/v2/pages/ID` | Public detail; authenticated `context=edit` and JSON POST updates of existing articles |
| `/wp-json/wp/v2/users/me` | Generated Basic credentials required; current identity only |

GET and HEAD are supported for reads. Collection parameters are `context=view`, `page`
(1–4096), `per_page` (1–100), one exact `slug`, `order=asc|desc`, and
`orderby=date|id`. Responses include `X-WP-Total` and `X-WP-TotalPages`.
Unknown/duplicate parameters are rejected. Detail accepts `context=view` or authorized `context=edit`.
Trailing collection slashes are accepted. `_fields`, `_embed`, search, taxonomies,
includes/excludes, authentication cookies, OPTIONS/CORS, XML-RPC, creation and
deletion are not implemented. No unknown parameters are silently treated as effective.

Post objects contain `id`, `date`, `date_gmt`, `slug`, `status`, `type`, `link`,
rendered `title`, rendered `content`/`excerpt` with `protected=false`, and
`author`. Titles and descriptions are escaped; content uses the native safe
Markdown subset. Public view contains no raw source, filesystem filename or version digest.
Edit context adds generated HTML `content.raw`, plain title/excerpt `raw`, a
`moonpress_revision` digest and its quoted HTTP ETag; it never returns the source
filename or exact Markdown/frontmatter.
Descriptions supply excerpts; automatic WordPress excerpt generation is absent.
Dates are native UTC publication schedule or date-at-midnight, falling back to
1970-01-01; arbitrary site timezones and actual modification timestamps are not
represented. Taxonomy numeric IDs, links/embeds, GUIDs, attachment data and
other WordPress fields are omitted rather than fabricated.

Draft, future and unlisted articles are excluded from public view even with
administrator credentials. An unlisted article's standalone static URL remains public; this
API exclusion does not make it private. Authenticated edit reads may return
nonpublic articles only when the caller can edit that exact article.
For `users/me` only, `context=edit` additionally returns the caller's username,
role and implemented capability subset. User email/profile data is not stored.

## Saved identities

REST requires every currently public source to have a unique positive integer
`wp_id` in frontmatter (1–2147483647). Optional `author` is a nonnegative local
principal ID; 0 means legacy unassigned. Missing public IDs and duplicate IDs,
including a collision with a draft, fail public content responses closed with a
generic 500. Nothing is silently assigned from array position or filename.
Normal static builds do not require REST IDs.

After reading the source version with `moonpress read SITE article.md --json`:

```
moonpress post-identity SITE article.md DIGEST 123 1 --json
```

This local owner command checks the current source version and refuses to
renumber an already assigned ID. IDs survive additions, content edits and source
renames. Raw source owners remain trusted and can alter metadata; they must keep
IDs globally unique and never reuse deleted IDs for a different article. There
is no historical ID allocation registry yet. Author values are local references,
not an imported identity proof. Duplicate and WXR intake clear identity/author
metadata so copies do not inherit another article's identity or another site's
authority. REST validates the entire bounded source snapshot under a content
lock, independently of the assignment command.

## Authentication and transport

Use a generated credential from [native access](native-access.md) as the HTTP
Basic password with its login name. Do not use a human password or put credentials
in URLs, command arguments, reports or published files. No login cookies or form
tokens confer API identity. Basic decoding is bounded, ASCII-only and canonical;
an invalid or revoked Authorization header produces 401, including on otherwise
public routes. Every identity request replays current access state. No credential
or principal cache delays revocation or role changes.

The listener is cleartext loopback only. Host must match the exact listener;
provided Origin must be the same origin. Duplicate headers, ambiguous framing,
cross-site fetches, encoded bodies and excessive headers/bodies are refused by
the existing strict native HTTP reader. Responses are no-store JSON with CSP,
nosniff and frame denial. Errors omit source paths, corrupt records and secrets.
Do not expose this development listener or the operator editor through a proxy
or tunnel. A reviewed public TLS/multiuser deployment boundary remains future
work. It serves requests serially with existing socket deadlines; static NGINX
throughput measurements do not measure this API's capacity.

At most 4096 source entries, 4 MiB per source and 16 MiB aggregate source bytes
are scanned per read; serialized JSON responses over 16 MiB are refused.
Incoming JSON bodies are limited to 256 KiB; large articles can still receive
partial title/status/excerpt changes without submitting their full content.
There is no claim of constant memory independent of source size.

Native unit and live socket tests cover visibility, IDs, pagination, escaped
content, strict requests and live identity rotation/revocation. After timed
benchmarks, the disposable actual WordPress core REST oracle compares the
implemented IDs/date/slug/status/type/author fields and rendered text for the
same WXR fixture. This verifies a subset; it does not verify every WordPress
client, response field, filter or plugin.

## Authenticated updates of existing articles

GET detail with `context=edit` requires generated Basic credentials. Subscribers
cannot edit. Contributors edit their own draft posts; authors edit their own
posts, including published posts. Editors/administrators edit others' posts and
pages. Legacy unassigned ownership requires editor/administrator privileges.
Published/ready/scheduled articles require the published-edit capability.

POST to the same numeric detail route with `Content-Type: application/json`
(or `application/json; charset=utf-8`), the credentials and `If-Match` equal to
the quoted ETag from the edit read. Missing conditions return 428; malformed
conditions 400; stale versions 412; missing/bad credentials 401; insufficient
role/ownership 403. All unsupported fields are refused. The source stays intact
on validation failures. A storage/durability error returns generic 500; reload
before retrying because a replacement may already be visible.

Supported string fields are `title`, `content`, `excerpt`, `status`, and
`date_gmt`. IDs, author, kind, slug, taxonomies, visibility and layout cannot be
changed here. Titles are nonempty native plain text and excerpts are plain text.
Content accepts the same bounded conservative HTML/plain-text conversion as WXR
intake: attribute-free paragraphs/headings with text only. Gutenberg, shortcodes,
inline/rich HTML, scripts and embedded media are refused. Returning an unchanged
`content.raw` preserves the existing Markdown exactly, including richer native
formatting. Empty updates and unchanged title/excerpt/content preserve exact source bytes,
mtime and history. This strict subset is not a drop-in Gutenberg save endpoint.

Status may be `draft`, `publish` or `future`. Publishing/scheduling requires the
post/page publish capability. `date_gmt` is strictly UTC `YYYY-MM-DDTHH:MM:SS`
without a suffix; future status requires a future timestamp. A publish request
without a date clears an existing future schedule. A publish request carrying a
future date remains scheduled. Draft date edits never publish the article. This
saves source only; static deployment/rebuild is still a separate operation.

The access vault stays locked from fresh authentication through publication,
and the retained content directory stays locked from identity/ownership lookup
through guarded save. The latter reuses ordinary durable staging, preimage
history and final source-version revalidation. The lock order is access,
content, history. Caught errors are not silently retried. A syscall-boundary
test pauses immediately before rename and proves revocation and another writer
are refused as busy until publication finishes. The disposable actual WordPress
oracle also compares 40 native HTTP edit permission decisions against core
`map_meta_cap` across all five roles, both ownership cases, post/page and
draft/published state. No user/admin mutation endpoints are present.

`_fields=id,title.rendered` selects bounded comma-separated properties after authorization, including nested properties. It applies to successful collection/detail/user/edit responses; unknown fields are omitted, never synthesized. Limits: 32 selectors, eight segments, 2048 characters. Error bodies and pagination/ETag headers remain intact.

Collection filters also accept `search` (up to 16 whitespace-separated AND terms, 256 characters), comma-separated `include`, `exclude`, `author`, `author_exclude` (100 unique positive IDs each), multiple `slug` values, `offset` (0–409600), and `orderby=title|slug|include`. Include ordering follows the supplied ID order. Search is case-insensitive literal native title/excerpt/body matching; SQL collation, quoted phrases, negative terms and relevance ranking are not emulated. Visibility is checked before all filters.

As in WP_Query, an explicit `offset` takes precedence over the page offset; page/total validation is retained.

Authenticated collection `context=edit` accepts `status=publish|draft|future|any` or up to three comma-separated statuses, with filtering/pagination after ownership authorization. Default status is publish. The native policy lists only articles the caller can edit, including authorized unlisted ones; it is deliberately stricter than WordPress collection-level edit permission. Subscribers are denied. Nonpublic rows/counts never leak through anonymous search or totals. Public context supports only status=publish.
