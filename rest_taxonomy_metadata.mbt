///|
fn rest_taxonomies_collection(path : String) -> Bool {
  ["/wp-json/wp/v2/taxonomies", "/wp-json/wp/v2/taxonomies/"].contains(path)
}

///|
fn rest_is_taxonomies(path : String) -> Bool {
  rest_taxonomies_collection(path) ||
  path.has_prefix("/wp-json/wp/v2/taxonomies/")
}

///|
fn rest_taxonomy_value(kind : String, context : String) -> Json {
  let category = kind == "category"
  let value : Json = {
    "name": (if category { "Categories" } else { "Tags" }).to_json(),
    "slug": kind.to_json(),
    "rest_base": (if category { "categories" } else { "tags" }).to_json(),
    "rest_namespace": "wp/v2".to_json(),
  }
  if context != "embed" && value is Object(fields) {
    fields["description"] = "".to_json()
    fields["types"] = ["post"].to_json()
  }
  value
}

///|
fn rest_taxonomies(path : String, query : Map[String, String]) -> RestResponse {
  if query.keys().any(key => !["context", "type"].contains(key)) ||
    !["view", "embed"].contains(query.get("context").unwrap_or("view")) ||
    (query.contains("type") && !["post", "page"].contains(query["type"])) {
    return rest_error(400, "rest_invalid_param")
  }
  if !rest_taxonomies_collection(path) {
    if query.contains("type") {
      return rest_error(400, "rest_invalid_param")
    }
    let kind = path[26:].trim_end(chars="/").to_owned()
    if !["category", "post_tag"].contains(kind) {
      return rest_error(404, "rest_taxonomy_invalid")
    }
    return rest_ok(
      rest_taxonomy_value(kind, query.get("context").unwrap_or("view")),
    )
  }
  let values : Map[String, Json] = Map([])
  if query.get("type") != Some("page") {
    for kind in ["category", "post_tag"] {
      values[kind] = rest_taxonomy_value(
        kind,
        query.get("context").unwrap_or("view"),
      )
    }
  }
  rest_ok(Json::object(values))
}
