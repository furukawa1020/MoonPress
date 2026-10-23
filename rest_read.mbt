///|
priv struct RestResponse {
  location : String?
  etag : String?
  code : Int
  value : Json
  total : Int?
  pages : Int?
}

///|
fn rest_error(code : Int, label : String) -> RestResponse {
  {
    location: None,
    etag: None,
    code,
    value: {
      "code": label.to_json(),
      "message": "Request unavailable or unsupported.".to_json(),
      "data": { "status": code.to_json() },
    },
    total: None,
    pages: None,
  }
}

///|
fn rest_ok(
  value : Json,
  etag? : String? = None,
  location? : String? = None,
) -> RestResponse {
  { location, etag, code: 200, value, total: None, pages: None, }
}

///|
fn rest_target(target : String) -> (String, Map[String, String]) raise {
  if target.length() > 2048 ||
    !target.has_prefix("/wp-json") ||
    target.contains("#") {
    raise InvalidInput("Invalid REST target")
  }
  let (path, text) = match target.split_once("?") {
    Some((path, text)) => (path.to_owned(), text.to_owned())
    None => (target, "")
  }
  let query : Map[String, String] = Map([])
  if !text.is_empty() {
    for pair in text.split("&") {
      let (key, value) = match pair.split_once("=") {
        Some((key, value)) =>
          (admin_decode(key.to_owned()), admin_decode(value.to_owned()))
        None => raise InvalidInput("Expected query key=value")
      }
      if query.contains(key) {
        raise InvalidInput("Duplicate REST query parameter")
      }
      query[key] = value
    }
  }
  (path, query)
}

///|
fn rest_post_value(document : Document, stem : String, base : String) -> Json {
  let date = match document.publish_at {
    Some(value) => value[:19].to_owned()
    None => document.date.unwrap_or("1970-01-01") + "T00:00:00"
  }
  {
    "id": document.wp_id.unwrap().to_json(),
    "date": date.to_json(),
    "date_gmt": date.to_json(),
    "slug": document.slug.unwrap_or(stem).to_json(),
    "status": "publish".to_json(),
    "type": document.kind.to_json(),
    "link": (base + url_component(document.slug.unwrap_or(stem) + ".html")).to_json(),
    "title": { "rendered": escape_html(document.title).to_json() },
    "content": {
      "rendered": render_markdown(document.body).to_json(),
      "protected": false.to_json(),
    },
    "excerpt": {
      "rendered": ("<p>" + escape_html(document.description) + "</p>\n").to_json(),
      "protected": false.to_json(),
    },
    "author": document.author.to_json(),
  }
}

///|
priv struct RestPost {
  document : Document
  digest : String
  stem : String
}

///|
fn rest_all_posts_at(
  input : String,
  directory : AuthoringDirectory,
  unassigned? : Bool = false,
) -> Array[RestPost] raise {
  let names = post_names(input)
  if names.length() > 4096 {
    raise InvalidInput("REST source count exceeds limit")
  }
  let posts : Array[RestPost] = []
  let ids : Map[Int, Bool] = Map([])
  let mut total = 0
  for name in names {
    if !name.has_suffix(".md") {
      continue
    }
    require_post_name(name)
    let bytes = directory.read(name, max_bytes=4194304)
    total += bytes.length()
    if total > 16777216 {
      raise InvalidInput("REST source total exceeds 16 MiB")
    }
    let stem = name[:name.length() - 3].to_owned()
    let document = parse_document(decode_text(bytes, name), stem, filename=name)
    if document.wp_id is Some(id) {
      if ids.contains(id) {
        raise InvalidInput("Duplicate native REST identity")
      }
      ids[id] = true
    }
    if document.wp_id is None && !unassigned {
      if !document.draft &&
        document.listed &&
        publication_due(document.publish_at, authoring_time()) {
        raise InvalidInput("Public source requires wp_id")
      }
      continue
    }
    posts.push({ document, digest: digest_bytes(bytes), stem, })
  }
  posts
}

