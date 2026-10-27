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
| `/wp-json/wp/v2` | Read-only namespace index; optional `context=view` |
| `/wp-json/wp/v2/posts` | Public post list; authenticated JSON POST creates a new post |
| `/wp-json/wp/v2/pages` | Public fixed-page list; authenticated JSON POST creates a new page |
| `/wp-json/wp/v2/posts/ID`, `/wp-json/wp/v2/pages/ID` | Public detail; authenticated `context=edit`, JSON POST/PUT/PATCH updates and guarded DELETE to trash |
| `/wp-json/wp/v2/users/me` | Generated Basic credentials required; current identity only |
| `/wp-json/wp/v2/search` | Public post/page universal search subset |
| `/wp-json/wp/v2/types`, `/types/post`, `/types/page` | Implemented post/page metadata; edit fields scoped to editable types |
| `/wp-json/wp/v2/statuses`, `/statuses/NAME` | Implemented publish/draft/future/trash metadata; nonpublic states require editing capability |

GET and HEAD are supported for reads. Collection parameters are `context=view|embed`, `page`
(1–4096), `per_page` (1–100), comma-separated `slug`, `order=asc|desc`, and
`orderby=date|id|title|slug|include|author|include_slugs`. Responses include `X-WP-Total` and `X-WP-TotalPages`.
Unknown/duplicate parameters are rejected. Detail accepts `context=view|embed` or authorized `context=edit`.
Trailing collection slashes are accepted. `_embed`, taxonomies,
authentication cookies, cross-origin CORS, XML-RPC, permanent deletion and remote trash restoration are not implemented. No unknown parameters are silently treated as effective.

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
represented. Taxonomy numeric IDs, embedded resources, GUIDs, attachment data and
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
IDs globally unique and never reuse deleted IDs for a different article. API creation reserves IDs in an append-only private allocation log before publishing source. Local manual assignments remain trusted and must never reuse historical IDs. Author values are local references,
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
Content accepts the same bounded HTML/plain-text conversion as WXR intake:
paragraphs/headings, representable inline formatting/links/code, flat lists and
validated basic static blocks as described below. Unsupported blocks/HTML,
scripts and embedded media are refused. Returning an unchanged
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

## Native REST creation

Authenticated JSON POST to posts/pages collections accepts string title/content/excerpt/slug/status/date_gmt. Title is required and nonempty. Contributors can create draft posts, authors can publish their own posts, and editors/administrators can create pages. Author is always the authenticated principal; caller-supplied author/ID/type/visibility and unknown fields are refused. Status defaults to draft; dates default to the captured current UTC instant. Supported native content conversion and 256 KiB request limits apply. No build or hosting deployment occurs.

Responses are 201 with an edit-context object, ETag and relative Location header. Slugs are safe flat native stems; omitted slugs derive from the title or post/page ID. Existing filenames and canonical slugs are preserved by trying -2 through -128 suffixes. Native Unicode slugs are not WordPress percent-encoded database slugs.

The private `.moonpress-identities` log reserves a strictly increasing positive ID before exclusive mode-0600 source creation, under access/content/identity locks. Existing live IDs and legacy trash IDs form the lower bound. Failed publications can consume an ID; missing source files and process restarts never make reserved IDs reusable. Records are owner-only, bounded, sequential and hash chained (4096 reservations, 1024 bytes each); corrupt/foreign/symlink/hardlinked records fail closed. This is corruption protection, not protection against a trusted owner rolling back the entire log. Keep its backups with the site and never restore an obsolete prefix independently. Old public sources still require explicit IDs before public collection reads.

DELETE numeric posts/pages moves the saved source to native private trash after delete-specific role/owner/published-capability checks and a mandatory current If-Match. The access/content locks remain held through durable backup and removal; response status is trash and includes a private `moonpress_trash_id`. `force=false|0` is accepted; permanent deletion is refused. Native CLI trash-read/restore/purge remain owner tools with their existing version/acknowledgement guards. REST trash listings/restoration and force purge are not implemented. This removes source only; previously deployed static HTML remains until a separate rebuild/deployment.

`OPTIONS` on known routes returns implemented methods, endpoint arguments and a
subset article schema, with a matching `Allow` header. Numeric detail metadata is
independent of whether a private article exists. This is descriptive discovery,
not the complete WordPress JSON Schema; writes take string values and retain the
native limits and If-Match requirement. Unknown routes/parameters are refused.
OPTIONS does not enable cross-origin access or weaken the local operator editor.

