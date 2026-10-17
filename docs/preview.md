# View a generated site locally

Build first, then run `moonpress preview OUTPUT PORT`, for example:

```sh
moonpress build my-site preview --include-drafts
moonpress preview preview 8081
```

Open `http://127.0.0.1:8081/`. CSS, images and relative page links work over HTTP.
Keep the terminal open; Ctrl-C stops the server. Rebuild saved sources explicitly,
then reload the browser. Private drafts may be included: do not expose this
loopback server through a tunnel/proxy or publish the preview directory.

The server is read-only and serves only intact manifest-tracked flat output files.
Edited files, symlinks, hidden state and untracked files are refused. Verified responses may be cached privately but must be revalidated before reuse;
errors are not stored. Project scripts, forms, embedded frames and external resource
loads are disabled by the preview content policy; this is not a hosting emulator.
Use a separate port from administration. No files are built or deployed by GET.

## From the editor

`moonpress admin my-site 8080` starts administration on port 8080 and the preview
on port 8081. Both bind only to 127.0.0.1 and stop with the same process. Choose
an unused pair of adjacent ports (admin range 1024–65534). Startup fails if either
is occupied; it does not silently reuse another service.

Choose **Build full preview files**, then **Open built preview** in the navigation.
The new tab contains generated site content only, including saved drafts. Editing
forms and tokens stay on the administration port. Before the first build the
preview reports unavailable; saving an article alone does not rebuild it.

GET and HEAD are supported on the preview origin. HEAD performs the same output
verification and returns the representation length without a response body.
The administration origin still accepts only its existing GET/POST routes.

Verified files include a SHA-256 ETag and `Cache-Control: private, no-cache`.
GET/HEAD `If-None-Match` supports strong/weak tag lists and `*`. Every request
rechecks the manifest and actual file digest before a bodyless 304; edited, missing
or unsafe output never bypasses verification. Errors remain `no-store`.
