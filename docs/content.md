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
of nonempty strings), `draft` (boolean, default false). Unknown keys and wrong types are errors, not silently
ignored typos. Tags are trimmed, deduplicated and deterministically sorted.
The closing delimiter is a line containing `---`. CRLF is accepted. Metadata
errors include the source filename and the frontmatter starting line; JSON
syntax errors also include the parser's position inside the header.

Without frontmatter, title is the first H1 outside code fences, or the filename
stem. Metadata is removed before Markdown rendering.

Layout placeholders: `{{title}}`, `{{description}}`, `{{content}}`, `{{toc}}`.
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

The Markdown subset now includes backtick-delimited inline code and simple
`[label](href)` links in paragraphs/headings. Nested labels, escaping and URLs
with literal parentheses are not yet CommonMark-compatible. Link text is plain
text and escaped. Raw HTML remains escaped. HTTP(S) and mailto links are allowed;
script/data/protocol-relative URLs, control characters and whitespace are rejected
at build time. Link-looking text inside inline or fenced code is ignored.

Before any output changes, builds and `explain` validate relative links against
the planned output routes, not stale files on disk. Use generated `.html` paths
(not `.md`); Unicode and percent-encoded filenames work. Query/fragment parts are
ignored for file existence checks. Generated `mp-` heading fragments receive
additional validation as described below; external URLs are not fetched. Root-relative links must stay under the configured site base path.
With no site config the root base path is `/`.

Static, quoted `href` and `src` attributes in layout.html are also checked. The attribute
tokenizer respects quotes/comments, but it is not a full HTML validator. Dynamic
href/src placeholders are unsupported and rejected. Only `&amp;` entity decoding is
supported in these URLs; percent-encode other special characters. CSS url(), srcset,
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
Inline parsing remains line-scoped. Fences start at column zero with at least three backticks or tildes. They close
only with the same character repeated at least as many times, followed only by
spaces/tabs. Shorter runs, a different fence character and trailing text remain
code. Backtick opening info strings cannot contain backticks. Language annotations
are ignored. An unclosed fence
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
recursive asset support yet.


## Images

`![alt](src)` renders an image in headings, paragraphs, list items and quotes.
Alt text is plain text, and both alt and src are HTML-escaped. Empty alt text is
allowed for decorative images. Inline/fenced code stays literal. The syntax has
the same simple-label/destination restrictions as links; nested labels, titles
and literal parentheses in URLs are unsupported.

Local image references and static quoted `src` attributes in the layout are
checked against planned output files before any writes, including during explain.
Use `![Moon](moon.svg)` with `public/moon.svg`. Root-relative paths follow the
configured base path. Only relative/root paths and HTTP(S) source URLs are
allowed; mailto, data, script, protocol-relative and query/fragment-only sources
are rejected. Validation checks local existence, not MIME types, image decoding,
fragment IDs or external URL reachability. srcset and CSS url() remain unchecked.

Changing image bytes updates only that asset; removing a referenced image fails
the build even when the previous output still exists. No image optimization,
network fetching, dimension inference or automatic loading attributes are added.

### URL normalization

Percent encodings for unreserved ASCII characters (letters, digits, `-._~`) are
normalized before route lookup: `%67uide%2Ehtml` resolves to `guide.html`.
Other encoded bytes retain their identity; encoded slashes do not become path
separators, and literal percent signs in filenames need `%25`. Unicode percent
hex digits are case-insensitive, while filenames remain case-sensitive.
A colon inside a query or fragment is not a URL scheme. Scheme names are
case-insensitive (`HTTPS://` is accepted, mixed-case `javascript:` rejected).
The build creates one route index shared by page, image and template validation.

## Heading anchors

Markdown headings receive deterministic `id` attributes prefixed with `mp-`.
IDs use visible inline text (link labels, code text and image alt text), lowercase
letters, digits, underscores and non-ASCII non-whitespace characters. Other
characters collapse into hyphens; empty results use `mp-section`. Duplicates get
`-2`, `-3`, etc., skipping IDs already used by earlier headings, including natural
suffix-like names. Changing heading order/text can change duplicate suffixes.

For example, `## Getting started` produces `id="mp-getting-started"`, which can be
linked as `[Start](#mp-getting-started)`. Code fences do not create anchors. Reserve
the `mp-` ID prefix for MoonPress in templates; arbitrary template IDs are not
checked for collisions.

`check`, `explain` and `build` validate local `href` fragments in the reserved
`mp-` namespace against the destination page's generated IDs. Same-page
`#mp-title`, query-only `?mode=x#mp-title`, cross-page and configured base-path
links share the route normalizer. Percent-encoded ASCII/Unicode spelling is
normalized; matching remains case-sensitive. Malformed percent escapes in local
HTML fragments are errors. Empty fragments and custom IDs outside `mp-` remain
unchecked. External URLs and non-HTML asset fragments (for example SVG/PDF)
are excluded, and text-fragment directives are not interpreted.

Validation uses the current selected sources on every invocation, even if the
linking page would be kept by incremental compilation. Removing a referenced
heading fails before output mutation. Excluded draft bodies are skipped; preview
mode includes and validates their headings/links. Inline/fenced code is ignored.

