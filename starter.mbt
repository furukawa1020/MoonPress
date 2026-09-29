///|
fn starter_files() -> Array[(String, String)] {
  [
    (
      "layout.html",
      (
        #|<!doctype html>
        #|<html lang="en">
        #|<head>
        #|<meta charset="utf-8">
        #|<meta name="viewport" content="width=device-width, initial-scale=1">
        #|<title>{{title}}</title>
        #|<meta name="description" content="{{description}}">
        #|<link rel="stylesheet" href="style.css">
        #|</head>
        #|<body>
        #|<header><a href="index.html">My MoonPress site</a><nav aria-label="Main"><a href="guide.html">Guide</a> <a href="articles.html">Articles</a></nav></header>
        #|<main>{{content}}</main>
        #|<footer>Built with MoonPress.</footer>
        #|</body>
        #|</html>
        #|
      ),
    ),
    (
      "style.css",
      (
        #|html { color-scheme: light dark; font: 18px/1.65 system-ui, sans-serif; }
        #|body { max-width: 52rem; margin: auto; padding: 1.5rem; }
        #|header, footer { padding: 1rem 0; }
        #|nav a { margin-right: 1rem; }
        #|a { text-underline-offset: .2em; }
        #|pre { overflow-x: auto; padding: 1rem; border: 1px solid currentColor; }
        #|img { max-width: 100%; height: auto; }
        #|blockquote { margin-left: 0; padding-left: 1rem; border-left: .2rem solid currentColor; }
        #|:focus-visible { outline: 3px solid currentColor; outline-offset: 4px; }
        #|
      ),
    ),
    (
      "content/index.md",
      (
        #|---
        #|{"title":"My MoonPress site","description":"A native MoonBit static site."}
        #|---
        #|# Welcome
        #|
        #|Your site is ready to edit. Change this file in `content/index.md`, then run the build again.
        #|
        #|- Read the [writing guide](guide.html).
        #|- Browse [all articles](articles.html).
        #|
        #|No JavaScript is needed to read this site.
        #|
      ),
    ),
    (
      "content/guide.md",
      (
        #|---
        #|{"title":"Writing guide","description":"Edit, validate and build your first site.","layout":"post.html","tags":["guide"]}
        #|---
        #|# Writing guide
        #|
        #|## Write
        #|
        #|Add Markdown files directly to `content/`. Each becomes a matching HTML file.
        #|Use **strong text**, *emphasis*, lists, quotes and fenced code. Link to generated `.html` paths.
        #|
        #|## Check and build
        #|
        #|Run these commands from this project directory with the MoonPress executable on PATH:
        #|
        #|```sh
        #|moonpress check .
        #|moonpress build . dist
        #|moonpress explain . dist
        #|```
        #|
        #|Open `dist/index.html` to preview. Edit sources, not generated files.
        #|
        #|## Customize
        #|
        #|Change `layout.html` for the default design, `layouts/post.html` for this page, and `style.css` for styles.
        #|Add a valid `date` such as `2026-01-01` to frontmatter to order articles by publication date.
        #|Use `"draft": true` in JSON frontmatter to exclude an unfinished page; preview it with `--include-drafts`.
        #|
        #|[Back home](index.html)
        #|
      ),
    ),
    (
      "layouts/post.html",
      (
        #|<!doctype html>
        #|<html lang="en">
        #|<head>
        #|<meta charset="utf-8">
        #|<meta name="viewport" content="width=device-width, initial-scale=1">
        #|<title>{{title}}</title>
        #|<meta name="description" content="{{description}}">
        #|<link rel="stylesheet" href="style.css">
        #|</head>
        #|<body>
        #|<header><a href="index.html">My MoonPress site</a><nav aria-label="Main"><a href="guide.html">Guide</a> <a href="articles.html">Articles</a></nav></header>
        #|<main><aside>{{toc}}</aside><article>{{content}}</article></main>
        #|<footer>Built with MoonPress.</footer>
        #|</body>
        #|</html>
        #|
      ),
    ),
    (
      "README.md",
      (
        #|# Your MoonPress site
        #|
        #|With the MoonPress native executable on PATH, run from this directory:
        #|
        #|```sh
        #|moonpress check .
        #|moonpress build . dist
        #|moonpress explain . dist
        #|```
        #|
        #|Open `dist/index.html` in a browser. Rebuild after editing the source files.
        #|Do not manually edit generated files in `dist/`.
        #|
        #|- `content/index.md`: home page.
        #|- `content/guide.md`: example article and local writing guide.
        #|- `layout.html`: default template and article/tag collection layout.
        #|- `layouts/post.html`: selected by the guide's JSON frontmatter.
        #|- `style.css`: styles shared by all pages.
        #|
        #|Use a separate `preview/` output with `--include-drafts` for unpublished content.
        #|Generated output is static HTML/CSS; it needs no JavaScript runtime or server code.
        #|To add a sitemap, create `site.json` with your real deployed URL:
        #|`{"base_url":"https://example.org/project/"}`. Do not use a placeholder URL in a deployed sitemap.
        #|
        #|This starter does not create a Git repository, remote, deployment credentials or a hosting workflow.
        #|Publish the generated files using your static hosting provider. For MoonPress's shell-only GitHub Actions example,
        #|see https://github.com/furukawa1020/MoonPress/blob/main/docs/deployment.md .
        #|Full supported content syntax: https://github.com/furukawa1020/MoonPress/blob/main/docs/content.md .
        #|
      ),
    ),
  ]
}
