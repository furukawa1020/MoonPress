# WordPress capability coverage

Status after the October 2026 authoring batch. This is a capability inventory,
not a claim of WordPress compatibility or complete replacement. The reference is
[WordPress core features](https://wordpress.org/about/features/), with
[revisions](https://wordpress.org/documentation/article/revisions/) and
[roles/capabilities](https://wordpress.org/documentation/article/roles-and-capabilities/).
Plugin extensions are an open-ended ecosystem, not a finite core checklist.

| Capability | MoonPress status and limits |
| --- | --- |
| Posts / fixed pages | Native metadata, browser type form and inventory filter; flat source/output names |
| Drafts / ready / unlisted | Supported; unlisted is public and is not access control |
| Scheduled publication | Strict UTC `publish_at`, guarded CLI/browser edits and production exclusion; due-time rebuild/deployment requires hosting automation |
| Revisions / rollback | Explicit opt-in, immutable distinct-version preimages, manual checkpoints, browser/CLI diff and current-version-bound restore; not every save event |
| Trash / restore / purge | Private durable records, reviewed source removal, restore to vacant original name as mode 0600, individual acknowledged purge; no timed automatic purge |
| Categories / tags | Separate flat metadata, escaped indexes/archives, pagination; category hierarchy missing |
| Rich editing | Structured fields and documented Markdown subset, escaped preview; validated static paragraph/heading/list/quote/code/separator/image/table/strikethrough intake, Gutenberg header/body table wrappers and uniform column alignment; no Gutenberg editor or general HTML authoring |
| Autosave | Missing; interrupted native staging can be inspected/rescued, but unsaved browser typing is not autosaved |
| Media | Import/list/replace/preview, reference inspection and guarded removal; crop/rotate, responsive variants and attachment metadata missing |
| Themes / menus | Trusted static HTML/CSS layouts, named layouts, starter navigation; no WordPress PHP theme or block-theme compatibility |
| Permalinks / redirects | Flat slugs, reviewed local redirects, reference validation; no arbitrary nested permalink routing |
| Feeds / discovery | RSS, sitemap, tag/category archives, table of contents; public post/page REST search; no static search UI or relevance index |
| Languages | Automatic Japanese/English administration language with manual override; article translation is not automatic |
| User accounts / roles | Native private principals, five fixed roles and implemented-capability decisions, generated revocable credentials; [access foundation](native-access.md). REST creation/edits/trash enforce ownership/role; local operator editor is still not a multiuser interface |
| Private / password posts | Missing; never treat listed=false as private |
| Comments / moderation | Native authenticated pending creation, public approved reads, scoped edit views, guarded approval/hold/spam/trash and hold-only restore; optional approved comment display on public article pages with per-article incremental dependencies |
| REST / XML-RPC / application passwords | [Native REST subset](native-rest.md): public posts/pages, selected filters/fields, users/me, authorized edit collections, guarded create/update/trash, OPTIONS and universal search; native history/media/comment/settings workflows and conditional representation reads. Broad REST/query/schema compatibility, WordPress password import and XML-RPC remain missing |
| Multisite / network administration | Missing |
| Plugins / hooks / custom post types | Missing; WordPress plugins cannot run in the native runtime |
| Import / export | Verified static-site ZIP plus WXR export and reviewed private-draft intake; documented subset with explicit refusals |
| Deployment / updates | Native release candidates and configured static hosting; a local build is not a deployment |

Next implementation priorities include full attachment metadata, threaded comment replies and notifications,
private/password visibility and broader route/schema/block coverage. These are
remaining work, not hidden behind placeholder UI.

## Measurement contract

Use deterministic synthetic paragraphs and stable IDs for 10/100/1000 articles.
Both renderers must return the same heading and paragraph text, verified from
actual responses. Record corpus and executable SHA-256, exact source revision,
WordPress/PHP/database/compiler versions, runner CPU/OS and raw samples.

Measure native clean/no-op/one-source-edit generation and peak RSS separately.
WordPress publishes dynamically, so its startup/import time is not a comparable
static build. HTTP comparisons use the same PHP development server executable
for WordPress dynamic pages, cached WordPress HTML and MoonPress static HTML;
rotate serial warm samples and show median/p95 and response bytes. Distinguish
full response from first-byte time. No CDN, compression, concurrent load, cold
OS caches, production-server throughput or whole-product speed claim follows
from this small local benchmark. PHP process RSS is a snapshot, not per-request
allocation, and excludes the database's memory unless separately reported.

Security and load acceptance: [security-and-capacity.md](security-and-capacity.md).

Scheduled publication is implemented with strict UTC `publish_at`, guarded editing and production exclusion; see [scheduled-publication.md](scheduled-publication.md). Automatic rebuild/deployment at the due instant still requires hosting automation.

WXR content interchange now includes bounded native export, reviewed private-draft intake and actual WordPress importer/core-export oracle tests; [migration scope and unsupported cases](wordpress-migration.md). This is not arbitrary WordPress theme/plugin/runtime compatibility.

## Native workflow expansion (20 changes, October 2026)

MoonBit native workflows now cover conservative HTML hard breaks, quotes, code/preformatted content, separators, images and static matching block wrappers; named categories/tags; guarded slug changes; authorized history reads/restores; bounded raster media inventory/upload/replacement; authenticated pending comments with scoped reads, moderation, trash and hold-only restoration; administrator settings reads/updates; and representation-aware conditional reads. Each has native HTTP regressions, with actual WordPress fixtures used for applicable interchange and capability behavior.

Comments now include native operator forms and optional approved rendering on public article pages. Raster uploads check supported signatures rather than decoding whole images. No complete WordPress feature parity, plugin compatibility, production API scaling or universal security superiority is asserted by this batch. The production serving benchmark compares generated output independently from this loopback authoring API.

## Native operator and discovery expansion (20 further changes)

Native category and tag inventories now support public counts, exact-name lookup, bounded search and count/name ordering. Article collections accept exact native term filters, including discoverable OPTIONS arguments. Authorized media inventory adds filename search, verified MIME/type filters, size/name ordering and digest lookup for existing identical files.

Comments gain visibility-scoped search, stable date/ID ordering, include/exclude selection and private moderator counts/capacity inspection. The local operator can browse, inspect, moderate, trash and restore with CSRF/version guards and without JavaScript. Tables use keyboard-focusable scroll regions, and language switches retain inspection context. Conservative HTML strikethrough and rectangular table interchange are covered by native and actual WordPress export fixtures. Approved comment display is opt-in and preserves clean/incremental parity.

Remaining comment features include threaded replies, anonymous posting, notifications and a public submission interface. The production serving benchmark remains distinct from authoring API capacity.

Native REST discovery now exposes post/page types and capability-scoped
publication statuses, resource links and pagination links. Actual core
comparisons exercise anonymous, subscriber, author and administrator metadata
across view/embed/edit. These report the implemented subset and do not claim a
Gutenberg editor, general block-theme runtime or arbitrary PHP plugin execution.

## Further authoring and public REST expansion (20 changes)

Native authoring accepts bounded raw title/content/excerpt objects, active-author
assignment/reassignment with edit-others and version checks, legacy author-zero
filters and a UTC date alias. Public author profiles, filters, lexical ordering,
pagination and article author links are available without private account fields.
Comments gain multi-article/author/date filters, native embed projection and a
read-only WordPress-shaped approved-public adapter with accurate discovery.
Actual core fixtures compare raw authoring/date cases, lexical title ordering,
public native author identity and view/embed comment fields. This does not add
PHP themes/plugins, Gutenberg runtime editing, private posts or threaded replies.
