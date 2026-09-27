///|
#borrow(path)
extern "C" fn native_path_kind(path : Bytes) -> Int = "moonpress_path_kind"

///|
fn path_kind(path : String) -> Int raise {
  if path.contains("\u0000") {
    raise InvalidInput("NUL in filesystem path")
  }
  native_path_kind(@utf8.encode(path) + b"\x00")
}

///|
pub(all) struct BuildReport {
  pages : Int
  written : Int
  skipped : Int
  deleted : Int
  events : Array[String]
}

///|
priv struct Pending {
  artifact : Artifact
  content : Bytes?
}

///|
fn load_previous(output : String) -> Map[String, Artifact] raise {
  let result : Map[String, Artifact] = Map([])
  let kind = path_kind(output)
  if kind == 0 {
    return result
  }
  if kind != 2 {
    raise InvalidInput("Output must be a real directory, not a symlink")
  }
  let marker = output + "/.moonpress.json"
  if path_kind(marker) != 1 {
    raise InvalidInput("Existing output is not managed by MoonPress")
  }
  let state = parse_manifest(@fs.read_file_to_string(marker))
  for artifact in state.artifacts {
    result[artifact.name] = artifact
  }
  // Refuse unknown files and edited outputs before ANY writes or deletions.
  for name in @fs.read_dir(output) {
    let file = output + "/" + name
    if path_kind(file) != 1 {
      raise InvalidInput("Output contains a non-regular file: " + name)
    }
    if name != ".moonpress.json" {
      match result.get(name) {
        None => raise InvalidInput("Unmanaged output file: " + name)
        Some(artifact) =>
          if digest_bytes(@fs.read_file_to_bytes(file)) != artifact.digest {
            raise InvalidInput("Output was edited outside MoonPress: " + name)
          }
      }
    }
  }
  result
}

///|
fn plan_artifact(
  name : String,
  dependencies : Array[Dependency],
  previous : Map[String, Artifact],
  output : String,
  render : () -> Bytes,
  events : Array[String],
) -> Pending raise {
  if !safe_output_name(name) {
    raise InvalidInput("Invalid output name: " + name)
  }
  let old = previous.get(name)
  let reason = match rebuild_reason(old, dependencies) {
    Some(reason) => Some(reason)
    None =>
      if path_kind(output + "/" + name) == 0 {
        Some("output missing")
      } else {
        None
      }
  }
  if reason is None && old is Some(artifact) {
    events.push("KEEP " + name + " — dependencies unchanged")
    return { artifact, content: None, }
  }
  let content = render()
  let artifact : Artifact = {
    name,
    digest: digest_bytes(content),
    dependencies,
  }
  events.push(
    "WRITE " + name + " — " + reason.unwrap_or("dependency changed"),
  )
  { artifact, content: Some(content), }
}

