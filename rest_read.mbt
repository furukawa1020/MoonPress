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
  let (raw_path, text) = match target.split_once("?") {
    Some((path, text)) => (path.to_owned(), text.to_owned())
    None => (target, "")
  }
  let path = if raw_path.has_suffix("/") {
    let candidate = raw_path[:raw_path.length() - 1].to_owned()
    let item = rest_edit_target(candidate) catch { _ => None }
    if item is Some(_) {
      candidate
    } else {
      raw_path
    }
  } else {
    raw_path
  }
  let array_counts : Map[String, Int] = Map([])
  let query : Map[String, String] = Map([])
  if !text.is_empty() {
    for pair in text.split("&") {
      let (key, value) = match pair.split_once("=") {
        Some((key, value)) =>
          (admin_decode(key.to_owned()), admin_decode(value.to_owned()))
        None => raise InvalidInput("Expected query key=value")
      }
      if key.contains("[") {
        let (name, suffix) = match key.split_once("[") {
          Some((name, suffix)) => (name.to_owned(), suffix.to_owned())
          None => raise InvalidInput("Invalid array query")
        }
        if ![
            "include", "exclude", "author", "author_exclude", "post", "slug", "status",
            "search_columns", "_fields", "subtype", "parent", "parent_exclude", "categories",
            "tags", "categories_exclude", "tags_exclude", "mime_type", "media_type",
          ].contains(name) ||
          !suffix.has_suffix("]") {
          raise InvalidInput("Unsupported array query")
        }
        let count = array_counts.get(name).unwrap_or(0)
        if count >= 100 || (count == 0 && query.contains(name)) {
          raise InvalidInput("Mixed or oversized array query")
        }
        let index = suffix[:suffix.length() - 1].to_owned()
        if !index.is_empty() && index != count.to_string() {
          raise InvalidInput(
            "Array indices must be contiguous in request order",
          )
        }
        if value.is_empty() {
          raise InvalidInput("Empty array element")
        }
        query[name] = if count == 0 { value } else { query[name] + "," + value }
        array_counts[name] = count + 1
      } else {
        if query.contains(key) {
          raise InvalidInput("Duplicate REST query parameter")
        }
        query[key] = value
      }
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
  rest_article_term_ids(
    {
      "_links": rest_article_links(document, base),
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
      "moonpress_categories": document.categories.to_json(),
      "moonpress_tags": document.tags.to_json(),
    },
    document,
  )
}

///|
priv struct RestPost {
  document : Document
  digest : String
  stem : String
}

///|
fn rest_all_posts_at(
  _input : String,
  directory : AuthoringDirectory,
  unassigned? : Bool = false,
) -> Array[RestPost] raise {
  let names = directory.names()
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
  rest_validate_term_inventory(posts)
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
  if rest_wp_media_target(path) is Some(_) {
    return rest_wp_media(input, path, query, base)
  }
  if rest_wp_term_target(path) is Some(_) {
    return rest_wp_terms(input, path, query, base)
  }
  if rest_wp_comment_id(path) is Some(_) {
    return rest_wp_comments(input, path, query, base, principal~) catch {
      _ => rest_error(500, "moonpress_comments_unavailable")
    }
  }
  if rest_is_users(path) {
    return rest_users(input, path, query)
  }
  if rest_is_metadata(path) {
    return rest_metadata(path, query, principal)
  }
  if path == "/wp-json/wp/v2" || path == "/wp-json/wp/v2/" {
    if query.keys().any(key => key != "context") ||
      (query.contains("context") && query.get("context") != Some("view")) {
      return rest_error(400, "rest_invalid_param")
    }
    let index = rest_route(input, "/wp-json/", Map([]), base, principal)
    let routes : Map[String, Json] = Map([])
    if index.value is Object(root) &&
      root.get("routes") is Some(Object(registered)) {
      for key, value in registered {
        if key.has_prefix("/wp/v2/") {
          routes[key] = value
        }
      }
    }
    return rest_ok({
      "namespace": "wp/v2".to_json(),
      "routes": Json::object(routes),
    })
  }
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
      "methods": ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"].to_json(),
    }
    return rest_ok({
      "name": "MoonPress".to_json(),
      "url": base.to_json(),
      "namespaces": ["wp/v2", "moonpress/v1"].to_json(),
      "authentication": {
        "moonpress-generated-basic": {
          "moonpress_generated_only": true.to_json(),
        },
      },
      "routes": native_discovery_routes({
        "/wp/v2/posts": create_route,
        "/wp/v2/pages": create_route,
        "/wp/v2/posts/(?P<id>[0-9]+)": edit_route,
        "/wp/v2/pages/(?P<id>[0-9]+)": edit_route,
        "/wp/v2/users/me": route,
        "/wp/v2/users": route,
        "/wp/v2/comments": create_route,
        "/wp/v2/comments/(?P<id>[0-9]+)": {
          "namespace": "wp/v2".to_json(),
          "methods": rest_methods("/wp-json/wp/v2/comments/1")
          .unwrap()
          .to_json(),
        },
        "/wp/v2/users/(?P<id>[0-9]+)": route,
        "/wp/v2/media": route,
        "/wp/v2/media/(?P<id>[0-9]+)": route,
        "/wp/v2/search": route,
        "/wp/v2/types": route,
        "/wp/v2/tags": route,
        "/wp/v2/tags/(?P<id>[0-9]+)": route,
        "/wp/v2/categories": route,
        "/wp/v2/categories/(?P<id>[0-9]+)": route,
        "/wp/v2/taxonomies": route,
        "/wp/v2/taxonomies/(?P<taxonomy>[a-z_]+)": route,
        "/wp/v2/statuses": route,
        "/wp/v2/statuses/(?P<status>[a-z]+)": route,
        "/wp/v2/types/post": route,
        "/wp/v2/types/page": route,
      }),
      "moonpress": {
        "read_only": false.to_json(),
        "contexts": ["view", "embed", "edit"].to_json(),
        "unsupported": [
          "force-delete", "taxonomy-writes", "embeds", "xml-rpc", "php-plugins",
        ].to_json(),
      },
    })
  }
  if rest_is_search(path) {
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
        return rest_ok(
          rest_article_context(
            rest_post_value(post.document, post.stem, base),
            query,
          ),
        )
      }
    }
    return rest_error(404, "rest_post_invalid_id")
  }
  rest_collection_result(posts, query, base, false)
}
