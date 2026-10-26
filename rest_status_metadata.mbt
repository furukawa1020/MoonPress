///|
fn rest_status_value(status : String, context : String) -> Json {
  let fields : Map[String, Json] = Map([
    (
      "name",
      (match status {
        "publish" => "Published"
        "future" => "Scheduled"
        "draft" => "Draft"
        _ => "Trash"
      }).to_json(),
    ),
    ("slug", status.to_json()),
  ])
  if context != "embed" {
    fields["public"] = (status == "publish").to_json()
    fields["queryable"] = (status == "publish").to_json()
    fields["date_floating"] = (status == "draft").to_json()
  }
  if context == "edit" {
    fields["private"] = false.to_json()
    fields["protected"] = (status == "draft" || status == "future").to_json()
    fields["show_in_list"] = (status != "trash").to_json()
  }
  Json::object(fields)
}

///|
fn rest_status_metadata(
  path : String,
  query : Map[String, String],
  principal : AccessPrincipal?,
) -> RestResponse raise {
  let context = query.get("context").unwrap_or("view")
  if query.keys().any(key => key != "context") ||
    !["view", "embed", "edit"].contains(context) {
    return rest_error(400, "rest_invalid_param")
  }
  let editor = principal
    .map(user => {
      role_capabilities(user.role).contains("edit_posts") ||
      role_capabilities(user.role).contains("edit_pages")
    })
    .unwrap_or(false)
  if context == "edit" && !editor {
    return rest_error(
      if principal is None {
        401
      } else {
        403
      },
      "rest_cannot_view",
    )
  }
  if path == "/wp-json/wp/v2/statuses" || path == "/wp-json/wp/v2/statuses/" {
    let fields : Map[String, Json] = Map([])
    for status in ["publish", "draft", "future", "trash"] {
      if editor || status == "publish" {
        fields[status] = rest_status_value(status, context)
      }
    }
    return rest_ok(Json::object(fields))
  }
  rest_error(404, "rest_status_invalid")
}

///|
fn rest_status_options(query : Map[String, String]) -> RestResponse {
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let properties : Map[String, Json] = Map([])
  for
    name in [
      "name", "slug", "public", "queryable", "date_floating", "private", "protected",
      "show_in_list",
    ] {
    properties[name] = {
      "readonly": true.to_json(),
      "type": (if name == "name" || name == "slug" {
        "string"
      } else {
        "boolean"
      }).to_json(),
      "context": (if name == "name" || name == "slug" {
        ["view", "embed", "edit"]
      } else if ["private", "protected", "show_in_list"].contains(name) {
        ["edit"]
      } else {
        ["view", "edit"]
      }).to_json(),
    }
  }
  rest_ok({
    "namespace": "wp/v2".to_json(),
    "methods": ["GET", "HEAD", "OPTIONS"].to_json(),
    "schema": {
      "type": "object".to_json(),
      "properties": Json::object(properties),
    },
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
    "moonpress": { "subset": true.to_json() },
  })
}
