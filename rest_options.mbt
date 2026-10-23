///|
fn rest_methods(path : String) -> Array[String]? {
  if rest_is_collection(path) {
    return Some(["GET", "HEAD", "POST", "OPTIONS"])
  }
  if [
      "/wp-json", "/wp-json/", "/wp-json/wp/v2/users/me", "/wp-json/wp/v2/search",
      "/wp-json/wp/v2/search/",
    ].contains(path) {
    return Some(["GET", "HEAD", "OPTIONS"])
  }
  for prefix in ["/wp-json/wp/v2/posts/", "/wp-json/wp/v2/pages/"] {
    if path.has_prefix(prefix) {
      let id = path[prefix.length():].to_owned()
      let valid = try rest_positive(id, 2147483647) > 0 catch {
        _ => false
      }
      if valid {
        return Some(["GET", "HEAD", "POST", "DELETE", "OPTIONS"])
      }
    }
  }
  None
}

///|
fn rest_options(path : String, query : Map[String, String]) -> RestResponse {
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let verbs = match rest_methods(path) {
    Some(verbs) => verbs
    None => return rest_error(404, "rest_no_route")
  }
  let article = path.has_prefix("/wp-json/wp/v2/posts") ||
    path.has_prefix("/wp-json/wp/v2/pages")
  let properties : Map[String, Json] = Map([])
  if article {
    properties["id"] = {
      "type": "integer".to_json(),
      "readonly": true.to_json(),
    }
    properties["author"] = {
      "type": "integer".to_json(),
      "readonly": true.to_json(),
    }
    for name in ["moonpress_categories", "moonpress_tags"] {
      properties[name] = {
        "type": "array".to_json(),
        "items": { "type": "string".to_json() },
      }
    }
    for
      field in [
        "date", "date_gmt", "slug", "status", "type", "link", "moonpress_revision",
      ] {
      properties[field] = {
        "type": "string".to_json(),
        "readonly": ["date", "type", "link", "moonpress_revision"]
        .contains(field)
        .to_json(),
      }
    }
    for field in ["title", "content", "excerpt"] {
      properties[field] = {
        "type": "object".to_json(),
        "properties": {
          "rendered": { "type": "string".to_json(), "readonly": true.to_json() },
          "raw": { "type": "string".to_json(), "context": ["edit"].to_json() },
        },
      }
    }
  }
  if path == "/wp-json/wp/v2/users/me" {
    for name in ["id", "name", "slug", "username", "roles", "capabilities"] {
      properties[name] = {
        "readonly": true.to_json(),
        "type": (match name {
          "id" => "integer"
          "roles" => "array"
          "capabilities" => "object"
          _ => "string"
        }).to_json(),
        "context": (if ["username", "roles", "capabilities"].contains(name) {
          ["edit"]
        } else {
          ["view", "edit"]
        }).to_json(),
      }
    }
  }
  if rest_is_search(path) {
    for name in ["id", "title", "url", "type", "subtype"] {
      properties[name] = {
        "readonly": true.to_json(),
        "type": (if name == "id" { "integer" } else { "string" }).to_json(),
      }
    }
  }
  let endpoints : Array[Json] = []
  for verb in verbs {
    let args : Map[String, Json] = Map([])
    if (verb == "GET" || verb == "HEAD") &&
      path != "/wp-json" &&
      path != "/wp-json/" {
      args["context"] = {
        "type": "string".to_json(),
        "enum": ["view", "edit"].to_json(),
        "default": "view".to_json(),
      }
      if rest_is_search(path) {
        args["context"] = {
          "type": "string".to_json(),
          "enum": ["view", "embed"].to_json(),
          "default": "view".to_json(),
        }
        for name in ["page", "per_page"] {
          args[name] = { "type": "integer".to_json() }
        }
        for name in ["search", "include", "exclude", "type", "subtype"] {
          args[name] = { "type": "string".to_json() }
        }
      }
      if rest_is_collection(path) {
        for name in ["page", "per_page", "offset"] {
          args[name] = { "type": "integer".to_json() }
        }
        for
          name in [
            "search", "slug", "include", "exclude", "author", "author_exclude", "status",
            "order", "orderby",
          ] {
          args[name] = { "type": "string".to_json() }
        }
      }
    }
    if verb == "POST" && article {
      for name in ["moonpress_categories", "moonpress_tags"] {
        args[name] = {
          "type": "array".to_json(),
          "items": { "type": "string".to_json() },
        }
      }
      for name in ["title", "content", "excerpt", "status", "date_gmt"] {
        args[name] = {
          "type": "string".to_json(),
          "required": (name == "title" && rest_is_collection(path)).to_json(),
        }
      }
    }
    if verb == "POST" && article {
      args["slug"] = { "type": "string".to_json() }
    }
    if verb == "DELETE" {
      args["force"] = {
        "type": "boolean".to_json(),
        "enum": [false].to_json(),
        "default": false.to_json(),
      }
    }
    endpoints.push({ "methods": [verb].to_json(), "args": Json::object(args) })
  }
  rest_ok({
    "namespace": "wp/v2".to_json(),
    "methods": verbs.to_json(),
    "endpoints": endpoints.to_json(),
    "schema": {
      "type": "object".to_json(),
      "properties": Json::object(properties),
    },
    "moonpress": {
      "subset": true.to_json(),
      "json_body_limit": (262144).to_json(),
      "update_delete_requires_if_match": true.to_json(),
      "permanent_delete": false.to_json(),
      "named_term_arrays": true.to_json(),
    },
  })
}
