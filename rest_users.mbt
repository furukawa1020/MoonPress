///|
fn rest_users_collection(path : String) -> Bool {
  ["/wp-json/wp/v2/users", "/wp-json/wp/v2/users/"].contains(path)
}

///|
fn rest_is_users(path : String) -> Bool {
  if rest_users_collection(path) {
    return true
  }
  if path.has_prefix("/wp-json/wp/v2/users/") {
    return try rest_positive(path[21:].to_owned(), 2147483647) > 0 catch {
      _ => false
    }
  }
  false
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
    if ![
        "context", "include", "exclude", "search", "slug", "order", "orderby", "per_page",
        "page",
      ].contains(key) ||
      (key == "context" && !["view", "embed"].contains(value)) {
      return rest_error(400, "rest_invalid_param")
    }
  }
  let orderby = query.get("orderby").unwrap_or("name")
  let order = query.get("order").unwrap_or("asc")
  if !["id", "name", "slug"].contains(orderby) ||
    !["asc", "desc"].contains(order) {
    return rest_error(400, "rest_invalid_param")
  }
  rest_page_bounds(0, query) |> ignore
  let search = native_query_text(query.get("search").unwrap_or(""))
  let slugs = rest_user_slugs(query.get("slug"))
  let included = rest_id_list(query.get("include"))
  let excluded = rest_id_list(query.get("exclude"))
  if !rest_users_collection(path) && query.keys().any(key => key != "context") {
    return rest_error(400, "rest_invalid_param")
  }
  let users = rest_public_users(input) catch {
    _ => return rest_error(500, "moonpress_users_unavailable")
  }
  let users = users.filter(user => {
    (slugs.is_empty() || slugs.contains(user.login)) &&
    user.login.contains(search) &&
    (included.is_empty() || included.contains(user.id)) &&
    !excluded.contains(user.id)
  })
  if !rest_users_collection(path) {
    let id = rest_positive(path[21:].to_owned(), 2147483647)
    for user in users {
      if user.id == id {
        return rest_ok(rest_user_value(user))
      }
    }
    return rest_error(404, "rest_user_invalid_id")
  }
  users.sort_by(fn(a, b) {
    let compared = if orderby == "id" {
      a.id.compare(b.id)
    } else {
      a.login.lexical_compare(b.login)
    }
    let compared = if compared == 0 { a.id.compare(b.id) } else { compared }
    if order == "asc" {
      compared
    } else {
      0 - compared
    }
  })
  let (start, size, pages) = match rest_page_bounds(users.length(), query) {
    Some(bounds) => bounds
    None => return rest_error(400, "rest_user_invalid_page_number")
  }
  let values : Array[Json] = []
  for i = start; i < users.length() && i < start + size; i = i + 1 {
    values.push(rest_user_value(users[i]))
  }
  {
    ..rest_ok(values.to_json()),
    total: Some(users.length()),
    pages: Some(pages),
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
  if rest_users_collection(path) {
    for name in ["include", "exclude"] {
      args[name] = {
        "type": "array".to_json(),
        "items": { "type": "integer".to_json() },
      }
    }
  }
  if rest_users_collection(path) {
    args["search"] = { "type": "string".to_json() }
    args["slug"] = {
      "type": "array".to_json(),
      "items": { "type": "string".to_json() },
    }
  }
  if rest_users_collection(path) {
    for name in ["page", "per_page"] {
      args[name] = { "type": "integer".to_json() }
    }
    args["order"] = {
      "type": "string".to_json(),
      "enum": ["asc", "desc"].to_json(),
    }
    args["orderby"] = {
      "type": "string".to_json(),
      "enum": ["id", "name", "slug"].to_json(),
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
      "public_authors_only": true.to_json(),
      "collection": rest_users_collection(path).to_json(),
    },
  })
}
