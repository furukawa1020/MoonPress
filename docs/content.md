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
of nonempty strings), `draft` (boolean, default false), `layout` (safe `.html` filename), `date` (calendar date string). Unknown keys and wrong types are errors, not silently
ignored typos. Tags are trimmed, deduplicated and deterministically sorted.
The closing delimiter is a line containing `---`. CRLF is accepted. Metadata
errors include the source filename and the frontmatter starting line; JSON
syntax errors also include the parser's position inside the header.

Without an explicit title, the first H1 outside code fences supplies plain inline
text: link labels, normalized code text and image alt text, with outer whitespace
trimmed. Supported inline delimiters and link destinations do not enter the title.
If that H1 has no visible text, or no H1 exists, the filename stem is used; a later
H1 does not replace an empty first H1. Explicit metadata titles remain literal
strings and skip automatic title discovery. Metadata is removed before rendering.
Titles are escaped when inserted into layouts and collection labels.

Layout placeholders: `{{title}}`, `{{description}}`, `{{content}}`, `{{toc}}`, `{{date}}`.
Title/description are escaped; content is generated HTML. Inserted values are
never expanded again, so text containing another placeholder remains literal.
Unknown template placeholders are preserved for forward compatibility.

## Per-page layouts

The required root `layout.html` is the default for source pages and all generated
article/tag collections. To select a different template for a source page, put
it in `layouts/post.html` and add metadata:

```text
---
{"layout":"post.html","title":"An article"}
---
# Article
```

The value is one literal, case-sensitive filename ending in `.html`, up to 255
UTF-8 bytes. Unicode names work. Empty stems, leading dots, slashes, backslashes,
colons, whitespace and control characters are rejected. It is not a URL or a
path: use `post.html`, not `layouts/post.html`. Omit the field to use the default;
null and other types are errors. Each selected template must be a valid UTF-8
regular file containing `{{content}}`; it supports the same placeholders and
single-pass escaping as the default. No includes, inheritance or template code.

An existing `layouts/` must be a real directory, not a symlink. Only selected
named files are loaded and validated; unused files/subdirectories are ignored.
Selected symlinks, directories, FIFOs and missing files are errors. Draft metadata
is always validated, but an excluded draft's layout is not loaded until it is
included by preview or published. Default `layout.html` is always required for
collections, even when all source pages use named layouts.

Static quoted href/src values are relative to generated output routes, not the
`layouts/` source directory. They receive the same URL checks as the default.
Generated `mp-` fragments are validated separately against every page using that
template. A named template's same-page anchor need not exist in unrelated pages
or collections. All checks run before output mutation, including on no-op builds.

Each selected template is read/hashed and its references parsed once per build.
A page depends on its selected template only. Editing a named template rebuilds
its consumers; editing the default rebuilds default pages and collections.
Unused template changes do not affect output. Switching a page's selection
rebuilds that page without changing collection metadata. Templates are not copied
to output. Removing a still-selected layout is an error; remove/change its
consumers first. Existing projects without this field keep the same dependencies
and output bytes; no manifest schema or renderer revision change is needed.

Library API: `Document` now has `layout : String?`. Callers constructing the
public struct directly must add `layout: None` (or `Some(filename)`); users of
`parse_document` need no change. CLI options and report schemas are unchanged.

## Collections

`articles.html` lists all selected source pages in publication-date order (newest
first), followed by undated pages. Equal dates and undated pages use the existing
MoonBit filename comparison (length first, then code-unit order), not locale
collation. Tag pages use the same ordering. Every
nonempty tag produces `tag-<UTF-8 bytes in hex>.html`. Tags may use Unicode and
are limited to 96 UTF-8 bytes so generated filenames fit POSIX limits. Links
percent-encode source filenames; title/description/tag text is HTML-escaped.

Body edits rebuild the article only. Title/description/tag/date edits rebuild the
article and affected collections. Removed tags delete their obsolete generated
pages. Membership changes and metadata are separate dependencies. Source pages
whose output collides with a generated collection are rejected before writes.

## Article archive pagination

Set `page_size` in `site.json` to a numeric integer from 1 to 1000:

```json
{"base_url":"https://example.org/project/","page_size":20}
```

The first archive stays at `articles.html`; subsequent pages are
`articles-2.html`, `articles-3.html`, etc. Source pages are sorted by the same
publication-date and filename rules before partitioning, so each appears once.
Archives use the default layout, with titles `Articles` and `Articles — page N`.
Previous/next links use `rel` attributes inside a labeled navigation element,
alongside a `Page N of M` indicator. Even a one-page enabled archive shows its
position. There is no JavaScript or client-side pagination.

Omit the setting to keep the original single archive, HTML and dependencies.
Zero, negative, fractional, out-of-range and non-number values are errors. As
before, a present `site.json` requires `base_url`. Tag archives remain single
pages. RSS includes all selected source pages, independently of archive size.
The source-page count in reports is unchanged by generated archive pages.

All archive routes enter the sitemap and route/anchor checks. A source page
named `articles-2.md` collides when that route is generated. Draft previews can
have more pages; returning to normal mode removes obsolete tracked archives.
Shrinking/disabling pagination also removes obsolete pages, after validating
remaining incoming links and protecting edited/unmanaged outputs.

