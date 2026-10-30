///|
fn rest_wp_media_target(path : String) -> Int? {
  if path == "/wp-json/wp/v2/media" || path == "/wp-json/wp/v2/media/" {
    Some(0)
  } else if path.has_prefix("/wp-json/wp/v2/media/") {
    let tail = path[21:].to_owned()
    let tail = if tail.has_suffix("/") {
      tail[:tail.length() - 1].to_owned()
    } else {
      tail
    }
    Some(rest_positive(tail, 2147483647)) catch {
      _ => None
    }
  } else {
    None
  }
}

///|
fn wp_media_value(row : WpMedia, base : String, _embed : Bool) -> Json {
  {
    "slug": ("media-" + @crypto.bytes_to_hex_string(@utf8.encode(row.name))).to_json(),
    "title": { "rendered": escape_html(row.name).to_json() },
    "id": row.id.to_json(),
    "source_url": (base + url_component(row.name)).to_json(),
    "mime_type": row.mime.to_json(),
    "media_type": (if row.mime.has_prefix("image/") { "image" } else { "file" }).to_json(),
  }
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
    if !["page", "per_page", "context"].contains(key) ||
      (id > 0 && key != "context") {
      return rest_error(400, "rest_invalid_param")
    }
  }
  if query.get("context").unwrap_or("view") != "view" {
    return rest_error(400, "rest_invalid_param")
  }
  let size = rest_positive(query.get("per_page").unwrap_or("10"), 100)
  let page = rest_positive(query.get("page").unwrap_or("1"), 4096)
  let start = (page - 1) * size
  let rows = wp_media_snapshot(input) catch {
    _ => return rest_error(500, "moonpress_media_unavailable")
  }
  if id > 0 {
    for row in rows {
      if row.id == id {
        return rest_ok(wp_media_value(row, base, false))
      }
    }
    return rest_error(404, "rest_post_invalid_id")
  }
  rows.sort_by(fn(a, b) { b.id.compare(a.id) })
  if start > 0 && start >= rows.length() {
    return rest_error(400, "rest_post_invalid_page_number")
  }
  let selected : Array[Json] = []
  for n = start; n < rows.length() && n < start + size; n = n + 1 {
    selected.push(wp_media_value(rows[n], base, false))
  }
  {
    ..rest_ok(selected.to_json()),
    total: Some(rows.length()),
    pages: Some((rows.length() + size - 1) / size),
  }
}
