# Content model

Markdown may begin with JSON frontmatter. No YAML parser dependency is required.

```text
---
{"title":"A small compiler","description":"How it works","tags":["MoonBit","開発"]}
---
# Article

Body text.
```

Optional keys: `title` (nonempty string), `description` (string), `tags` (array
of nonempty strings). Unknown keys and wrong types are errors, not silently
ignored typos. Tags are trimmed, deduplicated and deterministically sorted.
The closing delimiter is a line containing `---`. CRLF is accepted. Metadata
errors include the source filename and the frontmatter starting line; JSON
syntax errors also include the parser's position inside the header.

Without frontmatter, title is the first H1 outside code fences, or the filename
stem. Metadata is removed before Markdown rendering.

Layout placeholders: `{{title}}`, `{{description}}`, `{{content}}`.
Title/description are escaped; content is generated HTML. Inserted values are
never expanded again, so text containing another placeholder remains literal.
Unknown template placeholders are preserved for forward compatibility.

## Collections

`articles.html` lists all source pages in deterministic filename order. Every
nonempty tag produces `tag-<UTF-8 bytes in hex>.html`. Tags may use Unicode and
are limited to 96 UTF-8 bytes so generated filenames fit POSIX limits. Links
percent-encode source filenames; title/description/tag text is HTML-escaped.

Body edits rebuild the article only. Title/description/tag edits rebuild the
article and affected collections. Removed tags delete their obsolete generated
pages. Membership changes and metadata are separate dependencies. Source pages
whose output collides with a generated collection are rejected before writes.