Each archive depends on its own members' metadata, the default layout and page
number/count. Body edits do not rebuild archives; metadata edits update the
containing archive. Date or membership changes can move entries across pages;
page-count changes update navigation throughout. Clean and incremental output
remain identical. Existing sites without pagination do not need a renderer or
manifest migration; enabling/disabling it changes explicit dependencies.

## Publication dates

Optional `"date":"2026-09-29"` metadata supplies a publication date. Values must
use exactly ASCII `YYYY-MM-DD`, with years 0001–9999 and a valid Gregorian month
and day. Leap years include 2000 and 2024; 1900 and 2100 are not leap years.
Whitespace, timestamps, timezones, empty strings, null and other types are errors,
even in excluded drafts. Omit the key when the date is unknown.

Dated collection entries include `<time datetime="2026-09-29">2026-09-29</time>`.
The default and named layouts can insert escaped `{{date}}`; it expands to an
empty string for undated pages and generated collections. Inserted values are
never expanded again. Dates affect article/tag order and collection dependencies;
changing a date updates that page and its collections but not the sitemap.
Body-only changes do not update collections.

Dates are descriptive metadata, not scheduled publication. Future dates are
accepted and do not hide a page; use `draft` for publication control. The compiler
never consults the clock, file timestamps or locale, and does not infer sitemap
`lastmod` from a publication date. Source-page processing/report order stays in
filename order; only rendered collections use chronological order.

Library API: `Document` additionally has `date : String?`; direct struct callers
must supply `date: None` or a validated date. `parse_document` validates this field.
`apply_layout` adds an optional `date` argument. `render_collection` now sorts a
copy of its input, leaving the caller's array intact. Public rendering helpers
escape supplied values but do not validate manually constructed metadata.
Renderer dependencies advance to rebuild existing page/collection caches once;
manifest and CLI report schemas remain unchanged.

## Links and inline code

The Markdown subset now includes backtick-delimited inline code and simple
`[label](href)` links in paragraphs/headings. Nested labels and URLs
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

### Backslash escapes

Backslash followed by ASCII punctuation emits that punctuation literally:
`\*literal\*`, `` \`code\` `` and `\[text](missing.html)` do not start emphasis,
inline code or a link. All ASCII punctuation is supported. Backslashes before
letters, whitespace or Unicode, and a trailing backslash, remain literal.
Escaped output is never parsed a second time; HTML characters are still escaped.

Link labels and image alt text use the same decoding; escaped brackets remain
plain label text (`[\[label\]](guide.html)`). Nested unescaped labels remain
unsupported. Destinations do not decode backslashes and continue to reject them;
use URL percent encoding where appropriate. To suppress an image reference,
write `!\[alt](image.png)`. Escaping only `!` leaves a normal link after it:
`\![alt](guide.html)` renders an exclamation mark followed by a link.

Inline/fenced code preserves backslashes verbatim. Escaped leading block markers
such as `\# heading`, `\- item` and `\> quote` become paragraph text. Escapes do
not change JSON frontmatter, template markup or explicit metadata strings.
Automatic titles, TOC labels and heading IDs use decoded visible text; links to
old IDs may need updating. Validation catches stale `mp-` links before writes.

Renderer revisions v16 (source pages) and v4 (collections) refresh old caches
once. Later body-only escape edits rebuild only their page; automatic-title
changes also update affected collections. Public APIs and schemas are unchanged.

### Emphasis and strong emphasis

Exact single and double asterisk runs produce `*emphasis*` (`<em>`) and
`**strong emphasis**` (`<strong>`). Different-length spans can nest, such as
`**outer *inner* end**`, and may contain inline code, links and images.
The shared parser removes matched delimiters from automatic titles, TOC labels
and heading IDs. Links and images inside emphasis receive normal preflight checks.

This is an explicit subset, not CommonMark delimiter resolution. An opener must
have non-whitespace/non-control content immediately after it and either a line
boundary, whitespace or ASCII punctuation (excluding underscore) before it.
A closer uses the reverse rule. Intraword asterisks, runs of three or more,
underscores and unmatched delimiters remain literal. Only the most recent open
span can close; mismatched delimiters are not rearranged. Delimiters cannot span
lines. Non-ASCII punctuation is not an outer boundary unless it is whitespace.

Code and fenced code stay literal. Link labels and image alt text remain plain
text, so `[*label*](guide.html)` does not emphasize the label; use
`*[label](guide.html)*` to emphasize the whole link. Raw HTML stays escaped.

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

## RSS subscriptions

To generate `rss.xml`, extend `site.json`:

```json
{"base_url":"https://example.org/project/","feed":{"title":"My site","description":"Project updates"}}
```

Both feed fields must be nonempty strings. Unknown fields and wrong types are
errors; omit `feed` to disable it. A present `site.json` still requires `base_url`.
Add `<link rel="alternate" type="application/rss+xml" title="Updates" href="rss.xml">`
to your layout head for discovery, or an ordinary RSS link. These references are
validated against the generated route like any other link.