HTML content intake (REST create/update and external WXR) supports ordered inline
`strong`/`b`, `em`/`i`, plain-text `code` and plain-label safe `a href` within
paragraphs/headings. A bounded native parser preserves mixed text order. Each
converted inline fragment must render to the expected escaped HTML exactly;
intraword emphasis, whitespace-edge emphasis, nested formatted link/code labels,
unsupported attributes/elements, unsafe destinations and ordinary comments are
refused instead of flattened. This is a strict representable subset of HTML.

Flat `ul`/`ol` lists with inline `li` children are accepted through the same
render-back validation. `ol start` accepts 1–999999999. Empty/nested lists,
block-bearing list items and arbitrary list/item attributes are refused.

The same intake accepts the validated static Gutenberg paragraph/heading/list/
list-item subset described in [migration](wordpress-migration.md). It returns
native generated HTML; it does not preserve Gutenberg editing metadata or run
block/plugin code.

## Universal public search

`GET`/`HEAD /wp-json/wp/v2/search` returns only `id`, escaped `title`, `url`,
`type=post` and `subtype=post|page`. It supports `context=view|embed`, `page`,
`per_page`, `search`, CSV `include`/`exclude`, `type=post`, and
`subtype=any|post|page|post,page`. Public visibility is applied before text filters,
counts and pagination, including for authenticated administrators. `_fields`
and OPTIONS work on search. Attachments, terms and custom types are refused.
Search uses the existing bounded literal AND-term matching over native title,
description and body, with deterministic date/ID ordering. It does not implement
WordPress SQL collation, relevance scoring or a site-wide static search interface.

Search serializes its five result fields directly without rendering article bodies.
Source parsing and literal matching still scan the bounded live snapshot.

## Named article classification

`moonpress_categories` and `moonpress_tags` are explicit native string-array
extensions on public/edit objects and create/update requests. Pass names directly:
no numeric term catalog or extra lookup is needed. Each array has at most 64
entries, each trimmed name 1–96 UTF-8 bytes without controls. Names sort and
deduplicate; an unchanged set preserves source bytes and ETag. Article ownership,
publication and If-Match guards still apply. These are not WordPress numeric
`categories`/`tags` fields, which remain unsupported rather than misinterpreted.

Existing post/page `slug` can be changed with the current If-Match. The native
flat-slug grammar and 230-byte limit apply; another live canonical slug or source
stem is a 409 conflict across posts/pages. The source filename, id and owner stay
unchanged. Repeating the current slug is byte-preserving. Links/redirects and
previously deployed HTML are not rewritten automatically; review and rebuild the
site after changing URLs.

## Native workflow routes

`/wp-json/moonpress/v1/posts/ID/history` (or `pages`) lists saved versions;
append the returned record `id` to read generated historical content. Generated
credentials and permission to edit the current article are required. Native
history must first be enabled with `history-enable`; it records distinct saved
preimages, not every browser keystroke. Lists support page/per_page and are
bounded to 4096 vault entries and 16 MiB selected source history. Record order is
deterministic by id. Raw Markdown/frontmatter and filesystem source names are
never returned. Only records with the same stable article id, owner and type are exposed. Reusing
a deleted filename cannot grant access to its earlier article history. Legacy
records without matching identity remain available only through owner CLI tools. OPTIONS is
metadata only and does not reveal whether an article/version exists.

POST an empty JSON object to `history/RECORD/restore` with the current article's
quoted If-Match to restore a version. Record id, owner and type must match the
current article; a reused filename never inherits its old history. Publication
capability and current edit permission are required, and restored slugs must not
conflict with another live source. Existing durable save/preimage/no-op guards
are reused; the current version remains in history for undo. No build/deployment
is triggered.

Native `media` lists public-folder asset metadata; append a percent-encoded flat
filename for detail. Fresh generated credentials with `upload_files` are required,
even for inventory reads; asset URLs remain public independently. Results contain
name/URL/size/digest and signature-matched raster MIME (otherwise octet-stream),
never file bytes or private source paths. Detail ETag is the asset digest. GET/HEAD
and page/per_page are supported; reads are bounded to 4096 entries, 8 MiB/file and
64 MiB aggregate. These are filename resources, not a numeric WordPress attachment
catalog, and header signatures are not full image decoding/transcoding.