///|
fn rest_public_posts(input : String) -> Array[RestPost] raise {
  let directory = open_authoring_subdirectory(input, "content")
  defer directory_close(directory.fd)
  directory.lock()
  let instant = authoring_time()
  let posts : Array[RestPost] = []
  for post in rest_all_posts_at(input, directory) {
    if !post.document.draft &&
      post.document.listed &&
      publication_due(post.document.publish_at, instant) {
      posts.push(post)
    }
  }
  posts
}

///|
fn rest_route(
  input : String,
  path : String,
  query : Map[String, String],
  base : String,
  principal : AccessPrincipal?,
) -> RestResponse raise {
  if path == "/wp-json/" || path == "/wp-json" {
    if !query.is_empty() {
      return rest_error(400, "rest_invalid_param")
    }
    let route : Json = {
      "namespace": "wp/v2".to_json(),
      "methods": ["GET", "HEAD", "OPTIONS"].to_json(),
    }
    let create_route : Json = {
      "namespace": "wp/v2".to_json(),
      "methods": ["GET", "HEAD", "POST", "OPTIONS"].to_json(),
    }
    let edit_route : Json = {
      "namespace": "wp/v2".to_json(),
      "methods": ["GET", "HEAD", "POST", "DELETE", "OPTIONS"].to_json(),
    }
    return rest_ok({
      "name": "MoonPress".to_json(),
      "url": base.to_json(),
      "namespaces": ["wp/v2"].to_json(),
      "authentication": {
        "moonpress-generated-basic": {
          "moonpress_generated_only": true.to_json(),
        },
      },
      "routes": {
        "/wp/v2/posts": create_route,
        "/wp/v2/pages": create_route,
        "/wp/v2/posts/(?P<id>[0-9]+)": edit_route,
        "/wp/v2/pages/(?P<id>[0-9]+)": edit_route,
        "/wp/v2/users/me": route,
        "/wp/v2/search": route,
      },
      "moonpress": {
        "read_only": false.to_json(),
        "contexts": ["view", "edit"].to_json(),
        "unsupported": [
          "force-delete", "taxonomy-ids", "embeds", "xml-rpc", "php-plugins",
        ].to_json(),
      },
    })
  }
  if path == "/wp-json/wp/v2/search" {
    return rest_search(input, query, base)
  }
  if path == "/wp-json/wp/v2/users/me" {
    for key, value in query {
      if key != "context" || (value != "view" && value != "edit") {
        return rest_error(400, "rest_invalid_param")
      }
    }
    let user = match principal {
      Some(user) => user
      None => return rest_error(401, "rest_not_logged_in")
    }
    let fields : Map[String, Json] = Map([
      ("id", user.id.to_json()),
      ("name", user.login.to_json()),
      ("slug", user.login.to_json()),
    ])
    if query.get("context") == Some("edit") {
      let capabilities : Map[String, Json] = Map([])
      for capability in role_capabilities(user.role) {
        capabilities[capability] = true.to_json()
      }
      fields["username"] = user.login.to_json()
      fields["roles"] = [user.role].to_json()
      fields["capabilities"] = Json::object(capabilities)
    }
    return rest_ok(Json::object(fields))
  }
  let (kind, tail) = if path == "/wp-json/wp/v2/posts" {
    ("post", "")
  } else if path == "/wp-json/wp/v2/pages" {
    ("page", "")
  } else if path.has_prefix("/wp-json/wp/v2/posts/") {
    ("post", path[21:].to_owned())
  } else if path.has_prefix("/wp-json/wp/v2/pages/") {
    ("page", path[21:].to_owned())
  } else {
    return rest_error(404, "rest_no_route")
  }
  rest_validate_collection(query, false)
  if !tail.is_empty() && query.keys().any(key => key != "context") {
    return rest_error(400, "rest_invalid_param")
  }
  let id = if tail.is_empty() {
    None
  } else {
    Some(rest_positive(tail, 2147483647))
  }
  let available = rest_public_posts(input) catch {
    _ => return rest_error(500, "moonpress_content_unavailable")
  }
  let posts = rest_filter_posts(
    available.filter(post => post.document.kind == kind),
    query,
  )
  if id is Some(id) {
    for post in posts {
      if post.document.wp_id == Some(id) {
        return rest_ok(rest_post_value(post.document, post.stem, base))
      }
    }
    return rest_error(404, "rest_post_invalid_id")
  }
  rest_collection_result(posts, query, base, false)
}
