///|
pub(all) struct MediaUsage {
  item : MediaItem
  posts : Array[PostSummary]
} derive(ToJson)

///|
pub extend MediaUsage with ToJson::{to_json}

///|
pub(all) struct MediaReferences {
  assets : Array[MediaUsage]
  problems : Array[PostProblem]
  scope : String
} derive(ToJson)

///|
pub extend MediaReferences with ToJson::{to_json}

///|
fn media_routes(
  body : String,
  base_path : String,
  source : String,
) -> Map[String, Bool] raise {
  let (links, images) = block_references(parse_blocks(body))
  let routes : Map[String, Bool] = Map([])
  for href in links {
    if !allowed_href(href) {
      raise InvalidInput(source + ": disallowed link: " + href)
    }
    if local_route(href, base_path, source) is Some(route) {
      routes[route] = true
    }
  }
  for src in images {
    if !allowed_src(src) {
      raise InvalidInput(source + ": disallowed image: " + src)
    }
    if local_route(src, base_path, source) is Some(route) {
      routes[route] = true
    }
  }
  routes
}

///|
pub fn inspect_media_references(input : String) -> MediaReferences raise {
  let assets = list_media(input).items.map(item => { item, posts: [], })
  let config = read_site_config(input)
  let base_path = config.base_url.map(site_base_path).unwrap_or("/")
  let problems : Array[PostProblem] = []
  for name in post_names(input) {
    let source = "content/" + name
    try {
      require_input_kind(input + "/" + source, 1)
      if !name.has_suffix(".md") {
        continue
      }
      let stem = name[:name.length() - 3].to_owned()
      let document = parse_document(
        read_text(input + "/" + source),
        stem,
        filename=source,
      )
      let output = document.slug.unwrap_or(stem) + ".html"
      if !safe_output_name(output) {
        raise InvalidInput("Invalid output filename: " + output)
      }
      let post : PostSummary = {
        source,
        output,
        title: document.title,
        draft: document.draft,
        listed: document.listed,
        date: document.date,
        tags: document.tags,
      }
      let routes = media_routes(document.body, base_path, source)
      for asset in assets {
        if routes.contains(asset.item.url) {
          asset.posts.push(post)
        }
      }
    } catch {
      error => {
        let editable = try {
          let _ = read_post(input, name)
          true
        } catch {
          _ => false
        }
        problems.push({ source, message: error.to_string(), editable, })
      }
    }
  }
  {
    assets,
    problems,
    scope: "Supported article Markdown only, including drafts and unlisted posts. Templates, CSS and external URLs are excluded. An empty reference list is not proof that deletion is safe.",
  }
}
