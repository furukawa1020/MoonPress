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
Edited files, symlinks, hidden state and untracked files are refused. Responses
are not cached. Project scripts, forms, embedded frames and external resource
loads are disabled by the preview content policy; this is not a hosting emulator.
Use a separate port from administration. No files are built or deployed by GET.
