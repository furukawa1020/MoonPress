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
read-only; the import operation below writes assets. Browser upload and
reference-aware deletion remain separate work.

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
