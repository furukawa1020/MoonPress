///|
priv struct PageReferences {
  output : String
  links : Array[String]
  images : Array[String]
}

///|
fn plan_site(
  input : String,
  previous : Map[String, Artifact],
  output : String?,
  include_drafts? : Bool = false,
) -> BuildPlan raise {
  if input.is_empty() {
    raise InvalidInput("Input directory must not be empty")
  }
  let trimmed = input.trim_end(chars="/").to_owned()
  let input = if trimmed.is_empty() { "/" } else { trimmed }
  require_input_kind(input, 2)
  require_input_kind(input + "/content", 2)
  require_input_kind(input + "/layout.html", 1)
  require_input_kind(input + "/style.css", 1)
  let config = read_site_config(input)
  let base_url = config.base_url
  let layouts = load_layouts(input)
  let layout = layouts.default.content
  let page_layouts : Map[String, LayoutTemplate] = Map([])
  let css = read_bytes(input + "/style.css")
  let names = @fs.read_dir(input + "/content").to_owned()
  names.sort()
  let pending : Array[Pending] = []
  let log : BuildLog = { events: [], changes: [], }
  let documents : Array[Page] = []
  let references : Array[PageReferences] = []
  let heading_targets : Map[String, Map[String, Bool]] = Map([])
  let mut pages = 0
  let layout_digest = layouts.default.digest
  let compiler_digest = digest_text("moonpress-renderer-v17")
  for name in names {
    let path = input + "/content/" + name
    require_input_kind(path, 1)
    if name.has_suffix(".md") {
      let source = read_text(path)
      let stem = name[:name.length() - 3].to_owned()
      let document = parse_document(source, stem, filename=path)
      if document.draft && !include_drafts {
        record_event(log, "skip", "content/" + name, "draft")
        continue
      }
      let route = document.slug.unwrap_or(stem) + ".html"
      let template = select_layout(layouts, input, document.layout)
      page_layouts[route] = template
      documents.push({ output: route, document, })
      let blocks = parse_blocks(document.body)
      let outline = block_headings(blocks)
      let (links, images) = block_references(blocks)
      references.push({ output: route, links, images, })
      heading_targets[url_component(route)] = index_heading_ids(outline)
      let deps : Array[Dependency] = [
        { name: "compiler", digest: compiler_digest, },
        { name: template.source, digest: template.digest, },
        { name: "content/" + name, digest: digest_text(source), },
      ]
      pending.push(
        plan_artifact(
          route,
          deps,
          previous,
          output,
          () => {
            @utf8.encode(
              apply_layout(
                template.content,
                document.title,
                render_blocks_with_headings(blocks, outline),
                description=document.description,
                date=document.date.unwrap_or(""),
                toc=if template.content.contains("{{toc}}") {
                  render_outline(outline)
                } else {
                  ""
                },
              ),
            )
          },
          log,
        ),
      )
      pages += 1
    }
  }
  if pages == 0 {
    raise InvalidInput("No published .md pages found")
  }
  documents.sort_by((a, b) => a.output.compare(b.output))
  for archive in article_archives(documents, config.page_size) {
    pending.push(
      plan_artifact(
        archive.output,
        archive_dependencies(archive, layout_digest),
        previous,
        output,
        () => {
          @utf8.encode(
            apply_layout(layout, archive.title, render_archive(archive)),
          )
        },
        log,
      ),
    )
  }
  let tags : Array[String] = []
  for page in documents {
    for tag in page.document.tags {
      if !tags.contains(tag) {
        tags.push(tag)
      }
    }
  }
  tags.sort()
  for tag in tags {
    let members = documents.filter(page => page.document.tags.contains(tag))
    pending.push(
      plan_artifact(
        tag_filename(tag),
        collection_dependencies(members, layout_digest),
        previous,
        output,
        () => {
          @utf8.encode(
            apply_layout(layout, tag, render_collection(tag, members)),
          )
        },
        log,
      ),
    )
  }
  pending.push(
    plan_artifact(
      "style.css",
      [{ name: "style.css", digest: digest_bytes(css), }],
      previous,
      output,
      () => css,
      log,
    ),
  )
  pending.push(plan_artifact(".nojekyll", [], previous, output, () => b"", log))
  let public_dir = input + "/public"
  let public_kind = path_kind(public_dir)
  if public_kind != 0 {
    if public_kind != 2 {
      raise InvalidInput("public must be a real directory, not a symlink")
    }
    let assets = @fs.read_dir(public_dir).to_owned()
    assets.sort()
    for name in assets {
      let path = public_dir + "/" + name
      if path_kind(path) != 1 {
        raise InvalidInput(
          "Expected regular public asset (no subdirectories): " + path,
        )
      }
      if !safe_output_name(name) || !allowed_asset_name(name) {
        raise InvalidInput("Unsupported public asset name: " + name)
      }
      let bytes = read_bytes(path)
      pending.push(
        plan_artifact(
          name,
          [{ name: "public/" + name, digest: digest_bytes(bytes), }],
          previous,
          output,
          () => bytes,
          log,
        ),
      )
    }
  }
  if config.feed is Some(feed) {
    let url = base_url.unwrap()
    validate_feed(url, documents)
    pending.push(
      plan_artifact(
        "rss.xml",
        feed_dependencies(url, feed, documents),
        previous,
        output,
        () => @utf8.encode(render_feed(url, feed, documents)),
        log,
      ),
    )
  }
  let routes = pending.map(item => item.artifact.name)
  if base_url is Some(_) {
    routes.push("sitemap.xml")
  }
  let route_lookup = index_routes(routes)
  for route in routes {
    let key = url_component(route)
    if route.has_suffix(".html") && !heading_targets.contains(key) {
      heading_targets[key] = Map([])
    }
  }
  let base_path = match base_url {
    Some(url) => site_base_path(url)
    None => "/"
  }
  for page in references {
    validate_route_links(
      page.images,
      route_lookup,
      sources=true,
      base_path~,
      source=page.output,
    )
    let links = page.links
    validate_route_links(links, route_lookup, base_path~, source=page.output)
    validate_heading_links(
      links,
      heading_targets,
      page.output,
      base_path,
      page.output,
    )
  }
  validate_layouts(
    layouts, page_layouts, routes, route_lookup, heading_targets, base_path,
  )
  if base_url is Some(url) {
    let sitemap_routes = documents.map(page => page.output)
    for route in routes {
      if route.has_suffix(".html") && !page_layouts.contains(route) {
        sitemap_routes.push(route)
      }
    }
    pending.push(
      plan_artifact(
        "sitemap.xml",
        [
          { name: "site.json/base_url", digest: digest_text(url), },
          {
            name: "routes",
            digest: digest_text(sitemap_routes.to_json().stringify()),
          },
          { name: "sitemap-renderer", digest: digest_text("sitemap-v1"), },
        ],
        previous,
        output,
        () => @utf8.encode(render_sitemap(url, sitemap_routes)),
        log,
      ),
    )
  }
  let current : Map[String, Bool] = Map([])
  let artifacts : Array[Artifact] = []
  let mut written = 0
  for item in pending {
    if current.contains(item.artifact.name) {
      raise InvalidInput("Output collision: " + item.artifact.name)
    }
    current[item.artifact.name] = true
    artifacts.push(item.artifact)
    if item.content is Some(_) {
      written += 1
    }
  }
  let removed : Array[String] = []
  for name, _ in previous {
    if !current.contains(name) {
      removed.push(name)
    }
  }
  removed.sort()
  for name in removed {
    record_event(log, "delete", name, "source removed")
  }
  {
    pending,
    removed,
    manifest: serialize_manifest(artifacts),
    report: {
      pages,
      written,
      skipped: pending.length() - written,
      deleted: removed.length(),
      events: log.events,
      changes: log.changes,
    },
  }
}

///|
fn allowed_asset_name(name : String) -> Bool {
  let lower = name.to_lower()
  [
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".ico", ".svg", ".css", ".woff",
    ".woff2", ".ttf", ".otf", ".pdf", ".txt", ".xml", ".json", ".webmanifest",
  ].any(suffix => lower.has_suffix(suffix))
}