POST native `media` with `{name,data}` uploads a new PNG/JPEG/GIF/WebP, where data
is canonical standard base64 and filename/signature must agree. Only this native
media POST namespace permits up to 8 MiB JSON (decoded bytes at most 6 MiB);
ordinary REST JSON remains 256 KiB. No SVG/script/document uploads are accepted.
Generated credentials with upload_files are required. The source asset folder is
prepared under the retained site root when absent; new publication is exclusive
and durable. Existing names return 409, never overwrite. The response is 201 with
asset digest, URL and Location. No attachment ownership catalog or image
transcoding is fabricated, and no build/deployment occurs.

POST `{data}` to native `media/NAME` replaces raster bytes at the same URL.
Replacement requires editor/administrator `edit_others_posts`, even for an asset
uploaded by the caller: no per-asset ownership catalog is implied. A quoted
current asset If-Match is mandatory (428/400/412 for missing/invalid/stale).
Existing durable staging, mode preservation and byte-identical no-op behavior
are reused; the site must be rebuilt/deployed separately. Names, signatures and
body bounds are identical to upload, with no arbitrary metadata overrides.

## Native comments

Authenticated POST to native `comments` takes a public article `post` id, plain
`content` (1–8192 UTF-8 bytes), and explicit public `author_name` (1–80 bytes).
The author id is bound to the fresh principal; caller ids, status, email/IP and
unknown fields are rejected. Only currently public/listed/due posts/pages accept
comments. Every new comment is held for approval, including moderator submissions.
Public labels are self-selected and do not prove account identity. HTML is escaped;
no shortcode, Markdown or plugin code is evaluated.

Comments are private owner-only, sequential hash-chained events; new ids survive
restart and are never reused. Limits: 1024 comments, 4096 events, 32 KiB/event,
16 MiB total. Corrupt/foreign/symlink/hardlinked/nonprivate records fail closed.
This detects corruption, not trusted-owner rollback; back up the whole log with
the site. No email addresses or IP addresses are collected.

GET/HEAD native `comments` lists only approved comments whose parent article is
currently public/listed/due; detail uses the numeric id. Counts and pagination are
after this visibility filter. Plain `post` id, page/per_page, and context=view are
supported. Anonymous context=edit is denied; authenticated edit reads return only
the caller's comments unless the caller can manage others' posts. Edit reads add
raw text/owner and per-comment ETag; public reads expose only the chosen public
label and escaped rendered content. Explicit bad credentials never fall back to
anonymous access. This API does not yet render comments into static article HTML.

Editors/administrators with `moderate_comments` can POST `status=approved|hold|spam`
to `comments/ID`, with its current edit-read If-Match. Missing/invalid/stale tags
return 428/400/412. Status changes append a private immutable event; same status
is a no-op with the same ETag. Body, parent and author identity cannot be changed
by moderation. Approval still never bypasses current parent-article visibility.

Moderator DELETE `comments/ID` with current If-Match moves a comment to trash;
no request body or force purge is accepted. Repeating trash is a version-bound
no-op. POST status=hold restores it for review, never directly to approved/spam;
a separate approval is required before public display. Immutable event history
and ids are retained, including across restart. Physical comment purge and
anonymous submissions are not implemented.

Native GET/HEAD `settings` is limited to fresh `manage_options` administrators.
It returns validated native site settings, existence and source revision, with a
quoted settings ETag (`"absent"` for no file). Reads create no file and never
return raw file paths. Unknown query parameters are refused. Public API URLs now
read current validated site configuration per request, so an operator settings
change takes effect without restarting this development listener.

Comment event/byte capacity is an explicit 409 `moonpress_comment_storage_full`,
not a storage failure. No extra event is written when full; reads and exact
status no-ops remain available. Physical I/O or integrity failures still fail
closed with a generic error.

Site settings can also be updated by an administrator with `POST /wp-json/moonpress/v1/settings`, a single `settings` object and the current quoted `If-Match` revision (`"absent"` when missing). The same strict native site configuration validator and durable CLI save machinery apply. Missing/stale guards return 428/412; a semantic no-op retains the exact existing bytes and version. Existing staging files are retained for inspection. New base URLs take effect on the next request without restarting the listener. This updates source configuration; publication remains a separate operation.

### Conditional native reads

Successful GET/HEAD responses without a source-version ETag receive a SHA-256 ETag of the exact projected JSON bytes, including their trailing newline. `If-None-Match` accepts `*`, a quoted lowercase SHA-256 tag, weak tags, or a comma-separated list (at most 32 tags / 4096 characters). Matching representations return 304 with no body and no Content-Length. Malformed conditions on these successful reads return 400. Authentication, visibility and `_fields` projection run before comparison; errors never become 304.

