# Native WordPress REST read subset

`moonpress rest SITE PORT` starts a separate MoonBit-native listener at
`http://127.0.0.1:PORT/wp-json/`. It shares no editor session or mutation routes.
This is an explicitly limited read API, not full WordPress REST compatibility.
Reference schemas: [posts](https://developer.wordpress.org/rest-api/reference/posts/),
[pages](https://developer.wordpress.org/rest-api/reference/pages/),
[users](https://developer.wordpress.org/rest-api/reference/users/).

| Route | Current behavior |
| --- | --- |
| `/wp-json/` | Discovery declares the implemented read subset and omissions |
| `/wp-json/wp/v2/posts` | Public post list, default 10 items, date descending |
| `/wp-json/wp/v2/pages` | Public fixed-page list with the same filters |
| `/wp-json/wp/v2/posts/ID`, `/wp-json/wp/v2/pages/ID` | Public detail by saved positive ID |
| `/wp-json/wp/v2/users/me` | Generated Basic credentials required; current identity only |

GET and HEAD are supported. Collection parameters are `context=view`, `page`
(1–4096), `per_page` (1–100), one exact `slug`, `order=asc|desc`, and
`orderby=date|id`. Responses include `X-WP-Total` and `X-WP-TotalPages`.
Unknown/duplicate parameters are rejected. Detail accepts only `context=view`.
Trailing collection slashes are accepted. `_fields`, `_embed`, search, taxonomies,
includes/excludes, authentication cookies, OPTIONS/CORS, XML-RPC and all writes
are not implemented. No unknown parameters are silently treated as effective.

Post objects contain `id`, `date`, `date_gmt`, `slug`, `status`, `type`, `link`,
rendered `title`, rendered `content`/`excerpt` with `protected=false`, and
`author`. Titles and descriptions are escaped; content uses the native safe
Markdown subset. There is no raw source, filesystem filename or version digest.
Descriptions supply excerpts; automatic WordPress excerpt generation is absent.
Dates are native UTC publication schedule or date-at-midnight, falling back to
1970-01-01; arbitrary site timezones and actual modification timestamps are not
represented. Taxonomy numeric IDs, links/embeds, GUIDs, attachment data and
other WordPress fields are omitted rather than fabricated.

Draft, future and unlisted articles are excluded even with administrator
credentials. An unlisted article's standalone static URL remains public; this
API exclusion does not make it private. `context=edit` on posts/pages is refused.
For `users/me` only, `context=edit` additionally returns the caller's username,
role and implemented capability subset. User email/profile data is not stored.

## Saved identities

REST requires every currently public source to have a unique positive integer
`wp_id` in frontmatter (1–2147483647). Optional `author` is a nonnegative local
principal ID; 0 means legacy unassigned. Missing public IDs and duplicate IDs,
including a collision with a draft, fail the content response closed with a
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
There is no claim of constant memory independent of source size.

Native unit and live socket tests cover visibility, IDs, pagination, escaped
content, strict requests and live identity rotation/revocation. After timed
benchmarks, the disposable actual WordPress core REST oracle compares the
implemented IDs/date/slug/status/type/author fields and rendered text for the
same WXR fixture. This verifies a subset; it does not verify every WordPress
client, response field, filter or plugin.
