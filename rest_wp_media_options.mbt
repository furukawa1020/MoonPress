///|
fn rest_wp_media_options(
  path : String,
  query : Map[String, String],
) -> RestResponse {
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let properties : Map[String, Json] = Map([])
  for name in ["id", "slug", "title", "media_type", "mime_type", "source_url"] {
    properties[name] = {
      "type": (if name == "id" {
        "integer"
      } else if name == "title" {
        "object"
      } else {
        "string"
      }).to_json(),
      "readonly": true.to_json(),
      "context": ["view", "embed"].to_json(),
    }
  }
  for name in ["filename", "filesize"] {
    properties[name] = {
      "type": (if name == "filesize" { "integer" } else { "string" }).to_json(),
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
  if rest_wp_media_target(path) == Some(0) {
    for name in ["page", "per_page", "offset"] {
      args[name] = {
        "type": "integer".to_json(),
        "minimum": (if name == "offset" { 0 } else { 1 }).to_json(),
      }
    }
    for name in ["include", "exclude"] {
      args[name] = {
        "type": "array".to_json(),
        "items": { "type": "integer".to_json() },
      }
    }
    args["slug"] = {
      "type": "array".to_json(),
      "items": { "type": "string".to_json() },
    }
    for name in ["search", "mime_type", "media_type"] {
      args[name] = { "type": "string".to_json() }
    }
    for name in ["mime_type", "media_type"] {
      args[name] = {
        "type": "array".to_json(),
        "items": { "type": "string".to_json() },
      }
    }
    args["order"] = {
      "type": "string".to_json(),
      "enum": ["asc", "desc"].to_json(),
      "default": "desc".to_json(),
    }
    args["orderby"] = {
      "type": "string".to_json(),
      "enum": ["id", "title", "include"].to_json(),
      "default": "id".to_json(),
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
      "public_files_only": true.to_json(),
      "id_source": "filename-sha256-31bit".to_json(),
      "slug_source": "filename-utf8-hex".to_json(),
      "title_source": "filename".to_json(),
      "default_orderby": "id".to_json(),
      "attachment_database": false.to_json(),
      "image_metadata": false.to_json(),
    },
  })
}
