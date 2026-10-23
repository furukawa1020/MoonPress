# Local browser administration

Build MoonPress, initialize a site if needed, then run:

```sh
moonpress init my-site
moonpress admin my-site 8080
```

Open **http://127.0.0.1:8080/** on the same computer. Keep the terminal open;
Ctrl-C stops the server. Ports 1024–65535 are accepted. If a port is already in
use, choose another one. Use the printed numeric address, not `localhost`.
The server does not open a browser automatically and has no `--json` mode.

## Start here

Open **http://127.0.0.1:8080/rooms** for an ordered guide with current saved
ready/draft/problem counts. The guide does not compile or mutate files on GET.
Use its preview/review/build forms when ready; all use the existing protected
native compiler operations. Counts are metadata observations, not validation
or hosting status. Broken readable sources remain repairable through Posts.

## Available workflow

1. **Posts:** see article titles, source filenames, draft/ready state and unlisted
   markers. Click a title to edit it.
2. **New draft:** enter a title and file stem. This creates a Markdown source with
   `draft:true`, never overwriting an existing file.
3. **Edit:** use title, description, date, tag and body fields, or open the
   advanced source editor. Saving validates metadata with the compiler parser.
   **Preview body without saving** renders the current Markdown and keeps all
   fields available for continued editing.
4. **Status:** set the saved article to draft or ready for normal builds. Save
   editor changes first: status buttons operate on the saved version, not the
   text currently in the other form. These actions do not deploy anything.
5. **Validate saved site:** from Posts, check a normal build or include drafts.
   This uses the compiler checks for saved metadata, layouts, local links and
   routes. It reports page/output counts or the compiler diagnostic, without
   writing files. It does not check existing output integrity or hosting.
6. **Build full preview files:** compile saved sources, including drafts, into
   `.moonpress-preview` inside the site. The result includes layouts and assets.
   Open generated HTML with your local file browser. It is not deployed.

7. **Inspect production changes:** inspect planned writes, keeps, deletions and
   draft skips without creating output. This also checks existing output integrity.
8. **Build production files:** compile saved ready articles into `.moonpress-build`
   inside the site, excluding drafts. The result is local output, not a deployment.

Successful operations show a confirmation and a link to continue editing. There
is no JavaScript, auto-save, visual/WYSIWYG editor or client-side refresh. Browser
forms may normalize line endings to CRLF when saving source. If an older editor
tries to save after the source changed, saving is refused. The error screen shows
your submitted fields, or a read-only copy of raw source, before reloading.
This is not an automatic merge. Network failures do not provide this recovery
screen; keep a local copy of long edits.

The body preview does not load the site theme or images, activate links, validate
metadata, or check site links. It never refreshes the edit version: previewing an
old form does not allow overwriting newer source. Full preview files can be
built from Posts or the CLI. Use a normal CLI build for production, then publish
that output through your hosting workflow:

```sh
moonpress check my-site --include-drafts
moonpress build my-site preview --include-drafts
# Open preview/index.html locally.
moonpress check my-site
moonpress build my-site dist
# Publish dist through your hosting workflow separately.
```

The administration UI does not serve preview/output/source files as static files,
run shell commands, create hosting credentials or install a
workflow. The shared authoring services and their source-save limits are described
in [getting started](getting-started.md). This first UI slice does not complete
[the WordPress-style authoring roadmap](../../../issues/111).

## Local-only boundary

This experimental single-user server binds only IPv4 loopback (127.0.0.1).
It is for a trusted local machine and trusted project. It is **not** an authenticated
multi-user CMS. Any local process/user able to reach the port can access it. Do
not expose it through a proxy, port forwarding, tunnel or remote hosting.

