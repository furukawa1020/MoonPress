///|
fn rest_is_metadata(path : String) -> Bool {
  if path.has_prefix("/wp-json/wp/v2/statuses/") && !path[24:].is_empty() {
    return true
  }
  if ["/wp-json/wp/v2/statuses", "/wp-json/wp/v2/statuses/"].contains(path) {
    return true
  }
  [
    "/wp-json/wp/v2/types", "/wp-json/wp/v2/types/", "/wp-json/wp/v2/types/post",
    "/wp-json/wp/v2/types/page",
  ].contains(path)
}

///|
fn rest_metadata_collection(path : String) -> Bool {
  if ["/wp-json/wp/v2/statuses", "/wp-json/wp/v2/statuses/"].contains(path) {
    return true
  }
  ["/wp-json/wp/v2/types", "/wp-json/wp/v2/types/"].contains(path)
}

///|
fn rest_type_value(kind : String, context? : String = "view") -> Json {
  let fields : Map[String, Json] = Map([
    ("name", (if kind == "post" { "Posts" } else { "Pages" }).to_json()),
    ("slug", kind.to_json()),
    ("rest_base", (if kind == "post" { "posts" } else { "pages" }).to_json()),
    ("rest_namespace", "wp/v2".to_json()),
  ])
  if context != "embed" {
    fields["description"] = "".to_json()
  }
  if context == "edit" {
    fields["viewable"] = true.to_json()
  }
  Json::object(fields)
}

///|
fn rest_metadata(
  input_path : String,
  query : Map[String, String],
  principal : AccessPrincipal?,
) -> RestResponse raise {
  if input_path.has_prefix("/wp-json/wp/v2/statuses") {
    return rest_status_metadata(input_path, query, principal)
  }
  if query.keys().any(key => key != "context") ||
    !["view", "embed", "edit"].contains(query.get("context").unwrap_or("view")) {
    return rest_error(400, "rest_invalid_param")
  }
  if query.get("context") == Some("edit") {
    let user = match principal {
      Some(user) => user
      None => return rest_error(401, "rest_not_logged_in")
    }
    let values : Map[String, Json] = Map([])
    for kind in ["post", "page"] {
      let plural = if kind == "post" { "posts" } else { "pages" }
      if !role_capabilities(user.role).contains("edit_" + plural) {
        continue
      }
      let value = rest_type_value(kind, context="edit")
      if value is Object(fields) {
        fields["supports"] = {
          "title": true.to_json(),
          "editor": true.to_json(),
          "author": true.to_json(),
        }
        fields["capabilities"] = {
          "edit_posts": ("edit_" + plural).to_json(),
          "delete_posts": ("delete_" + plural).to_json(),
          "publish_posts": ("publish_" + plural).to_json(),
        }
      }
      values[kind] = value
    }
    if values.is_empty() {
      return rest_error(403, "rest_cannot_view")
    }
    if rest_metadata_collection(input_path) {
      return rest_ok(Json::object(values))
    }
    let kind = if input_path.has_suffix("/post") { "post" } else { "page" }
    return match values.get(kind) {
      Some(value) => rest_ok(value)
      None => rest_error(403, "rest_cannot_view")
    }
  }
  if rest_metadata_collection(input_path) {
    return rest_ok({
      "post": rest_type_value(
        "post",
        context=query.get("context").unwrap_or("view"),
      ),
      "page": rest_type_value(
        "page",
        context=query.get("context").unwrap_or("view"),
      ),
    })
  }
  if input_path == "/wp-json/wp/v2/types/post" {
    return rest_ok(
      rest_type_value("post", context=query.get("context").unwrap_or("view")),
    )
  }
  if input_path == "/wp-json/wp/v2/types/page" {
    return rest_ok(
      rest_type_value("page", context=query.get("context").unwrap_or("view")),
    )
  }
  rest_error(404, "rest_no_route")
}

///|
fn rest_project_keyed(value : Json, fields : Array[String]) -> Json {
  let result : Map[String, Json] = Map([])
  if value is Object(items) {
    for name, item in items {
      result[name] = rest_project(item, fields, collection=false)
    }
  }
  Json::object(result)
}

///|
fn rest_metadata_options(
  path : String,
  query : Map[String, String],
) -> RestResponse {
  if path.has_prefix("/wp-json/wp/v2/statuses") {
    return rest_status_options(query)
  }
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let properties : Map[String, Json] = Map([])
  for
    name in [
      "name", "slug", "description", "rest_base", "rest_namespace", "viewable",
    ] {
    properties[name] = {
      "type": (if name == "viewable" { "boolean" } else { "string" }).to_json(),
      "readonly": true.to_json(),
    }
  }
  properties["viewable"] = {
    "type": "boolean".to_json(),
    "readonly": true.to_json(),
    "context": ["edit"].to_json(),
  }
  for name in ["supports", "capabilities"] {
    properties[name] = {
      "type": "object".to_json(),
      "readonly": true.to_json(),
      "context": ["edit"].to_json(),
    }
  }
  rest_ok({
    "namespace": "wp/v2".to_json(),
    "methods": ["GET", "HEAD", "OPTIONS"].to_json(),
    "endpoints": [
      {
        "methods": ["GET"].to_json(),
        "args": {
          "context": {
            "type": "string".to_json(),
            "enum": ["view", "embed", "edit"].to_json(),
            "default": "view".to_json(),
          },
        },
      },
      {
        "methods": ["HEAD"].to_json(),
        "args": {
          "context": {
            "type": "string".to_json(),
            "enum": ["view", "embed", "edit"].to_json(),
            "default": "view".to_json(),
          },
        },
      },
      { "methods": ["OPTIONS"].to_json(), "args": Json::object(Map([])) },
    ].to_json(),
    "schema": {
      "type": "object".to_json(),
      "properties": Json::object(properties),
    },
    "moonpress": {
      "subset": true.to_json(),
      "collection": rest_metadata_collection(path).to_json(),
    },
  })
}
