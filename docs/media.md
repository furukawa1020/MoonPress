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
read-only; import/upload and reference-aware deletion are separate operations.
