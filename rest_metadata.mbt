///|
fn rest_is_metadata(path : String) -> Bool {
  [
    "/wp-json/wp/v2/types", "/wp-json/wp/v2/types/", "/wp-json/wp/v2/types/post",
    "/wp-json/wp/v2/types/page",
  ].contains(path)
}

///|
fn rest_metadata_collection(path : String) -> Bool {
  ["/wp-json/wp/v2/types", "/wp-json/wp/v2/types/"].contains(path)
}

///|
fn rest_type_value(kind : String) -> Json {
  {
    "name": (if kind == "post" { "Posts" } else { "Pages" }).to_json(),
    "slug": kind.to_json(),
    "description": "".to_json(),
    "rest_base": (if kind == "post" { "posts" } else { "pages" }).to_json(),
    "rest_namespace": "wp/v2".to_json(),
    "viewable": true.to_json(),
  }
}

///|
fn rest_metadata(
  input_path : String,
  query : Map[String, String],
  _principal : AccessPrincipal?,
) -> RestResponse {
  if query.keys().any(key => key != "context") ||
    !["view", "embed"].contains(query.get("context").unwrap_or("view")) {
    return rest_error(400, "rest_invalid_param")
  }
  if rest_metadata_collection(input_path) {
    return rest_ok({
      "post": rest_type_value("post"),
      "page": rest_type_value("page"),
    })
  }
  if input_path == "/wp-json/wp/v2/types/post" {
    return rest_ok(rest_type_value("post"))
  }
  if input_path == "/wp-json/wp/v2/types/page" {
    return rest_ok(rest_type_value("page"))
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
  rest_ok({
    "namespace": "wp/v2".to_json(),
    "methods": ["GET", "HEAD", "OPTIONS"].to_json(),
    "endpoints": [
      {
        "methods": ["GET"].to_json(),
        "args": {
          "context": {
            "type": "string".to_json(),
            "enum": ["view", "embed"].to_json(),
            "default": "view".to_json(),
          },
        },
      },
      {
        "methods": ["HEAD"].to_json(),
        "args": {
          "context": {
            "type": "string".to_json(),
            "enum": ["view", "embed"].to_json(),
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
