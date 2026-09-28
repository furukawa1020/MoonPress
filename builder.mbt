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
  changes : Array[BuildEvent]
} derive(ToJson)

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
  let state = parse_manifest(read_text(marker))
  for artifact in state.artifacts {
    result[artifact.name] = artifact
  }
  // Refuse unknown files and edited outputs before ANY writes or deletions.
  for name in @fs.read_dir(output) {
    if name == ".moonpress-stage" {
      raise InvalidInput(
        "Output contains an unfinished or foreign staging entry; use a fresh output directory: " +
        output,
      )
    }
    let file = output + "/" + name
    if path_kind(file) != 1 {
      raise InvalidInput("Output contains a non-regular file: " + name)
    }
    if name != ".moonpress.json" {
      match result.get(name) {
        None => raise InvalidInput("Unmanaged output file: " + name)
        Some(artifact) =>
          if digest_bytes(read_bytes(file)) != artifact.digest {
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
  output : String?,
  render : () -> Bytes,
  log : BuildLog,
) -> Pending raise {
  if !safe_output_name(name) {
    raise InvalidInput("Invalid output name: " + name)
  }
  let old = previous.get(name)
  let reason = match rebuild_reason(old, dependencies) {
    Some(reason) => Some(reason)
    None =>
      match output {
        Some(directory) =>
          if path_kind(directory + "/" + name) == 0 {
            Some("output missing")
          } else {
            None
          }
        None => Some("validation only")
      }
  }
  if reason is None && old is Some(artifact) {
    record_event(log, "keep", name, "dependencies unchanged")
    return { artifact, content: None, }
  }
  let content = render()
  let artifact : Artifact = {
    name,
    digest: digest_bytes(content),
    dependencies,
  }
  record_event(log, "write", name, reason.unwrap_or("dependency changed"))
  { artifact, content: Some(content), }
}

///|
priv struct BuildPlan {
  pending : Array[Pending]
  removed : Array[String]
  manifest : String
  report : BuildReport
}

///|
pub fn compile_site(
  input : String,
  output : String,
  dry_run? : Bool = false,
  include_drafts? : Bool = false,
) -> BuildReport raise {
  let output = output.trim_end(chars="/").to_owned()
  if output.is_empty() {
    raise InvalidInput("Root output directory is not allowed")
  }
  let lock = lock_output(output, shared=dry_run)
  defer native_unlock_output(lock)
  let previous = load_previous(output)
  let plan = plan_site(input, previous, Some(output), include_drafts~)
  if !dry_run {
    apply_plan(output, plan)
  }
  plan.report
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
  let base_url = read_base_url(input)
  let layout = read_text(input + "/layout.html")
  if !layout.contains("{{content}}") {
    raise InvalidInput("layout.html must contain {{content}}")
  }
  let css = read_bytes(input + "/style.css")
  let names = @fs.read_dir(input + "/content").to_owned()
  names.sort()
  let pending : Array[Pending] = []
  let log : BuildLog = { events: [], changes: [], }
  let documents : Array[Page] = []
  let mut pages = 0
  let layout_digest = digest_text(layout)
  let compiler_digest = digest_text("moonpress-renderer-v10")
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
          log,
        ),
      )
      pages += 1
    }
  }
  if pages == 0 {
    raise InvalidInput("No published .md pages found")
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
      log,
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
fn apply_plan(output : String, plan : BuildPlan) -> Unit raise {
  let fresh = path_kind(output) == 0
  let marker = output + "/.moonpress.json"
  let manifest_changed = fresh || read_text(marker) != plan.manifest
  if plan.report.written == 0 && plan.removed.is_empty() && !manifest_changed {
    return
  }
  if fresh {
    @fs.create_dir(output)
  }
  let stage = output + "/.moonpress-stage"
  // mkdir must succeed exclusively before this build owns the staging area.
  @fs.create_dir(stage) catch {
    error => {
      if fresh {
        @fs.remove_dir(output) catch {
          _ => ()
        }
      }
      let cause : Error = error
      raise InvalidInput(
        "Cannot create staging directory " + stage + ": \{cause}",
      )
    }
  }
  let staged : Array[String] = []
  let mut publishing = false
  try {
    for item in plan.pending {
      if item.content is Some(bytes) {
        staged.push(item.artifact.name)
        write_bytes(stage + "/" + item.artifact.name, bytes)
      }
    }
    if manifest_changed {
      staged.push(".moonpress.json")
      write_text(stage + "/.moonpress.json", plan.manifest)
    }
    publishing = true
    for item in plan.pending {
      if item.content is Some(_) {
        replace_staged_file(
          stage + "/" + item.artifact.name,
          output + "/" + item.artifact.name,
        )
      }
    }
    for name in plan.removed {
      if path_kind(output + "/" + name) == 1 {
        @fs.remove_file(output + "/" + name)
      }
    }
    if manifest_changed {
      replace_staged_file(stage + "/.moonpress.json", marker)
    }
    cleanup_stage(stage, staged)
  } catch {
    error => {
      let cleaned = try {
        cleanup_stage(stage, staged)
        if fresh && !publishing {
          @fs.remove_dir(output)
        }
        true
      } catch {
        _ => false
      }
      let phase = if publishing {
        "Publication failed; output may be partially updated; rebuild into a fresh directory"
      } else {
        "Staging failed before existing artifacts were changed"
      }
      let cleanup = if cleaned { "" } else { "; staging cleanup incomplete" }
      raise InvalidInput(phase + " for " + output + ": \{error}" + cleanup)
    }
  }
}

///|
fn cleanup_stage(stage : String, names : Array[String]) -> Unit raise {
  for name in names {
    let path = stage + "/" + name
    if path_kind(path) == 1 {
      @fs.remove_file(path)
    }
  }
  // Never recursively delete unknown entries.
  @fs.remove_dir(stage)
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

///|
pub(all) struct CheckReport {
  pages : Int
  outputs : Int
} derive(ToJson)

///|
pub fn check_site(
  input : String,
  include_drafts? : Bool = false,
) -> CheckReport raise {
  // No output path, prior manifest, temporary directory, or filesystem mutation.
  let plan = plan_site(input, Map([]), None, include_drafts~)
  { pages: plan.report.pages, outputs: plan.pending.length(), }
}

///|
pub(all) struct BuildEvent {
  action : String
  path : String
  reason : String
} derive(ToJson)

///|
priv struct BuildLog {
  events : Array[String]
  changes : Array[BuildEvent]
}

///|
fn record_event(
  log : BuildLog,
  action : String,
  path : String,
  reason : String,
) -> Unit {
  log.changes.push({ action, path, reason, })
  log.events.push(action.to_upper() + " " + path + " — " + reason)
}

///|
pub extend BuildEvent with ToJson::{to_json}

///|
pub extend BuildReport with ToJson::{to_json}

///|
pub extend CheckReport with ToJson::{to_json}

///|
fn require_input_kind(path : String, expected : Int) -> Unit raise {
  if path_kind(path) != expected {
    let kind = if expected == 2 { "directory" } else { "file" }
    raise InvalidInput(
      "Expected regular input " +
      kind +
      " (no symlinks or special files): " +
      path,
    )
  }
}