Static layout hrefs are checked in the context of every generated HTML page.
Article/tag collections have no generated heading IDs, so a shared layout with
`href="#mp-title"` fails on those pages. Use an explicit destination such as
`href="guide.html#mp-title"`, or use `{{toc}}` for page-specific navigation. Layout
URLs retain the documented quoted-attribute and `&amp;`-only entity rules.
The public `validate_links` helper remains route-only; site compilation adds
heading validation using the complete source index.

## Table of contents

Add `{{toc}}` to layout.html to insert a static navigation list. It includes all
H1–H6 headings in source order, with classes `toc-level-1` through `toc-level-6`.
The list is flat, so skipped heading levels do not invent a document hierarchy;
CSS may indent entries by level. Links percent-encode the exact generated IDs,
and labels are escaped plain text without nested links, images or inline markup.

Site planning shares each selected body’s parsed blocks and heading outline
between rendering, TOC generation and reference extraction. Link/image references
are collected in one inline walk; later cross-page validation retains only those
references and heading IDs, not a second site-wide block tree. Frontmatter/title
discovery remains a separate pass. The public standalone Markdown helpers keep
their existing APIs.
Pages without headings and generated article/tag collections receive an empty
TOC. Omitting the placeholder suppresses TOC markup while preserving heading IDs.
The template is expanded once: placeholders appearing inside heading text remain
literal. A body-only heading edit updates that article and its TOC together,
without rebuilding unrelated pages/collections. No browser scripting is needed.


### Inline code delimiters

Inline code opens and closes with backtick runs of exactly the same length.
Different-length runs inside it are literal, so double-backtick delimiters can
contain a single backtick. Links, images and HTML inside code are escaped text,
not references. When content begins and ends with an ASCII space, one space at
each end is removed unless all content is spaces. Unclosed delimiter runs remain
literal. Spans are limited to one source line; multiline spans are unsupported.
Headings and TOC labels use the same normalized code text.

## Draft articles

Set `"draft": true` in JSON frontmatter to exclude an article from publication.
The default is false; other value types are errors. Drafts produce no HTML and
appear in no article/tag collection or sitemap. `build` and `explain` report a
SKIP event; page counts include only published source pages.

Draft metadata is still parsed and validated, but unfinished body links/images
are not checked until publication. Published content or templates linking to a
draft fail validation because it has no output route. Switching a published
article to draft deletes its tracked HTML and obsolete tag pages on a successful
build. Switching back to false restores them. A draft-only body edit leaves
outputs unchanged. check, explain and build use the same publication selection.

In normal mode at least one published Markdown page is required. An all-draft site fails before
any output changes. The public/ directory is independent: its assets are still
copied even if only a draft refers to them. This flag controls generated pages,
not access to source files in a public repository. Use the explicit preview option below to include drafts.


### Preview drafts explicitly

Append `--include-drafts` to any of these commands:

```sh
moonpress check site --include-drafts
moonpress explain site preview --include-drafts
moonpress build site preview --include-drafts
```

In this mode drafts participate in HTML, collections, tags, sitemap and reference
validation just like published pages. An all-draft site is permitted. Broken
references and output collisions in drafts are errors. API users can pass
`include_drafts=true` to `compile_site` or `check_site`; defaults remain false.

Use a separate preview output directory. Preview files contain draft content and
are ordinary static files; there is no access control or draft watermark. If the
same managed output is switched back to normal mode, draft artifacts are removed
on a successful build. The Pages workflow keeps the default publication mode.
The CLI accepts the option only once, at the end; use `./` for paths beginning
with `--` to distinguish them from options.

## Input filesystem contract

The site root and its required `content/` directory must be real directories.
Required `layout.html` and `style.css`, optional existing `site.json`, and every
entry directly inside `content/` must be regular files. Symlinks (including
dangling links), FIFOs and other special entries are rejected before their data
is read. Trailing slashes on the site root do not bypass this check.

Content is flat: subdirectories are errors, so nested articles cannot silently
disappear from publication. Ordinary non-`.md` files directly inside `content/`
are ignored. Markdown extension matching is case-sensitive. An absent
`site.json` is allowed; an invalid existing entry is not treated as absent.
The same rules apply to check, explain, build and draft previews.

These are checks at named input boundaries, not a sandbox: ancestor path
components, concurrent changes and trusted template/asset contents are outside
this protection. Build only trusted local projects; do not change their files
while a build is running. Validation failures occur before output mutations.

### Text encoding and file reads

Layout, Markdown, site configuration and the incremental manifest must be valid
UTF-8. Invalid, truncated, overlong and surrogate encodings produce an error
naming the affected file, before any output changes. A UTF-8 BOM is preserved as
U+FEFF; existing JSON/frontmatter parsing rules still apply. Valid Unicode,
including supplementary characters, is preserved.

CSS and public assets are read as exact bytes and receive no text decoding.
File handles are closed before text decoding and on read/seek/size errors.
The compiler loads file contents into memory; files above the native byte-buffer
limit of 2,147,483,647 bytes are rejected before allocation. Available memory can
impose a lower practical limit. Sources must remain unchanged during a build.