Existing edit, settings, media detail and historical detail source ETags keep their write-guard meaning and ignore If-None-Match. Mutations also ignore this read condition and still require their documented If-Match guards. Responses retain `Cache-Control: no-store`; explicit conditional requests save response bytes, but do not skip authorization, storage validation or snapshot computation. This is not a claim of increased authoring API capacity.

Native `GET/HEAD categories` lists exact native names and public, listed, due post counts. Categories belonging only to drafts, unlisted articles, pages or future publications are excluded. It supports bounded page/per_page and field projection. Names are not invented WordPress numeric term IDs. Explicit bad credentials never fall back to anonymous reads.

Native `tags` provides the same exact-name inventory and public post-count behavior for native tags.

Taxonomy inventories accept case-insensitive `search` (at most 256 UTF-8 bytes, no controls) and exact `name` (native term bounds). Filters apply before totals and pagination.

Taxonomy `orderby=name|count` and `order=asc|desc` apply before pagination. Native string ordering provides deterministic count ties. Invalid ordering is refused.

Post/page collections accept single exact native `moonpress_category` and `moonpress_tag` names, combined with AND. The native 96-byte term bounds apply. Both public and authorized edit collection filters run after their visibility/ownership gates and before totals.

Media inventory accepts bounded, case-insensitive filename `search` before totals and pagination. Searching does not bypass whole-snapshot file/byte limits or upload_files authorization. Detail routes reject inventory filters.

Media inventory accepts `media_type=image|file` and exact supported `mime_type`. Both depend on the file signature matching its supported raster extension; an invalid PNG is classified as application/octet-stream. Combined filters use AND.

Media `orderby=name|bytes` and `order=asc|desc` sort selected files before pagination, with deterministic filename ties. Size is the actual opened file length.

Media `digest` accepts a lowercase SHA-256 content digest to find existing identical assets before another upload. It combines with other filters, retains authorization, and does not create or delete files.

Comment inventory `search` matches bounded case-insensitive content or public author label after visibility/ownership filtering and before totals. Hidden matches never affect public counts.

Comment inventory `orderby=id|date` and `order=asc|desc` apply before pagination. Date ties use the immutable comment ID.

Comment inventory `include`/`exclude` accept at most 100 distinct positive IDs. Exclusion wins; selection never bypasses visibility or ownership. Empty lists retain the existing all-IDs filter convention.

`GET/HEAD comments/summary` requires fresh moderate_comments authority and returns hold/approved/spam/trash counts plus comment/event/byte usage and limits. It returns no text, identities or physical paths and creates no storage on empty reads.

HTML intake accepts attribute-free del/s as native strikethrough only when exact native inline rendering preserves its text and nesting. Unsupported attributes and lossy delimiter boundaries are refused.

HTML intake accepts plain rectangular tables: one th header row, optional thead/tbody sections, and matching td body rows. At most 32 columns and 1,000 body rows; supported inline cells round-trip through native Markdown. Header scope=col is allowed. Spans, styling, captions, ragged rows and nested tables are explicitly refused. Actual WordPress core-export fixtures cover both tables and strikethrough.

