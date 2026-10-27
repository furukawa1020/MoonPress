///|
fn rest_users_collection(path : String) -> Bool {
  ["/wp-json/wp/v2/users", "/wp-json/wp/v2/users/"].contains(path)
}

///|
fn rest_is_users(path : String) -> Bool {
  rest_users_collection(path)
}

///|
fn rest_user_value(user : AccessUser) -> Json {
  {
    "id": user.id.to_json(),
    "name": user.login.to_json(),
    "slug": user.login.to_json(),
  }
}

///|
fn rest_public_users(input : String) -> Array[AccessUser] raise {
  if path_kind(input + "/.moonpress-access") == 0 {
    return []
  }
  let vault = access_open(input)
  defer directory_close(vault.fd)
  vault.lock()
  let state = access_replay(vault)
  let authors = rest_public_posts(input).map(post => post.document.author)
  state.users.filter(user => user.active && authors.contains(user.id))
}

///|
fn rest_users(
  input : String,
  path : String,
  query : Map[String, String],
) -> RestResponse raise {
  for key, value in query {
    if !["context"].contains(key) ||
      (key == "context" && !["view", "embed"].contains(value)) {
      return rest_error(400, "rest_invalid_param")
    }
  }
  let users = rest_public_users(input) catch {
    _ => return rest_error(500, "moonpress_users_unavailable")
  }
  if !rest_users_collection(path) {
    return rest_error(404, "rest_user_invalid_id")
  }
  {
    ..rest_ok(users.map(user => rest_user_value(user)).to_json()),
    total: Some(users.length()),
    pages: Some(if users.is_empty() { 0 } else { 1 }),
  }
}

///|
fn rest_users_options(
  path : String,
  query : Map[String, String],
) -> RestResponse {
  if !query.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let properties : Map[String, Json] = Map([])
  for name in ["id", "name", "slug"] {
    properties[name] = {
      "type": (if name == "id" { "integer" } else { "string" }).to_json(),
      "readonly": true.to_json(),
      "context": ["view", "embed"].to_json(),
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
      "public_authors_only": true.to_json(),
      "collection": rest_users_collection(path).to_json(),
    },
  })
}
