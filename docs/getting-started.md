# Create and build your first site

MoonPress currently targets Linux x86_64. Build the compiler using the repository
README instructions; setup requires a C compiler, curl, Git, Bash, jq and GNU
command-line tools. No Node/npm or JavaScript runtime is required. The exact
MoonBit toolchain is verified by setup; fixed archive distribution is still an
open release gate.

From the MoonPress checkout after `bash scripts/check.sh`:

```sh
moonpress="$PWD/_build/native/release/build/cmd/main/main.exe"
"$moonpress" init ../my-site
"$moonpress" check ../my-site
"$moonpress" build ../my-site ../my-site/dist
```

Open `../my-site/dist/index.html` directly in a browser. The starter has a home
page, writing guide, navigation, CSS and an example named layout. Generated pages
use relative links and need no server-side code. To put the executable on PATH:

```sh
mkdir -p "$HOME/.local/bin"
install -m755 "$moonpress" "$HOME/.local/bin/moonpress"
export PATH="$HOME/.local/bin:$PATH"
```

This installs only the native executable. The MoonBit compiler is needed to
rebuild MoonPress itself, not to generate sites with that executable. Installation
here is from your verified local build; it is not a downloadable stable release.

## Edit and rebuild

From the new project's directory:

```sh
moonpress check .
moonpress explain . dist
moonpress build . dist
```

Edit `content/index.md` and `content/guide.md`, `layout.html`, `layouts/post.html`
and `style.css`. Add Markdown files directly under `content/`; nested content is
not supported yet. The guide's JSON frontmatter selects its named layout. Its
tag automatically creates a tag page. README.md in the new project repeats the
essential commands. See [content semantics](content.md) for supported syntax.

`check` validates in memory. `explain` shows the planned writes/deletions without
making them. `build` updates generated files; unchanged files keep their mtimes.
Do not manually edit generated output or place other files inside `dist/`.

Preview drafts in a separate output directory:

```sh
moonpress build . preview --include-drafts
```

## Initialization contract

```sh
moonpress init new-site
moonpress init new-site --json
moonpress init --help
```

The parent directory must exist. The target must not exist, even as an empty
directory, ordinary file or symlink. There is no force/merge/overwrite option.
Use `./--name` for names beginning with `--`; spaces and Unicode paths work when
quoted. A successful init creates exactly seven deterministic source files and
prints a report. It does not build output, initialize Git, access the network,
create credentials or configure hosting. Edit the generated project normally;
it is not a MoonPress-managed output directory.

JSON success uses the existing schema-1 envelope with `command: "init"`,
`include_drafts: false`, and `report: {directory, files}`. `directory` retains the
supplied spelling with trailing slashes removed; `files` contains relative file
paths in creation order. No absolute-path canonicalization is promised.
Exit statuses are 0 for success, 1 for filesystem/validation errors, and 2 for
invalid arguments. Errors use stderr with empty stdout. `--json` is the only
operation option and may appear once after the directory. `--include-drafts`
is not accepted by init. Library callers can use `init_site` and `InitReport`.

The initializer takes the same conservative parent-directory lock as build and
uses exclusive mkdir. On a caught failure, it attempts to remove only files and
directories created by that invocation; cleanup never recursively removes a
source tree. An incomplete cleanup is reported alongside the original error.
A killed process or failed cleanup can leave a partial new project. Init has no
recovery journal; inspect and keep/remove that directory yourself, or choose a
new name. Existing-target refusal prevents a retry from silently overwriting it.
These guarantees concern trusted local projects, not hostile concurrent changes
to ancestor directories. Do not edit the project during initialization.

## Configure local navigation

The starter includes `site.json` with a tag index and article/tag pages of 10
entries. It needs no deployment URL. Its home page uses `"listed":false` so it
stays accessible without appearing among articles. The writing guide is a listed
article with a tag and its own page layout.

Change `page_size` and `tag_page_size` (1–1000) to tune pagination. Add
`"collection_layout":"archive.html"` and create `layouts/archive.html` to style
listing pages separately. To disable the tag index, remove links to `tags.html`
from both templates and the home page before setting `tag_index` to false.

Add `"draft":true` to an unfinished article and build to a separate `preview/`
directory with `--include-drafts`; keep deployment output free of drafts.

## Publish static output

Publish the generated files using your static hosting provider. For a sitemap,
add the actual deployment base URL to the generated `site.json` before building,
preserving its navigation settings:

```json
{"base_url":"https://example.org/my-site/","tag_index":true,"page_size":10,"tag_page_size":10}
```

Replace that example with your real URL. No date or hostname is inferred.
The [GitHub Actions deployment guide](deployment.md) describes this repository's
shell-only example and the necessary one-time Pages setting. The starter does
not install that workflow into a new repository, and a local build is not proof
of a successful public deployment.

## Review your posts

Run `moonpress posts my-site` to list source filenames, titles, draft status and
resolved HTML routes. Use `moonpress posts my-site --json` for the schema-1 report
with `report.posts`; each entry includes `source`, `output`, `title`, `draft`,
`listed`, nullable `date` and `tags`. All posts are included, even drafts and
unlisted pages. Ordering is deterministic by source filename (length then code
units). Text fields are JSON-quoted to keep embedded newlines on one line.

`ready` means the page is eligible for a normal build; it does not mean deployed.
This read-only inventory needs only the site and its flat `content/` directory,
so it works while layouts or configuration are being edited. It uses the same
strict frontmatter parser as the compiler. No route collision, content-link,
layout or deployment validation is performed; use `check` before building.
Invalid input fails without a partial report. The listing is not a snapshot
against an external editor changing files during the operation.
