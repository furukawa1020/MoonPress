///|
fn rest_wp_media_target(path : String) -> Int? {
  let prefix = "/wp-json/wp/v2/media"
  if path == prefix || path == prefix + "/" {
    return Some(0)
  }
  if !path.has_prefix(prefix + "/") {
    return None
  }
  let tail = path[prefix.length() + 1:].to_owned()
  let tail = if tail.has_suffix("/") {
    tail[:tail.length() - 1].to_owned()
  } else {
    tail
  }
  Some(rest_positive(tail, 2147483647)) catch {
    _ => None
  }
}

///|
fn wp_media_value(row : WpMedia, base : String, embed : Bool) -> Json {
  let value : Json = {
    "slug": wp_media_slug(row.name).to_json(),
    "title": { "rendered": escape_html(row.name).to_json() },
    "id": row.id.to_json(),
    "source_url": (base + url_component(row.name)).to_json(),
    "mime_type": row.mime.to_json(),
    "media_type": (if row.mime.has_prefix("image/") { "image" } else { "file" }).to_json(),
    "_links": {
      "self": [
        {
          "href": (base + "wp-json/wp/v2/media/" + row.id.to_string()).to_json(),
        },
      ].to_json(),
      "collection": [{ "href": (base + "wp-json/wp/v2/media").to_json() }].to_json(),
    },
    "filename": row.name.to_json(),
    "filesize": row.bytes.to_json(),
  }
  if embed {
    rest_project(value, [
      "id", "slug", "title", "source_url", "media_type", "mime_type", "_links",
    ])
  } else {
    value
  }
}

///|
fn wp_media_slug(name : String) -> String {
  "media-" + @crypto.bytes_to_hex_string(@utf8.encode(name))
}

///|
fn rest_wp_media(
  input : String,
  path : String,
  query : Map[String, String],
  base : String,
) -> RestResponse raise {
  let id = rest_wp_media_target(path).unwrap()
  for key, _ in query {
    if ![
        "page", "per_page", "context", "search", "mime_type", "media_type", "include",
        "exclude", "order", "orderby", "slug", "offset",
      ].contains(key) ||
      (id > 0 && key != "context") {
      return rest_error(400, "rest_invalid_param")
    }
  }
  if !["view", "embed"].contains(query.get("context").unwrap_or("view")) {
    return rest_error(400, "rest_invalid_param")
  }
  let embed = query.get("context") == Some("embed")
  let size = rest_positive(query.get("per_page").unwrap_or("10"), 100)
  let page = rest_positive(query.get("page").unwrap_or("1"), 4096)
  let start = match query.get("offset") {
    Some(value) => rest_nonnegative(value, 409600)
    None => (page - 1) * size
  }
  let search = native_query_text(query.get("search").unwrap_or(""))
  let mimes = wp_media_filter_values(query.get("mime_type"), [
    "image/png", "image/jpeg", "image/gif", "image/webp", "application/octet-stream",
  ])
  let media_types = wp_media_filter_values(query.get("media_type"), [
    "image", "application", "audio", "video", "text",
  ])
  let included = rest_id_list(query.get("include"))
  let excluded = rest_id_list(query.get("exclude"))
  let slugs = wp_media_slugs(query.get("slug"))
  let orderby = query.get("orderby").unwrap_or("id")
  let order = query.get("order").unwrap_or("desc")
  if !["id", "title", "include"].contains(orderby) ||
    !["asc", "desc"].contains(order) {
    return rest_error(400, "rest_invalid_param")
  }
  if orderby == "include" && included.is_empty() {
    return rest_error(400, "rest_invalid_param")
  }
  let ranks : Map[Int, Int] = Map([])
  for n = 0; n < included.length(); n = n + 1 {
    ranks[included[n]] = n
  }
  let rows = wp_media_snapshot(input) catch {
    _ => return rest_error(500, "moonpress_media_unavailable")
  }
  let rows = rows.filter(row => {
    row.name.to_lower().contains(search) &&
    (
      (mimes.is_empty() && media_types.is_empty()) ||
      mimes.contains(row.mime) ||
      media_types.any(kind => row.mime.has_prefix(kind + "/"))
    ) &&
    (included.is_empty() || included.contains(row.id)) &&
    (!included.is_empty() || !excluded.contains(row.id)) &&
    (slugs.is_empty() || slugs.contains(wp_media_slug(row.name)))
  })
  if id > 0 {
    for row in rows {
      if row.id == id {
        return rest_ok(wp_media_value(row, base, embed))
      }
    }
    return rest_error(404, "rest_post_invalid_id")
  }
  rows.sort_by(fn(a, b) {
    if orderby == "include" {
      return ranks[a.id].compare(ranks[b.id])
    }
    let compared = if orderby == "title" {
      a.name.lexical_compare(b.name)
    } else {
      a.id.compare(b.id)
    }
    let compared = if compared == 0 { a.id.compare(b.id) } else { compared }
    if order == "asc" {
      compared
    } else {
      0 - compared
    }
  })

  let total = if query.contains("offset") && start >= rows.length() {
    0
  } else {
    rows.length()
  }
  if page > (total + size - 1) / size && total > 0 {
    return rest_error(400, "rest_post_invalid_page_number")
  }
  let selected : Array[Json] = []
  for n = start; n < rows.length() && n < start + size; n = n + 1 {
    selected.push(wp_media_value(rows[n], base, embed))
  }
  {
    ..rest_ok(selected.to_json()),
    total: Some(total),
    pages: Some((total + size - 1) / size),
  }
}

///|
fn wp_media_slugs(value : String?) -> Array[String] raise {
  let names : Array[String] = []
  if value is Some(value) {
    for part in value.split(",") {
      let name = part.to_owned()
      if !name.has_prefix("media-") ||
        name.length() <= 6 ||
        name.length() > 518 ||
        (name.length() - 6) % 2 != 0 ||
        !name[6:].all(c => (c >= 'a' && c <= 'f') || c.is_ascii_digit()) {
        raise InvalidInput("Invalid media slug")
      }
      if !names.contains(name) {
        names.push(name)
      }
      if names.length() > 100 {
        raise InvalidInput("Media slug limit")
      }
    }
  }
  names
}

///|
fn wp_media_filter_values(
  value : String?,
  allowed : Array[String],
) -> Array[String] raise {
  let selected : Array[String] = []
  if value is Some(value) {
    for part in value.split(",") {
      let name = part.trim().to_owned()
      if !allowed.contains(name) {
        raise InvalidInput("Unsupported media filter")
      }
      if !selected.contains(name) {
        selected.push(name)
      }
      if selected.length() > 100 {
        raise InvalidInput("Media filter limit")
      }
    }
  }
  selected
}
