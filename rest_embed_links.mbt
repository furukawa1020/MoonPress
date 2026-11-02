///|
priv struct RestEmbedState {
  cache : Map[String, Json]
  mut bytes : Int
  mut expanded_bytes : Int
}

///|
fn rest_embed_local(
  href : String,
  base : String,
) -> (String, Map[String, String])? {
  if !href.has_prefix(base + "wp-json/wp/v2/") {
    return None
  }
  (rest_target("/" + href[base.length():].to_owned()) |> Some) catch {
    _ => None
  }
}

///|
fn rest_embed_response(
  input : String,
  result : RestResponse,
  selectors : Array[String],
  base : String,
  credentials : String?,
) -> RestResponse {
  if result.code != 200 {
    return result
  }
  let principal = match credentials {
    None => None
    Some(value) => {
      let user = try {
        let (login, secret) = rest_basic(value)
        authenticate_access(input, login, secret)
      } catch {
        _ => None
      }
      if user is None {
        return rest_error(401, "rest_not_logged_in")
      }
      user
    }
  }
  let state : RestEmbedState = {
    cache: Map([]),
    bytes: 0,
    expanded_bytes: @utf8.encode(result.value.stringify()).length(),
  }
  try {
    let value = rest_embed_data(
      input,
      result.value,
      selectors,
      base,
      principal,
      state,
    )
    if @utf8.encode(value.stringify()).length() > 16777216 {
      raise InvalidInput("Embed response limit")
    }
    { ..result, value, }
  } catch {
    _ => rest_error(500, "moonpress_embed_unavailable")
  }
}

///|
fn rest_embed_data(
  input : String,
  value : Json,
  selectors : Array[String],
  base : String,
  principal : AccessPrincipal?,
  state : RestEmbedState,
) -> Json raise {
  match value {
    Array(items) =>
      items
      .map(item => {
        rest_embed_data(input, item, selectors, base, principal, state)
      })
      .to_json()
    Object(fields) => {
      let links = match fields.get("_links") {
        Some(Object(links)) => links
        _ => return value
      }
      let embedded : Map[String, Json] = Map([])
      for rel, entries in links {
        if !selectors.is_empty() && !selectors.contains(rel) {
          continue
        }
        let items = match entries {
          Array(items) => items
          _ => continue
        }
        let slots : Array[Json] = []
        let mut has_value = false
        for item in items {
          let link = match item {
            Object(link) => link
            _ => {
              slots.push(([] : Array[Json]).to_json())
              continue
            }
          }
          let href = match link.get("href") {
            Some(String(href)) => href
            _ => {
              slots.push(([] : Array[Json]).to_json())
              continue
            }
          }
          if link.get("embeddable") != Some(true.to_json()) ||
            !rest_embed_allowed(fields, rel, link) {
            slots.push(([] : Array[Json]).to_json())
            continue
          }
          let data = rest_embed_fetch(input, href, rel, base, principal, state)
          if data != ([] : Array[Json]).to_json() {
            has_value = true
          }
          slots.push(data)
        }
        if has_value {
          embedded[rel] = slots.to_json()
        }
      }
      if embedded.is_empty() {
        return value
      }
      let output = fields.copy()
      output["_embedded"] = Json::object(embedded)
      Json::object(output)
    }
    _ => value
  }
}

///|
fn rest_embed_allowed(
  fields : Map[String, Json],
  rel : String,
  link : Map[String, Json],
) -> Bool {
  let article = fields.get("type") == Some("post".to_json()) ||
    fields.get("type") == Some("page".to_json())
  let comment = fields.get("type") == Some("comment".to_json())
  if article && rel == "author" {
    return true
  }
  if article &&
    rel == "wp:term" &&
    link.get("taxonomy") == Some("category".to_json()) {
    return true
  }
  if article &&
    rel == "wp:term" &&
    link.get("taxonomy") == Some("post_tag".to_json()) {
    return true
  }
  if article && rel == "replies" {
    return true
  }
  if comment && rel == "up" {
    return true
  }
  if comment && rel == "in-reply-to" {
    return true
  }
  if comment && rel == "author" {
    return true
  }
  if comment && rel == "children" {
    return true
  }
  ignore(comment)
  ignore(link)
  false
}

///|
fn rest_embed_fetch(
  input : String,
  href : String,
  rel : String,
  base : String,
  principal : AccessPrincipal?,
  state : RestEmbedState,
) -> Json raise {
  if state.cache.get(href) is Some(data) {
    return rest_embed_expansion(state, data)
  }
  if state.cache.length() >= 256 {
    raise InvalidInput("Embed fetch count limit")
  }
  let (path, query) = match rest_embed_local(href, base) {
    Some(target) => target
    _ => raise InvalidInput("Nonlocal embed route")
  }
  let supported = match rel {
    "author" => rest_user_target(path).unwrap_or(0) > 0
    "wp:term" => rest_wp_term_target(path) is Some((_, 0))
    "replies" | "children" => rest_wp_comment_id(path) == Some(0)
    "in-reply-to" => rest_wp_comment_id(path).unwrap_or(0) > 0
    "up" =>
      path.has_prefix("/wp-json/wp/v2/posts/") ||
      path.has_prefix("/wp-json/wp/v2/pages/")
    _ => false
  }
  if !supported || query.keys().any(key => key != "post" && key != "parent") {
    raise InvalidInput("Unsupported embedded target")
  }
  query["context"] = "embed"
  if rest_wp_comment_id(path) == Some(0) ||
    rest_wp_term_target(path) is Some((_, 0)) {
    query["per_page"] = "100"
  }
  let response = rest_route(input, path, query, base, principal)
  let data = response.value
  return rest_embed_cache(state, href, data)
}

///|
fn rest_embed_expansion(state : RestEmbedState, data : Json) -> Json raise {
  let size = @utf8.encode(data.stringify()).length()
  if state.expanded_bytes + size > 16777216 {
    raise InvalidInput("Embed expanded byte limit")
  }
  state.expanded_bytes += size
  data
}

///|
fn rest_embed_cache(
  state : RestEmbedState,
  href : String,
  data : Json,
) -> Json raise {
  let size = @utf8.encode(data.stringify()).length()
  if state.bytes + size > 8388608 {
    raise InvalidInput("Embed cache byte limit")
  }
  let data = rest_embed_expansion(state, data)
  state.bytes += size
  state.cache[href] = data
  data
}
