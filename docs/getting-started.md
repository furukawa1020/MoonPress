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
quoted. A successful init creates exactly six deterministic source files and
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

## Publish static output

Publish the generated files using your static hosting provider. For a sitemap,
add `site.json` containing the actual deployment base URL before building:

```json
{"base_url":"https://example.org/my-site/"}
```

Replace that example with your real URL. No date or hostname is inferred.
The [GitHub Actions deployment guide](deployment.md) describes this repository's
shell-only example and the necessary one-time Pages setting. The starter does
not install that workflow into a new repository, and a local build is not proof
of a successful public deployment.