All requests require the exact loopback Host. POST additionally requires the
same-origin Origin, URL-encoded form content type and an unpredictable 256-bit
per-process form token. Tokens are hidden form fields, not URL parameters, and
restart invalidates open forms. Cross-site fetch metadata, duplicate headers,
transfer/content encodings and ambiguous framing are rejected. GET never mutates
source. Responses escape untrusted text, disable caching/framing and apply a
Content Security Policy that disables scripts and external resources.

The minimal HTTP/1.1 implementation accepts GET and fixed-length POST only,
one request per connection. Headers are limited to 16 KiB and encoded request
bodies to 256 KiB (8 MiB for multipart upload requests). Reads have a total 5-second deadline; responses have a separate
5-second send deadline. Incomplete/malformed requests fail without a source
operation. The server processes one connection at a time; it is not designed for
untrusted traffic or concurrent teams. Request limits are not a limit on all local
file sizes or CPU work. Failed bind/accept operations terminate with an error;
ordinary request errors leave the server running.

There is no persisted browser session or remote authentication. Filesystem trust,
cooperative locking, source staging and external-editor race limitations remain
those of the CLI. A successful save means the source operation succeeded, not
that a build or deployment succeeded.

### Structured article editing

The article editor provides title, description, date, tags and Markdown body
fields. A blank title keeps automatic title inference; a blank date removes the
date. Enter tags one per line (commas are part of a tag); blank lines are ignored
and duplicates removed. Dates use valid `YYYY-MM-DD` calendar dates. Draft state,
listing, slug and layout are preserved. Changed articles serialize JSON
frontmatter and normalize body line endings; unchanged fields preserve source
bytes. The advanced source editor remains available, including for repairing
invalid frontmatter. Use one editor at a time.

Both editors use the same version-checked atomic save service. Validation or
version errors retain submitted input. On a version conflict, copy your input
and reload before merging your edits manually. Retrying an old form cannot
force an overwrite. Saving does not build or deploy the site.

### Repairing individual sources

An invalid article no longer hides the rest of the Posts screen. The screen
shows a separate diagnostics list and offers **Repair source** for regular,
safely named UTF-8 Markdown files. Symlinks, directories, special files and
invalid UTF-8 appear as problems without repair links; fix these with local
filesystem tools. Missing or invalid site/content directories still fail the
whole request. Inventory is read-only; compiler validation and the CLI `posts`
command remain strict. Listing valid posts does not mean the site can build.

### Finding articles

Search matches title, source filename or tags using a case-insensitive substring
(after trimming query whitespace). It does not search article bodies. Combine
search with All, Drafts, Ready for build, or Unlisted; an unlisted article can
also be a draft. Ready describes build eligibility, not deployment.

Results retain deterministic filename order and show 20 articles per page.
Previous/Next links retain the query and state. Search submits a normal GET form,
resets to page 1, and can be bookmarked; Clear filters returns to all posts.
Counts describe valid articles only. Source diagnostics remain visible on every
page and through every filter, even when no articles match. Invalid query fields,
duplicate fields and out-of-range pages are rejected without changing sources.


### Full preview output protection

The preview action always includes drafts and writes only to
`<site>/.moonpress-preview`; it cannot select an arbitrary output path. Keep this
preview directory private. Publishing it would publish drafts. It uses the same
incremental compiler, ownership manifest, locking and publication protections as
the CLI. Unknown files, edited outputs and symlink directories are refused;
errors are reported without silently replacing or deleting them. If interrupted,
use the documented CLI recovery flow for this output directory.

The admin server does not serve generated project HTML on its origin or start a
second preview server. Open the files locally; theme links configured for a
hosted base URL still point to that URL. Unsaved form edits are not included.
The preview directory is retained across server restarts for incremental builds.

### Media inventory

Open **Media** to see public asset byte counts and digests, and copy an escaped
Markdown image/link snippet into an article. See [media](media.md) for naming,
classification and validation limits. The inventory never serves these files.


The Media screen also accepts browser file selection with a multipart upload.
See [media](media.md) for its size limit, destination naming and retry behavior.

