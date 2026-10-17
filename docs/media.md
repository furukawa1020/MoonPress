# Media and public assets

Put supported flat files in `public/` inside the site. They are copied byte for
byte to the output root. `public/` is optional; directories, symlinks, special
files and unsupported extensions are rejected by both inventory and compiler.

```sh
moonpress media my-site
moonpress media my-site --json
```

The native media report contains source name, encoded output URL, byte length,
SHA-256 and image classification. Classification uses filename extensions, not
file-content validation. Inventory does not check article references, output
collisions or hosting; use `check` for the whole site.

In local administration, open **Media** and copy a Markdown snippet into an
article. Replace `Describe image` with meaningful alternative text or `Download`
with a descriptive link label. URLs encode spaces, Unicode and punctuation.
Relative snippets assume the compiler's flat output routes. Supported raster images have lazy thumbnails and an Open image link. These show
saved source bytes without rebuilding the site. No script or clipboard automation
is used. Inventory is
read-only; the import operation below writes assets. Browser upload is described below; reference-aware deletion remains separate work.

## Importing local files

For the CLI, create a real `public/` directory in your site first, then run:

```sh
mkdir my-site/public
moonpress import my-site /absolute/path/photo.png photo.png
moonpress import my-site /absolute/path/attachment.pdf attachment.pdf --json
```

The local administration Media screen also accepts a source file path on the
same machine as MoonPress and a destination filename. This is a local copy, not
a browser multipart upload. Failed form submissions retain those paths for
correction; a successful import provides the Markdown snippet.

Import reads binary bytes, requires regular source files and a real public
directory, and uses a shared directory lock plus exclusive target creation.
Existing targets (including symlinks) are never replaced. Destination names must
be flat supported assets, cannot begin with a dot, and reserve `style.css`,
`sitemap.xml` and `rss.xml` for compiler outputs. Other output collisions and
article references are checked by the compiler, not import. Classification does
not prove the content matches an extension.

Caught write/flush/close failures remove the owned partial file; failed cleanup
reports its path. A process crash can leave a partial target, which later imports
refuse to overwrite. Inspect it before manually removing it. Source files are
not changed, source permissions are not copied, and import does not build or
deploy. Uncooperative external file replacement during an import is outside the
cooperative locking guarantee; use a trusted local project.


## Browser file selection

On a fresh site, open Media and click **Prepare media storage** first. This
explicit action creates only the public directory; opening the screen writes
nothing. Existing real directories are kept, and files/symlinks/special entries
are refused. Then use **Upload a file**, enter a supported destination name
and select one file. This sends binary multipart data without JavaScript. The
complete request, including form fields and framing, must fit within **8 MiB**;
choose a file slightly smaller than that limit. The existing real `public/`
directory requirement and exclusive creation protections apply. Success provides
a Markdown snippet. On a save error the destination is retained, but the browser
requires selecting the file again before retrying. No uploaded bytes are retained
on the error page.

The original browser filename and supplied MIME type are not used as a path or
as content verification; the explicit destination controls extension checks.
Upload does not inspect or sanitize file contents. The multipart parser accepts
three fields (`token`, `name`, `file`), standard quoted dispositions and an ASCII
alphanumeric/hyphen/underscore boundary of 1–70 characters, optionally quoted.
Duplicate/unknown fields, nested multipart, part transfer encodings, preambles
and epilogues are rejected. Standard HTML forms and curl multipart requests use
this supported subset. Ordinary editor forms keep their 256 KiB limit.

## Article reference inspection

The native `inspect_media_references` service scans supported Markdown links and
images with the same parser and local URL normalization as the compiler. Each
asset lists referring articles once, in source order, including drafts and
unlisted posts. Code spans, fenced code, escaped syntax, and external URLs do not
count. Site base paths, percent escapes, query strings and fragments follow the
compiler rules. Invalid metadata, unreadable entries and invalid destinations
produce explicit per-source diagnostics; invalid site configuration or asset
storage rejects the report. This is a read-only observation, not a snapshot
locked against external editors. Templates and CSS are outside its scope, and
an empty list is never proof that an asset is safe to delete.

Run `moonpress media-refs <site-directory> [--json]` to inspect references.
The schema-1 report contains `assets` (each with `item` and `posts`), `problems`,
and `scope`. Exit 0 means the report was produced, even if `problems` is nonempty;
consumers must inspect diagnostics. Site-level configuration/storage failures
exit 1 with empty stdout; invalid arguments exit 2. `--include-drafts` is not an
option because reference inspection always covers drafts and unlisted articles.

## Native raster preview snapshots

`read_media_preview(input, name, expected~)` returns the exact bytes, MIME and
MediaItem for PNG/JPEG/GIF/WebP. The optional expected SHA-256 refuses stale
snapshots. The retained no-follow public directory reader rejects symlinks and
special files and refuses files larger than 8 MiB before allocating the buffer.
Filename and magic bytes must agree; this is not a full decoder or an image
sanitizer, and it makes no decoded-pixel-size guarantee. SVG/AVIF/ICO and other
assets remain supported by the compiler but are outside this preview API.
No source, generated output or deployment is changed.

## Images in local administration

Media and Replace media show bounded thumbnails for PNG/JPEG/GIF/WebP up to
8 MiB. The image URL includes the saved SHA-256: stale URLs refuse instead of
silently displaying replacement bytes. Reload the Media/Replace page after
changes to get a new URL. Unsupported formats/sizes retain their snippets and
replacement controls. Invalid or undecodable image data may show a broken-image
placeholder; signature checks are not full decoding.

The image route is a read-only, same-origin GET with strict name/version fields,
Host/Origin checks, no-store/nosniff headers and sandboxed content policy. Source
images are not served on the generated-site preview origin. Viewing them does
not rebuild, publish, or imply they appear in the current generated output.
