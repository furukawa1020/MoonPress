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
manage uploads, run shell commands, create hosting credentials or install a
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
bodies to 256 KiB. Reads have a total 5-second deadline; responses have a separate
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
