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
| Rich editing | Structured fields and documented Markdown subset, escaped preview; no Gutenberg/block editor or general HTML authoring |
| Autosave | Missing; interrupted native staging can be inspected/rescued, but unsaved browser typing is not autosaved |
| Media | Import/list/replace/preview, reference inspection and guarded removal; crop/rotate, responsive variants and attachment metadata missing |
| Themes / menus | Trusted static HTML/CSS layouts, named layouts, starter navigation; no WordPress PHP theme or block-theme compatibility |
| Permalinks / redirects | Flat slugs, reviewed local redirects, reference validation; no arbitrary nested permalink routing |
| Feeds / discovery | RSS, sitemap, tag/category archives, table of contents; no public full-text search yet |
| Languages | Automatic Japanese/English administration language with manual override; article translation is not automatic |
| User accounts / roles | Missing; local single-operator loopback editor uses a session token, not a multiuser CMS |
| Private / password posts | Missing; never treat listed=false as private |
| Comments / moderation | Missing |
| REST / XML-RPC / application passwords | Missing; local form endpoints are not a public API compatibility layer |
| Multisite / network administration | Missing |
| Plugins / hooks / custom post types | Missing; WordPress plugins cannot run in the native runtime |
| Import / export | Verified static-site ZIP plus WXR export and reviewed private-draft intake; documented subset with explicit refusals |
| Deployment / updates | Native release candidates and configured static hosting; a local build is not a deployment |

Next implementation priorities are broader WXR content conversion,
public search, attachment metadata, then a designed multiuser
storage/authentication boundary before roles, comments and public APIs. These are
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