///|
pub fn compile_site(
  input : String,
  output : String,
  dry_run? : Bool = false,
) -> BuildReport raise {
  let output = output.trim_end(chars="/").to_owned()
  if output.is_empty() {
    raise InvalidInput("Root output directory is not allowed")
  }
  let previous = load_previous(output)
  let base_url = read_base_url(input)
  let layout = @fs.read_file_to_string(input + "/layout.html")
  if !layout.contains("{{content}}") {
    raise InvalidInput("layout.html must contain {{content}}")
  }
  let css = @fs.read_file_to_bytes(input + "/style.css")
  let names = @fs.read_dir(input + "/content").to_owned()
  names.sort()
  let pending : Array[Pending] = []
  let events : Array[String] = []
  let documents : Array[Page] = []
  let mut pages = 0
  let layout_digest = digest_text(layout)
  let compiler_digest = digest_text("moonpress-renderer-v9")
  for name in names {
    if name.has_suffix(".md") {
      let path = input + "/content/" + name
      if path_kind(path) != 1 {
        raise InvalidInput("Expected regular source file: " + path)
      }
      let source = @fs.read_file_to_string(path)
      let stem = name[:name.length() - 3].to_owned()
      let document = parse_document(source, stem, filename=path)
      documents.push({ output: stem + ".html", document, })
      let deps : Array[Dependency] = [
        { name: "compiler", digest: compiler_digest, },
        { name: "layout.html", digest: layout_digest, },
        { name: "content/" + name, digest: digest_text(source), },
      ]
      pending.push(
        plan_artifact(
          stem + ".html",
          deps,
          previous,
          output,
          () => {
            let blocks = parse_blocks(document.body)
            let outline = block_headings(blocks)
            @utf8.encode(
              apply_layout(
                layout,
                document.title,
                render_blocks_with_headings(blocks, outline),
                description=document.description,
                toc=if layout.contains("{{toc}}") {
                  render_outline(outline)
                } else {
                  ""
                },
              ),
            )
          },
          events,
        ),
      )
      pages += 1
    }
  }
  if pages == 0 {
    raise InvalidInput("No .md pages found")
  }
  pending.push(
    plan_artifact(
      "articles.html",
      collection_dependencies(documents, layout_digest),
      previous,
      output,
      () => {
        @utf8.encode(
          apply_layout(
            layout,
            "Articles",
            render_collection("Articles", documents),
          ),
        )
      },
      events,
    ),
  )
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
        events,
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
      events,
    ),
  )
  pending.push(
    plan_artifact(".nojekyll", [], previous, output, () => b"", events),
  )
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
      let bytes = @fs.read_file_to_bytes(path)
      pending.push(
        plan_artifact(
          name,
          [{ name: "public/" + name, digest: digest_bytes(bytes), }],
          previous,
          output,
          () => bytes,
          events,
        ),
      )
    }
  }
  let routes = pending.map(item => item.artifact.name)
  if base_url is Some(_) {
    routes.push("sitemap.xml")
  }
  let route_lookup = index_routes(routes)
  let base_path = match base_url {
    Some(url) => site_base_path(url)
    None => "/"
  }
  for page in documents {
    validate_route_links(
      markdown_images(page.document.body),
      route_lookup,
      sources=true,
      base_path~,
      source=page.output,
    )
    validate_route_links(
      markdown_links(page.document.body),
      route_lookup,
      base_path~,
      source=page.output,
    )
  }
  validate_route_links(
    template_sources(layout),
    route_lookup,
    sources=true,
    base_path~,
    source="layout.html",
  )
  validate_route_links(
    template_links(layout),
    route_lookup,
    base_path~,
    source="layout.html",
  )
  if base_url is Some(url) {
    let sitemap_routes = routes.filter(name => name.has_suffix(".html"))
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
        events,
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
    events.push("DELETE " + name + " — source removed")
  }
  let manifest = serialize_manifest(artifacts)
  if !dry_run {
    if path_kind(output) == 0 {
      @fs.create_dir(output)
    }
    for item in pending {
      if item.content is Some(bytes) {
        @fs.write_bytes_to_file(output + "/" + item.artifact.name, bytes)
      }
    }
    for name in removed {
      if path_kind(output + "/" + name) == 1 {
        @fs.remove_file(output + "/" + name)
      }
    }
    let marker = output + "/.moonpress.json"
    if !@fs.path_exists(marker) || @fs.read_file_to_string(marker) != manifest {
      @fs.write_string_to_file(marker, manifest)
    }
  }
  {
    pages,
    written,
    skipped: pending.length() - written,
    deleted: removed.length(),
    events,
  }
}

///|
pub fn build_site(input : String, output : String) -> Int raise {
  compile_site(input, output).pages
}

///|
fn allowed_asset_name(name : String) -> Bool {
  let lower = name.to_lower()
  [
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif", ".ico", ".svg", ".css", ".woff",
    ".woff2", ".ttf", ".otf", ".pdf", ".txt", ".xml", ".json", ".webmanifest",
  ].any(suffix => lower.has_suffix(suffix))
}
