///|
fn native_parts(path : String) -> Array[String] {
  let prefix = "/wp-json/moonpress/v1/"
  if !path.has_prefix(prefix) {
    return []
  }
  path[prefix.length():]
  .trim_end(chars="/")
  .split("/")
  .map(s => s.to_owned())
  .to_array()
}

///|
fn native_history_target(path : String) -> (String, Int, String?)? {
  let parts = native_parts(path)
  if (
      parts.length() != 3 &&
      parts.length() != 4 &&
      !(parts.length() == 5 && parts[4] == "restore")
    ) ||
    !["posts", "pages"].contains(parts[0]) ||
    parts[2] != "history" {
    return None
  }
  let id = rest_positive(parts[1], 2147483647) catch { _ => return None }
  if parts.length() >= 4 {
    require_record_id(parts[3]) catch {
      _ => return None
    }
  }
  Some(
    (
      if parts[0] == "posts" {
        "post"
      } else {
        "page"
      },
      id,
      if parts.length() >= 4 {
        Some(parts[3])
      } else {
        None
      },
    ),
  )
}

///|
fn native_rest_methods(path : String) -> Array[String]? {
  if native_comment_summary_path(path) {
    return Some(["GET", "HEAD", "OPTIONS"])
  }
  if native_taxonomy(path) is Some(_) {
    return Some(["GET", "HEAD", "OPTIONS"])
  }
  if native_settings_path(path) {
    return Some(["GET", "HEAD", "POST", "OPTIONS"])
  }
  if native_comment_id(path) is Some(id) {
    return Some(
      if id == 0 {
        ["GET", "HEAD", "POST", "OPTIONS"]
      } else {
        ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
      },
    )
  }
  if native_media_name(path) is Some(_) {
    return Some(["GET", "HEAD", "POST", "OPTIONS"])
  }
  if native_history_target(path) is Some(_) {
    if native_parts(path).length() == 5 {
      return Some(["POST", "OPTIONS"])
    }
    return Some(["GET", "HEAD", "OPTIONS"])
  }
  None
}

///|
fn native_rest_options(
  path : String,
  query : Map[String, String],
) -> RestResponse {
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  match native_rest_methods(path) {
    Some(methods) =>
      rest_ok({
        "namespace": "moonpress/v1".to_json(),
        "methods": methods.to_json(),
        "moonpress": {
          "generated_credentials": true.to_json(),
          "native_workflow": true.to_json(),
        },
      })
    None => rest_error(404, "rest_no_route")
  }
}

///|
fn rest_native(
  input : String,
  path : String,
  query : Map[String, String],
  base : String,
  request : AdminRequest,
  body : Bytes,
) -> RestResponse raise {
  if native_rest_methods(path) is None {
    return rest_error(404, "rest_no_route")
  }
  if request.verb == "OPTIONS" && request.authorization is None {
    return native_rest_options(path, query)
  }
  if native_taxonomy(path) is Some(kind) &&
    request.authorization is None &&
    (request.verb == "GET" || request.verb == "HEAD") {
    let content = open_authoring_subdirectory(input, "content")
    defer directory_close(content.fd)
    content.lock()
    return native_taxonomy_read(input, content, kind, query)
  }
  if native_comment_id(path) is Some(id) &&
    request.authorization is None &&
    (request.verb == "GET" || request.verb == "HEAD") {
    let content = open_authoring_subdirectory(input, "content")
    defer directory_close(content.fd)
    content.lock()
    return native_comments_read(input, content, None, id, query)
  }
  rest_with_access(input, request.authorization, fn(principal, content) raise {
    if request.verb == "OPTIONS" {
      return native_rest_options(path, query)
    }
    if native_comment_summary_path(path) {
      return native_comment_summary(input, content, principal, query)
    }
    if native_taxonomy(path) is Some(kind) {
      return native_taxonomy_read(input, content, kind, query)
    }
    if native_settings_path(path) {
      if request.verb == "POST" {
        return native_settings_save(
          input,
          content,
          principal,
          query,
          request.if_match,
          body,
        )
      }
      return native_settings_read(input, content, principal, query)
    }
    if native_comment_id(path) is Some(id) {
      if ["POST", "PUT", "PATCH", "DELETE"].contains(request.verb) && id > 0 {
        return native_comment_moderate(
          input,
          content,
          principal,
          id,
          query,
          request.if_match,
          body,
          request.verb,
        )
      }
      if request.verb == "POST" {
        return native_comment_create(input, content, principal, query, body)
      }
      return native_comments_read(input, content, Some(principal), id, query)
    }
    if native_media_name(path) is Some(name) {
      if request.verb == "POST" && !name.is_empty() {
        return native_media_replace(
          input,
          content,
          principal,
          name,
          query,
          base,
          request.if_match,
          body,
        )
      }
      if request.verb == "POST" {
        return native_media_upload(input, content, principal, query, base, body)
      }
      return native_media_read(input, content, principal, name, query, base)
    }
    match native_history_target(path) {
      Some((kind, id, record)) =>
        if native_parts(path).length() == 5 {
          native_history_restore(
            input,
            content,
            principal,
            kind,
            id,
            record.unwrap(),
            query,
            base,
            request.if_match,
            body,
          )
        } else {
          native_history_read(
            input, content, principal, kind, id, record, query, base,
          )
        }
      None => rest_error(404, "rest_no_route")
    }
  })
}