The Media screen lists referring articles beside each asset, including drafts
and unlisted posts. Article titles link to the editor. Source diagnostics remain
visible; repair eligible sources before relying on the scan. The report covers
supported article Markdown, not templates or CSS, and cannot certify deletion
safety. It remains read-only and does not serve images on the admin origin.

Media search uses a case-insensitive filename substring and an All/Images/
Attachments filter. Classification still uses filename extensions. Normal GET
forms retain and escape the query; Clear filters restores the inventory.
Reference diagnostics remain visible even when no assets match, or storage has
not been prepared. Invalid, unknown or duplicate query fields are rejected.

### Production output

**Build production files** always uses `<site>/.moonpress-build`, independently
of draft-inclusive previews and other CLI output directories. It shares the
compiler's locking, incremental dependencies, owned manifest and publication
recovery protections. Foreign entries, symlinks and manually edited generated
files are refused. The form accepts only its token and review ID from inspection; clients cannot
select an arbitrary path or enable drafts. Missing or stale IDs fail before
publication. On failure, inspect again using the recovery form. Unsaved form text is excluded.

The result reports local page/write/unchanged/delete counts. No hosting request
is made and no deployment status is inferred. Use the documented deployment
workflow for actual hosting. Generated project HTML is not served on the admin
origin. If publication is interrupted, use the CLI recovery procedure for this
specific output directory.

**Inspect production changes** uses the same typed review operation as CLI
`review`, with the same fixed production destination and draft exclusion. It
shows planned actions, paths, reasons and counts without creating or changing
source/output files, even on the first run. Existing output ownership and edits
are validated. The report is not a reserved transaction: sources or output may
change between inspection and build. Building compares the recomputed review ID
under the exclusive output lock and refuses a different plan before writing.

### Duplicate an article

The editor has a separate **Duplicate saved article** form. It creates a new
draft from saved source and leaves the original unchanged. Choose a new filename
stem and title; old URL/date are cleared, while body and other article settings
are retained. See [duplication](duplication.md) for version checks and limits.

### Article URL, listing and layout

The editor's **Article URL and layout** form controls output stem, article-list
inclusion and named layout without changing the body or draft state. It uses the
same source-version protection as other saves. No-op submissions preserve source
bytes and timestamps. See [article settings](article-settings.md) for defaults,
validation limits and unlisted-page visibility. URL changes create no redirects.

Media results show 20 assets per page in deterministic filename order. Counts
include matching and total assets. Previous/Next links preserve filename search
and type filters; submitting a new search resets to page 1. Source diagnostics
and upload/import actions remain available on each page. Empty results have one
page; invalid or out-of-range page requests are rejected without changes.
Pagination limits displayed assets, not the underlying read-only reference scan.

## Inspect article references before changing its URL

The editor's **Inspect saved article references** link opens a read-only report
of incoming and outgoing authored links for that article's current output name,
including a configured slug. Choose **Ready articles only** or **Include saved
drafts**; ready unlisted pages remain included. Unsaved editor text is excluded.
The shared compiler validates the selected site scope before reporting. A broken
included source shows an explicit error and a return-to-editor link, never a
false empty result. Excluded drafts have a scope-switch notice.

An excluded draft notice is shown before compiling the ready-only graph, even
when the site has no ready articles. The notice explicitly does not validate a
graph; choose the draft-inclusive view to run validation and inspect references.

Rows identify the source, consuming output, kind, original URL and target/fragment.
Article sources link to the editor; templates/configuration remain plain text.
Project HTML and arbitrary reference URLs are never served or opened on the admin
origin. Counts describe deduplicated authored edges, not occurrence counts or
all rendered links. Generated navigation, CSS and external URLs are excluded;
zero incoming references does not certify deletion safety. See [reference
scope](references.md). Inspection never changes article/output files.

## Understand production changes

