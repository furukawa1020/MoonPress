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
3. **Edit:** edit the complete Markdown source, including JSON frontmatter, and
   save. Metadata is validated by the same parser used by the compiler.
4. **Status:** set the saved article to draft or ready for normal builds. Save
   editor changes first: status buttons operate on the saved version, not the
   text currently in the other form. These actions do not deploy anything.

Successful operations show a confirmation and a link to continue editing. There
is no JavaScript, auto-save, visual/WYSIWYG editor or client-side refresh. Browser
forms may normalize line endings to CRLF when saving source. If an older editor
tries to save after the source changed, saving is refused. The error screen shows
your submitted source in a read-only textarea so you can copy it before reloading.
This is not an automatic merge. Network failures do not provide this recovery
screen; keep a local copy of long edits.

Preview, full-site validation and deployment still use the CLI:

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