The RSS 2.0 summary feed includes every selected source page in the same date
order as collections, including undated pages after dated ones. Generated
collections are excluded. Each item has its metadata title, plain-text metadata
description, tags as categories, and absolute encoded link/GUID. The channel link
points to `articles.html`. GUIDs change if the base URL or filename changes.
Descriptions are escaped as HTML inside XML so literal markup remains text in
readers; article bodies and templates are not embedded. RSS does not require a
publication timestamp: date-only metadata sorts entries, while `pubDate` and
`lastBuildDate` are omitted rather than inferring a time/timezone or using a clock.
Format reference: https://www.rssboard.org/rss-specification

Drafts are excluded unless `--include-drafts` is explicitly selected. Feed metadata
must contain valid XML 1.0 characters; unsupported controls are rejected before
writes, including during check/explain and no-op builds. Metadata of excluded
drafts does not enter the feed.

RSS depends on its settings, membership and article metadata. Body/layout/CSS edits
do not rewrite it; title/description/tag/date edits do. Removing feed configuration
removes its tracked output on the next build, after removing incoming references.
A public asset named `rss.xml` collides while feed generation is enabled. Modified
or unmanaged outputs receive the same protections as HTML. No network fetching,
RSS client, full-content feed or browser scripting is added.

## Markdown compiler core

One block parser defines headings, paragraphs, fenced code, lists and quotes. HTML rendering,
title discovery and Markdown link extraction consume that same block model.
Inline parsing remains line-scoped. Fences start at column zero with at least three backticks or tildes. They close
only with the same character repeated at least as many times, followed only by
spaces/tabs. Shorter runs, a different fence character and trailing text remain
code. Backtick opening info strings cannot contain backticks. Language annotations follow the rules below. An unclosed fence
runs to EOF. CRLF is normalized and raw HTML is always escaped.


### ATX headings

At column zero, one through six `#` markers followed by an ASCII space, tab or
end of line introduce H1–H6. Seven or more markers, indentation and a missing
separator stay paragraph text. Thus `# Title`, `#` and a hash followed by a tab
are headings; `#Title` is not. Only ASCII spaces/tabs delimit this syntax.

Outer ASCII spaces/tabs are removed from heading content. An optional final run
of hashes is removed when preceded by an ASCII space/tab, after ignoring trailing
spaces/tabs: `## Title ###` displays `Title`. Attached hashes (`# C#`), escaped
hashes and hashes followed by other text stay visible. Remaining content uses
the normal inline parser. Fenced code is unaffected.

Empty headings produce empty heading elements and TOC labels with deterministic
`mp-section` IDs (and duplicate suffixes). An empty first H1 keeps the filename
fallback for automatic titles; a later H1 does not replace it. Explicit metadata
titles remain literal and unchanged.

The shared block model supplies normalized text to rendering, titles, TOC,
heading IDs and reference checks. Existing heading IDs can change, particularly
when previously literal tab/empty headings now enter the outline. Update incoming
`mp-` links as needed; stale references fail before output mutation.
Source renderer v17 and collection renderer v5 refresh old caches once. No public
API or manifest/report schema changes are required.

### Fenced-code languages

An opening fence such as ` ```moonbit ` or `~~~sh` produces
`<code class="language-moonbit">` or `<code class="language-sh">`. The first
info token may contain 1–64 ASCII letters, digits, underscores, hyphens or plus
signs; spelling and case are preserved (`C++` works). ASCII spaces/tabs before
that token are skipped; additional space/tab-separated metadata is ignored.
Empty or invalid tokens, including quotes, HTML, Unicode and `{.language}`
notation, produce a plain `<code>` element. No partial token is accepted.

This supplies a CSS hook only: MoonPress does not tokenize code, load a highlighter
or generate JavaScript. Code content remains HTML-escaped and does not create
headings, titles, TOC entries, links or image references. Both fence styles,
CRLF, empty blocks and unclosed fences use the same rules. Existing backtick
opener restrictions and closing-fence rules are unchanged.

Source renderer revision v15 rebuilds cached source pages once. Collections,
CSS and sitemap retain their dependencies; subsequent builds are no-ops.
Changing a language annotation rebuilds only its source page. The CLI, manifest
schema and public library signatures are unchanged.

### Thematic breaks

At column zero, three or more identical `-`, `*` or `_` markers form a horizontal
rule (`<hr>`). Spaces and tabs may separate or follow the markers: `---`, `* * *`
and `_ _ _` work. Indented lines, mixed markers and other trailing content follow
the existing paragraph/list rules. Thematic breaks interrupt paragraphs, lists
and quotes and take precedence over list markers. Fenced code stays literal.
They add no heading, title, TOC entry or reference.

The frontmatter contract is unchanged: a source beginning with `---` followed by
a newline starts JSON frontmatter, not a horizontal rule. Use `***` or `___` for
a rule at the beginning of a page without frontmatter. After the frontmatter
closing delimiter, `---` is a normal thematic break. Setext headings remain
unsupported: `Title` followed by `---` renders a paragraph and a rule.

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