///|
fn rest_precondition(value : String?, current : String) -> RestResponse? {
  let text = match value {
    Some(text) => text
    None => return Some(rest_error(428, "moonpress_precondition_required"))
  }
  if text.length() < 3 ||
    text.length() > 66 ||
    !text.has_prefix("\"") ||
    !text.has_suffix("\"") {
    return Some(rest_error(400, "moonpress_invalid_precondition"))
  }
  let digest = text[1:text.length() - 1].to_owned()
  if digest != "absent" && !valid_digest(digest) {
    return Some(rest_error(400, "moonpress_invalid_precondition"))
  }
  if digest != current {
    return Some(rest_error(412, "moonpress_source_changed"))
  }
  None
}

///|
fn native_discovery_routes(value : Json) -> Json {
  if value is Object(routes) {
    routes["/moonpress/v1/comments/summary"] = {
      "namespace": "moonpress/v1".to_json(),
      "methods": ["GET", "HEAD", "OPTIONS"].to_json(),
    }
    routes["/moonpress/v1/tags"] = {
      "namespace": "moonpress/v1".to_json(),
      "methods": ["GET", "HEAD", "OPTIONS"].to_json(),
    }
    routes["/moonpress/v1/categories"] = {
      "namespace": "moonpress/v1".to_json(),
      "methods": ["GET", "HEAD", "OPTIONS"].to_json(),
    }
    routes["/moonpress/v1/settings"] = {
      "namespace": "moonpress/v1".to_json(),
      "methods": ["GET", "HEAD", "POST", "OPTIONS"].to_json(),
    }
    routes["/moonpress/v1/comments"] = {
      "namespace": "moonpress/v1".to_json(),
      "methods": ["GET", "HEAD", "POST", "OPTIONS"].to_json(),
    }
    routes["/moonpress/v1/comments/(?P<id>[0-9]+)"] = {
      "namespace": "moonpress/v1".to_json(),
      "methods": native_rest_methods("/wp-json/moonpress/v1/comments/1")
      .unwrap()
      .to_json(),
    }
    for path in ["/moonpress/v1/media", "/moonpress/v1/media/(?P<name>[^/]+)"] {
      routes[path] = {
        "namespace": "moonpress/v1".to_json(),
        "methods": ["GET", "HEAD", "POST", "OPTIONS"].to_json(),
      }
    }
    for kind in ["posts", "pages"] {
      let path = "/moonpress/v1/" + kind + "/(?P<id>[0-9]+)/history"
      let descriptor : Json = {
        "namespace": "moonpress/v1".to_json(),
        "methods": ["GET", "HEAD", "OPTIONS"].to_json(),
      }
      routes[path + "/(?P<revision>[a-f0-9-]+\\.json)/restore"] = {
        "namespace": "moonpress/v1".to_json(),
        "methods": ["POST", "OPTIONS"].to_json(),
      }
      routes[path] = descriptor
      routes[path + "/(?P<revision>[a-f0-9-]+\\.json)"] = descriptor
    }
  }
  value
}
