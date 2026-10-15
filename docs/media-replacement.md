# Versioned media replacement

`read_media(site, name)` reads one existing regular file in `public/` and returns
its source name, encoded article URL, byte count, SHA-256 digest and extension
classification as a `MediaItem`. It reads binary bytes without decoding them and
writes nothing. It does not require valid articles or a successful site build.

Use an exact flat asset filename, for example `月 &a.PNG`, not a URL or source
path. Missing files, reserved compiler filenames, symlinks and special files are
rejected. Reading one item does not validate all other public files or the site.
Classification by extension does not validate an image or sanitize its content.
