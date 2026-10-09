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
Relative snippets assume the compiler's flat output routes. No script, image
viewer, clipboard automation or arbitrary asset server is used. Inventory is
read-only; the import operation below writes assets. Browser upload is described below; reference-aware deletion remains separate work.

## Importing local files

Create a real `public/` directory in your site first, then run:

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

On the Media screen, use **Upload a file**, enter a supported destination name
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