Inspect production changes uses the same typed native `DetailedBuildPlan` as
`moonpress plan`, under the same ownership validation and shared output lock.
It shows every added/changed/removed dependency per affected output, rather
than only the first rebuild reason. For example, editing an article and its
layout together reports both dependencies. Kept outputs remain in the summary;
excluded draft source rows have a separate list.

Each affected output says whether it is new, removed, changed in bytes,
recomputed with identical bytes or restored after going missing. Full observed
SHA-256 values are available in collapsed details. These are integrity/diff
observations, not signatures. Review writes no source/output files and does not
reserve an approved snapshot: Build production files revalidates current state
and requires its review ID to match. Only the inspection page has a build form;
a failed build offers another inspection, never an automatic approval.
CLI and HTML review use one native MoonBit planner, not a separate browser
implementation or JavaScript dependency model.

## All output references

The global **Output references** link opens a saved-site overview with twenty
outputs per page. It includes assets, archives, redirects and marker files as
well as articles. Counts distinguish incoming/outgoing edges, self references
and distinct other referring outputs. Click an output to inspect source
evidence; redirects link to their terminal target's inspection.

Ready-only and draft-inclusive links retain the selected output; switching to a
scope which excludes that output produces an explicit error with an overview
link. Pagination retains scope. Validation failures never produce a successful
zero-count report. A site with only drafts must use the inclusive scope.

All these GET requests are read-only. Source links point to the existing article
editor only when the source is a safe article filename; project HTML/assets are
not served on the administration origin. Counts exclude generated navigation,
CSS and external URLs and are not proof that deletion is safe. No output or
source files are removed or changed by this screen.

## Replace an existing image or attachment

On **Media**, choose **Replace this media at the same URL**. The detail screen
shows the saved byte version and a link to inspect references including drafts.
Select a replacement file and submit. Its local filename does not rename the
asset. The complete request must fit within 8 MiB, including form overhead.

The form carries the version shown when opened. A newer edit causes an error;
the failed form retains its old version and does not silently retry. Use
**Reload current media version**, review the asset, then select the file again.
Identical bytes are reported as unchanged. Existing create-only upload/import
still refuse occupied destinations.

Replacement changes the saved public asset only. Review the production build
plan before rebuilding; hosting deployment remains a separate step. Assets are
not displayed or served on the admin origin. Keep a backup for undo. See
[replacement guarantees and limits](media-replacement.md).

### Saved article integrity

Existing article reads and saves now retain a no-follow handle to the content
directory. Saves lock that same directory and verify closed staging bytes before
checking the target version again and replacing the article. Changed/unreadable
staging is retained for inspection; an occupied stage also blocks a no-op save.
If the directory is renamed during an edit, the operation remains in the original
directory rather than following a replacement path. This does not provide an
undo journal or protection against arbitrary entry/content changes after final
checks. Draft/ready and article settings edits use the shared post save service.

New draft creation, duplication and media import/upload also retain their
content/public directory handles. Destination existence checks, exclusive open
and caught-failure cleanup use that handle; duplicate source verification uses
the locked content directory. Initial media-directory preparation and site
initialization are separate operations, not a retained existing-directory edit.

### Keyboard and narrow-screen navigation

The first focusable link skips navigation and moves to the main content. Main
navigation has an accessible label, and visible focus outlines remain enabled.
Inventory tables keep their native table markup inside keyboard-focusable scroll
regions; use horizontal scrolling when columns exceed the viewport. Long names
wrap, and controls stay within their containing form. These changes have native
and HTTP regression coverage; actual browser, touch and assistive-technology
checks remain release gates rather than completed claims.

See [administration languages](languages.md) for automatic Japanese/English
selection and persistent browser overrides. Save before switching language.

The local operator navigation now includes Comments. The no-JavaScript inventory defaults to pending comments and offers status counts, bounded search and pagination. It escapes stored labels/text and never changes comment state on GET. This is the existing trusted loopback operator interface, separate from generated-credential multiuser REST.
