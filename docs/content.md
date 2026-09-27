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

## Links and inline code

The Markdown subset now includes single-backtick inline code and simple
`[label](href)` links in paragraphs/headings. Nested labels, escaping and URLs
with literal parentheses are not yet CommonMark-compatible. Link text is plain
text and escaped. Raw HTML remains escaped. HTTP(S) and mailto links are allowed;
script/data/protocol-relative URLs, control characters and whitespace are rejected
at build time. Link-looking text inside inline or fenced code is ignored.

Before any output changes, builds and `explain` validate relative links against
the planned output routes, not stale files on disk. Use generated `.html` paths
(not `.md`); Unicode and percent-encoded filenames work. Query/fragment parts are
ignored for file existence checks; fragment IDs and external URLs are not fetched
or validated. Root-relative links must stay under the configured site base path.
With no site config the root base path is `/`.

Static, quoted `href` attributes in layout.html are also checked. The attribute
tokenizer respects quotes/comments, but it is not a full HTML validator. Dynamic
href placeholders are unsupported and rejected. Only `&amp;` entity decoding is
supported in these URLs; percent-encode other special characters. CSS url(), src,
JavaScript-generated links and arbitrary HTML fragments are outside this checker.

## Site URL and sitemap

Optional site.json:

```json
{"base_url":"https://example.org/project/"}
```

This generates sitemap.xml for source articles, articles.html and tag pages.
The HTTP(S) base is normalized to a trailing slash; credentials, query strings,
fragments and dot path segments are rejected. Unknown config keys are errors.
No lastmod timestamp is invented. URL and route membership are sitemap dependencies:
body changes do not rewrite the sitemap. Removing site.json removes the tracked
sitemap on the next build. The site remains relative-link based and portable.

## Markdown compiler core

One block parser defines headings, paragraphs, fenced code, lists and quotes. HTML rendering,
title discovery and Markdown link extraction consume that same block model.
Inline parsing remains line-scoped. Fences begin/end on any line starting with
three backticks; language annotations are currently ignored. An unclosed fence
runs to EOF. CRLF is normalized and raw HTML is always escaped.


### Lists and quotes

At column zero, `- `, `* ` and `+ ` introduce an unordered list item. Consecutive
items form one list even when the bullet changes. `1. ` through nine-digit ASCII
number markers introduce ordered items (`0. ` is also allowed); the first number
sets the HTML start attribute, and following item numbers do not reset numbering.
Leading zeroes are normalized. `> ` introduces a quote line; a bare `>` is an empty
quote line. Consecutive quote lines form one paragraph inside a blockquote.

A blank line, heading, fence, different block kind or EOF closes the group. Each
list item is one line. Unmarked continuation lines become ordinary paragraphs.
Indented/nested lists, nested quote parsing, loose multi-paragraph items and
recursive Markdown inside quotes are unsupported and stay literal. Inline links
and code work inside all these blocks, and their links receive the same preflight
validation as paragraph links. Code fences suppress all list/quote syntax.


## Static assets

Place files directly in the optional `public/` directory. They are copied to the
output root as bytes, without decoding or transforming their contents. Supported
extensions (case-insensitive): png, jpg, jpeg, gif, webp, avif, ico, svg, css, woff,
woff2, ttf, otf, pdf, txt, xml, json, webmanifest. Other extensions, including
JS/TS, are rejected. These are trusted project assets, not sanitized uploads;
extensions select supported files, not a content security boundary.

For example, `public/manual.pdf` is available as `manual.pdf` and can be linked
with `[Download](manual.pdf)`. Percent-encode special characters in filenames.
Nested directories and symlinks (including a symlink for public itself) are
rejected. Output names cannot collide with generated pages, style.css, sitemap.xml
or MoonPress management files. All checks happen before output changes.

Every asset has its own content-hash dependency: editing it does not rebuild
pages or collections. Deletions and renames remove old tracked outputs; missing
outputs are restored. Removing public/ removes its tracked assets, provided no
remaining links refer to them. `explain` reports the same plan without writing.
Only generated HTML routes enter the sitemap. There is no image optimization,
Markdown image syntax or recursive asset support yet; templates may use static
image tags, whose src attributes are not checked by the link validator.
