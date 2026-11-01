///|
fn rest_users_collection(path : String) -> Bool {
  path == "/wp-json/wp/v2/users" || path == "/wp-json/wp/v2/users/"
}

///|
fn rest_user_target(path : String) -> Int? {
  if rest_users_collection(path) {
    return Some(0)
  }
  if path == "/wp-json/wp/v2/users/me" {
    return Some(-1)
  }
  let prefix = "/wp-json/wp/v2/users/"
  if !path.has_prefix(prefix) {
    return None
  }
  let tail = path[prefix.length():].to_owned()
  Some(rest_positive(tail, 2147483647)) catch {
    _ => None
  }
}

///|
fn rest_is_users(path : String) -> Bool {
  rest_user_target(path) is Some(_)
}

///|
fn rest_user_value(
  user : AccessPrincipal,
  context : String,
  base : String,
) -> Json raise {
  let fields : Map[String, Json] = Map([
    ("id", user.id.to_json()),
    ("name", user.login.to_json()),
    ("slug", user.login.to_json()),
  ])
  if context == "edit" {
    fields["username"] = user.login.to_json()
    fields["roles"] = [user.role].to_json()
    let caps : Map[String, Json] = Map([])
    for cap in role_capabilities(user.role) {
      caps[cap] = true.to_json()
    }
    caps[user.role] = true.to_json()
    fields["capabilities"] = Json::object(caps)
  }
  ignore(base)
  Json::object(fields)
}

///|
fn rest_users(
  input : String,
  path : String,
  query : Map[String, String],
  principal? : AccessPrincipal? = None,
  base? : String = "",
) -> RestResponse raise {
  let target = rest_user_target(path).unwrap()
  let context = query.get("context").unwrap_or("view")
  if !["view", "embed", "edit"].contains(context) {
    return rest_error(400, "rest_invalid_param")
  }
  for key, _ in query {
    if ![
        "context", "include", "exclude", "search", "slug", "order", "orderby", "page",
        "per_page", "roles",
      ].contains(key) ||
      (target != 0 && key != "context") {
      return rest_error(400, "rest_invalid_param")
    }
  }
  let admin = match principal {
    Some(user) => role_capabilities(user.role).contains("list_users")
    None => false
  }
  if target == 0 && context == "edit" && !admin {
    return rest_error(
      if principal is None {
        401
      } else {
        403
      },
      "rest_forbidden_context",
    )
  }
  let roles = rest_user_words(query.get("roles"))
  if !roles.is_empty() && !admin {
    return rest_error(
      if principal is None {
        401
      } else {
        403
      },
      "rest_user_cannot_view",
    )
  }
  let orderby = query.get("orderby").unwrap_or("name")
  let order = query.get("order").unwrap_or("asc")
  if !["id", "name", "slug"].contains(orderby) ||
    !["asc", "desc"].contains(order) {
    return rest_error(400, "rest_invalid_param")
  }
  let size = rest_positive(query.get("per_page").unwrap_or("10"), 100)
  let page = rest_positive(query.get("page").unwrap_or("1"), 4096)
  let start = (page - 1) * size
  let search = native_query_text(query.get("search").unwrap_or(""))
  let slugs = rest_user_slugs(query.get("slug"))
  let included = rest_id_list(query.get("include"))
  let excluded = rest_id_list(query.get("exclude"))
  let all = rest_active_users(input) catch {
    _ => return rest_error(500, "moonpress_users_unavailable")
  }
  let posts = rest_public_posts(input) catch {
    _ => return rest_error(500, "moonpress_users_unavailable")
  }
  let public_ids = posts.map(post => post.document.author)
  if target != 0 {
    if target == -1 && principal is None {
      return rest_error(401, "rest_not_logged_in")
    }
    let id = if target == -1 { principal.unwrap().id } else { target }
    for user in all {
      if user.id != id {
        continue
      }
      if context == "edit" {
        let allowed = match principal {
          Some(actor) =>
            actor.id == id ||
            role_capabilities(actor.role).contains("edit_users")
          None => false
        }
        if !allowed {
          return rest_error(
            if principal is None {
              401
            } else {
              403
            },
            "rest_forbidden_context",
          )
        }
        return rest_ok(rest_user_value(user, context, base))
      }
      if public_ids.contains(id) ||
        (principal is Some(actor) && actor.id == id) ||
        admin {
        return rest_ok(rest_user_value(user, context, base))
      }
      return rest_error(404, "rest_user_invalid_id")
    }
    return rest_error(404, "rest_user_invalid_id")
  }
  let users = all.filter(user => {
    (admin || public_ids.contains(user.id)) &&
    (roles.is_empty() || roles.contains(user.role)) &&
    user.login.contains(search) &&
    (slugs.is_empty() || slugs.contains(user.login)) &&
    (included.is_empty() || included.contains(user.id)) &&
    !excluded.contains(user.id)
  })
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
  if page > (users.length() + size - 1) / size && page != 1 {
    return rest_error(400, "rest_user_invalid_page_number")
  }
  let values : Array[Json] = []
  for n = start; n < users.length() && n < start + size; n = n + 1 {
    values.push(rest_user_value(users[n], context, base))
  }
  {
    ..rest_ok(values.to_json()),
    total: Some(users.length()),
    pages: Some((users.length() + size - 1) / size),
  }
}

///|
fn rest_user_words(value : String?) -> Array[String] raise {
  let words : Array[String] = []
  if value is Some(value) && !value.is_empty() {
    let parts = value.split(",").to_array()
    if parts.length() > 100 {
      raise InvalidInput("User filter limit")
    }
    for part in parts {
      let word = part.trim().to_owned()
      if word.is_empty() ||
        word.length() > 80 ||
        !word.all(c => {
          c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '_' || c == '-'
        }) {
        raise InvalidInput("Invalid user filter")
      }
      if !words.contains(word) {
        words.push(word)
      }
    }
  }
  words
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