Native settings accept boolean `comments` for opt-in approved static article discussion. The operator interface exposes versioned moderation and display settings; [comment publication and incremental guarantees](site-settings.md#approved-comments-in-article-pages). Publishing still requires a build and deployment.

Filter REST articles after ISO8601 timestamps, with exclusive UTC boundaries and numeric offsets.

Filter REST articles before ISO8601 timestamps; combine before and after before counts and pagination.

Restrict REST search with search_columns=post_title,post_content,post_excerpt; empty selection searches all supported columns.

Support REST orderby=author with deterministic ID tie breaks and normal order direction.

Support REST orderby=include_slugs to preserve the requested slug sequence regardless of order direction.

Accept bounded REST bracket arrays: key[]=value or contiguous key[0]=value; reject mixed scalar forms and sparse or repeated indices.

Support public REST context=embed with id/date/slug/type/link/title/excerpt/author; content and raw fields stay excluded.

Support REST _envelope=1: HTTP 200 wraps body/status/headers, including errors, filtered bodies and pagination metadata.

Support guarded REST article PUT and PATCH updates through the existing permission, revision, JSON and durable write pipeline.

Expose /wp-json/wp/v2 and its trailing-slash alias as a read-only namespace index containing the implemented wp/v2 routes.

ISO8601 date bounds accept second-precision timestamps, with `Z`, a numeric
`+HH:MM`/`-HH:MM` offset, or no zone (native UTC). Fractional seconds and
noncanonical dates are rejected. Modified dates are not available. Search still
uses the documented bounded native term matcher; WordPress quoted phrases,
negative terms, SQL wildcard/collation rules and relevance ranking are not
claimed. Bracket arrays are a bounded subset: request-order contiguous indices
or append notation, without nested arrays or mixing scalar and array forms.
The envelope keeps numeric pagination values and applies field projection to
the body before wrapping; it also wraps credential denials after target parsing.

Expose REST /wp/v2/types for native post/page collections, including keyed per-item field projection; omit unsupported runtime metadata.

Expose REST /wp/v2/types/post and /wp/v2/types/page with collection/detail parity and read-only schemas.

Expose authorized REST type edit metadata only for editable types; supports/capability mappings never appear in public context.

Expose REST /wp/v2/statuses with public-only anonymous discovery and capability-scoped draft/future/trash metadata.

Expose REST individual implemented statuses; nonpublic status details require an editing capability and unsupported states remain absent.

Add REST article _links for implemented self/collection/about resources in public, edit and embed views; never advertise unsupported author/media endpoints.

Emit bounded REST collection prev/next Link headers while retaining query filters, field selection and envelope metadata.

Accept one trailing slash on valid REST post/page details through the shared read/update/delete parser; reject extra path segments.

Import Gutenberg core/table wrappers into native header/body tables, validating fixed-layout metadata; captions, headerless tables and arbitrary styling remain unsupported.

Preserve uniform HTML/Gutenberg table column alignment for left/center/right; reject conflicting styles, mixed per-cell alignment and unsupported attributes.

Metadata collections are keyed objects. `_fields` selects fields within each
item. Type `supports`, `capabilities` and `viewable` are edit-only; embed omits
description. Only native post/page types and implemented publication statuses
are advertised. WordPress custom types, pending/private/password states, PHP
runtime capabilities, hierarchy and full editing support are not implemented.
Article `_links` currently resolves self, collection and type information.
Collection `Link` headers preserve filters and expose previous/next pages; the
same pagination metadata is available inside `_envelope` responses.

As in WordPress, the individual public `publish` status exposes its static edit-context flags to anonymous readers; edit-context collection discovery and nonpublic state details still require editing capability. This returns no article or user data.

`supports.editor=true` advertises native article body editing only. WordPress
7.1 may return editor support as an options array containing `notes`; those
collaborative editor notes are not implemented or advertised. The core oracle
compares editor availability for that version-specific extension and exact
values/types for the remaining represented metadata.

Accept string or strict {raw:string} titles in native REST create/update; unsupported object fields are rejected.

Accept raw content objects through the same conservative HTML intake and guarded native REST write pipeline.

Accept raw excerpt objects while retaining the native plain-text excerpt contract and strict field validation.

Allow legacy author ID 0 in bounded REST author and author_exclude filters; article include/exclude IDs remain positive.

Allow active author assignment on REST creation; assigning another principal requires edit_others_posts/pages under the same access/content locks.

Allow guarded REST author reassignment with active-target validation and edit-others capability; ownership takes effect immediately.

Accept date as a native UTC creation alias for date_gmt; both supplied values must agree and retain second-precision validation.

Accept guarded REST date updates through native UTC date_gmt validation without granting publication capability.

Expose read-only public user profiles containing id/name/slug only for active principals with currently public native articles.

Expose read-only visible author details at /wp/v2/users/ID while keeping users/me private identity behavior separate.

Filter public users by bounded include/exclude identities after publication/activity visibility and before result counts.

Search visible native user labels and select bounded slugs; hidden or inactive principals never affect results or counts.

Order visible public users by id/name/slug and paginate after visibility/filtering with counts and navigable Link headers.

Link positive article author identities to native public user resources; revoked or nonpublic author profiles remain unavailable.

Select native comments across bounded article ID arrays while retaining public-parent visibility before filtering and pagination.

Filter visible native comments by author and author_exclude identity arrays without widening approval or ownership scope.

Filter visible native comments with exclusive ISO8601 after/before timestamps using the same bounded UTC/offset parser as articles.
