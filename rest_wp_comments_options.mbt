///|
fn rest_wp_comments_options(
  path : String,
  query : Map[String, String],
) -> RestResponse {
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let properties : Map[String, Json] = Map([])
  for
    name in [
      "id", "author", "author_name", "author_url", "content", "date", "date_gmt",
      "link", "parent", "post", "status", "type",
    ] {
    properties[name] = {
      "type": (if ["id", "author", "parent", "post"].contains(name) {
        "integer"
      } else if name == "content" {
        "object"
      } else {
        "string"
      }).to_json(),
      "readonly": true.to_json(),
      "context": (if ["date_gmt", "post", "status"].contains(name) {
        ["view"]
      } else {
        ["view", "embed"]
      }).to_json(),
    }
  }
  properties["content"] = {
    "type": "object".to_json(),
    "readonly": true.to_json(),
    "context": ["view", "embed"].to_json(),
    "properties": {
      "rendered": { "type": "string".to_json(), "readonly": true.to_json() },
    },
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
  if rest_wp_comment_id(path) == Some(0) {
    for
      name in [
        "post", "author", "author_exclude", "include", "exclude", "parent", "parent_exclude",
      ] {
      args[name] = {
        "type": "array".to_json(),
        "items": { "type": "integer".to_json() },
      }
    }
    for name in ["page", "per_page", "offset"] {
      args[name] = { "type": "integer".to_json() }
    }
    for name in ["after", "before"] {
      args[name] = {
        "type": "string".to_json(),
        "format": "date-time".to_json(),
      }
    }
    args["search"] = { "type": "string".to_json() }
    args["status"] = {
      "type": "string".to_json(),
      "enum": ["approve"].to_json(),
      "default": "approve".to_json(),
    }
    args["type"] = {
      "type": "string".to_json(),
      "enum": ["comment"].to_json(),
      "default": "comment".to_json(),
    }
    args["order"] = {
      "type": "string".to_json(),
      "enum": ["asc", "desc"].to_json(),
      "default": "desc".to_json(),
    }
    args["orderby"] = {
      "type": "string".to_json(),
      "enum": ["date", "date_gmt", "id", "author_name", "post", "include"].to_json(),
      "default": "date_gmt".to_json(),
    }
  }
  let endpoints : Array[Json] = [
    { "methods": ["GET"].to_json(), "args": Json::object(args) },
    { "methods": ["HEAD"].to_json(), "args": Json::object(args) },
    { "methods": ["OPTIONS"].to_json(), "args": Json::object(Map([])) },
  ]
  if rest_wp_comment_id(path) == Some(0) {
    endpoints.push({
      "methods": ["POST"].to_json(),
      "args": {
        "context": {
          "type": "string".to_json(),
          "enum": ["view", "embed", "edit"].to_json(),
          "default": "edit".to_json(),
        },
        "post": {
          "type": "integer".to_json(),
          "required": true.to_json(),
          "minimum": (1).to_json(),
        },
        "parent": {
          "type": "integer".to_json(),
          "minimum": (0).to_json(),
          "default": (0).to_json(),
        },
        "author_name": {
          "type": "string".to_json(),
          "maxLength": (80).to_json(),
        },
        "content": {
          "required": true.to_json(),
          "oneOf": [
            { "type": "string".to_json() },
            {
              "type": "object".to_json(),
              "properties": { "raw": { "type": "string".to_json() } },
              "required": ["raw"].to_json(),
              "additionalProperties": false.to_json(),
            },
          ].to_json(),
        },
      },
    })
  }
  rest_ok({
    "namespace": "wp/v2".to_json(),
    "methods": rest_methods(path).unwrap().to_json(),
    "schema": {
      "type": "object".to_json(),
      "properties": Json::object(properties),
    },
    "endpoints": endpoints.to_json(),
    "moonpress": {
      "subset": true.to_json(),
      "approved_public_reads_only": true.to_json(),
      "authenticated_creation": true.to_json(),
      "creation_status": "hold".to_json(),
      "creation_response_context": "edit".to_json(),
      "max_reply_ancestors": (8).to_json(),
      "native_writes": "/wp-json/moonpress/v1/comments".to_json(),
    },
  })
}
