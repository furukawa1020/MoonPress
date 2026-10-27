///|
fn rest_term_options(
  path : String,
  query : Map[String, String],
) -> RestResponse {
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let metadata = rest_is_taxonomies(path)
  let target = rest_wp_term_target(path)
  let collection = if metadata {
    rest_taxonomies_collection(path)
  } else {
    target is Some((_, 0))
  }
  let properties : Map[String, Json] = Map([])
  for
    name in (if metadata {
      ["name", "slug", "description", "types", "rest_base", "rest_namespace"]
    } else {
      ["id", "name", "slug", "taxonomy", "count", "description", "link"]
    }) {
    properties[name] = {
      "type": (if ["id", "count"].contains(name) {
        "integer"
      } else if name == "types" {
        "array"
      } else {
        "string"
      }).to_json(),
      "readonly": true.to_json(),
      "context": (if ["count", "description", "types"].contains(name) {
        ["view"]
      } else {
        ["view", "embed"]
      }).to_json(),
    }
  }
  if metadata {
    properties["types"] = {
      "type": "array".to_json(),
      "items": { "type": "string".to_json() },
      "readonly": true.to_json(),
      "context": ["view"].to_json(),
    }
  }
  if target is Some(("category", _)) {
    properties["parent"] = {
      "type": "integer".to_json(),
      "readonly": true.to_json(),
      "context": ["view"].to_json(),
    }
  }
  let args : Map[String, Json] = Map([
    (
      "context",
      {
        "type": "string".to_json(),
        "enum": ["view", "embed"].to_json(),
        "default": "view".to_json(),
      },
    ),
  ])
  if metadata && collection {
    args["type"] = {
      "type": "string".to_json(),
      "enum": ["post", "page"].to_json(),
    }
  }
  if !metadata && collection {
    for name in ["include", "exclude"] {
      args[name] = {
        "type": "array".to_json(),
        "items": { "type": "integer".to_json(), "minimum": (1).to_json() },
        "maxItems": (100).to_json(),
      }
    }
    args["slug"] = {
      "type": "array".to_json(),
      "items": { "type": "string".to_json() },
      "maxItems": (100).to_json(),
    }
    args["search"] = { "type": "string".to_json() }
    args["post"] = { "type": "integer".to_json(), "minimum": (1).to_json() }
    args["hide_empty"] = {
      "type": "boolean".to_json(),
      "default": false.to_json(),
    }
    if target is Some(("category", _)) {
      args["parent"] = { "type": "integer".to_json(), "minimum": (0).to_json() }
    }
    args["order"] = {
      "type": "string".to_json(),
      "enum": ["asc", "desc"].to_json(),
      "default": "asc".to_json(),
    }
    args["orderby"] = {
      "type": "string".to_json(),
      "enum": ["name", "slug", "id", "count", "include", "include_slugs"].to_json(),
      "default": "name".to_json(),
    }
    args["page"] = {
      "type": "integer".to_json(),
      "minimum": (1).to_json(),
      "maximum": (4096).to_json(),
      "default": (1).to_json(),
    }
    args["per_page"] = {
      "type": "integer".to_json(),
      "minimum": (1).to_json(),
      "maximum": (100).to_json(),
      "default": (10).to_json(),
    }
    args["offset"] = {
      "type": "integer".to_json(),
      "minimum": (0).to_json(),
      "maximum": (409600).to_json(),
    }
  }
  rest_ok({
    "namespace": "wp/v2".to_json(),
    "methods": ["GET", "HEAD", "OPTIONS"].to_json(),
    "endpoints": [
      { "methods": ["GET"].to_json(), "args": Json::object(args) },
      { "methods": ["HEAD"].to_json(), "args": Json::object(args) },
      { "methods": ["OPTIONS"].to_json(), "args": Json::object(Map([])) },
    ].to_json(),
    "schema": {
      "type": "object".to_json(),
      "properties": Json::object(properties),
    },
    "moonpress": {
      "subset": true.to_json(),
      "public_terms_only": true.to_json(),
      "flat_terms": true.to_json(),
      "name_derived_ids": true.to_json(),
      "collection": collection.to_json(),
    },
  })
}
