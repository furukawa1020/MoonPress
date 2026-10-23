///|
priv struct NativeMediaRow {
  name : String
  bytes : Int
  value : Json
}

///|
extern "C" fn native_media_same_site(content : Int, assets : Int) -> Int = "moonpress_same_media_site"

///|
fn native_media_name(path : String) -> String? {
  let parts = native_parts(path)
  if parts.length() == 1 && parts[0] == "media" {
    return Some("")
  }
  if parts.length() != 2 || parts[0] != "media" {
    return None
  }
  let name = admin_decode(parts[1].replace_all(old="+", new="%2B")) catch {
    _ => return None
  }
  require_media_destination(name) catch {
    _ => return None
  }
  Some(name)
}

///|
fn native_media_value(name : String, bytes : Bytes, base : String) -> Json {
  let mime = native_media_mime(name, bytes)
  {
    "name": name.to_json(),
    "source_url": (base + url_component(name)).to_json(),
    "bytes": bytes.length().to_json(),
    "digest": digest_bytes(bytes).to_json(),
    "mime_type": mime.to_json(),
    "media_type": (if mime.has_prefix("image/") { "image" } else { "file" }).to_json(),
  }
}

///|
fn native_media_read(
  input : String,
  content : AuthoringDirectory,
  principal : AccessPrincipal,
  name : String,
  query : Map[String, String],
  base : String,
) -> RestResponse raise {
  if !role_capabilities(principal.role).contains("upload_files") {
    return rest_error(403, "rest_cannot_upload")
  }
  for key, _ in query {
    if ![
        "page", "per_page", "search", "mime_type", "media_type", "order", "orderby",
      ].contains(key) ||
      !name.is_empty() {
      return rest_error(400, "rest_invalid_param")
    }
  }
  let orderby = query.get("orderby").unwrap_or("name")
  let order = query.get("order").unwrap_or("asc")
  if !["name", "bytes"].contains(orderby) || !["asc", "desc"].contains(order) {
    return rest_error(400, "rest_invalid_param")
  }
  let mime = query.get("mime_type")
  let media_type = query.get("media_type")
  if (
      mime is Some(value) &&
      ![
        "image/png", "image/jpeg", "image/gif", "image/webp", "application/octet-stream",
      ].contains(value)
    ) ||
    (media_type is Some(value) && !["image", "file"].contains(value)) {
    return rest_error(400, "rest_invalid_param")
  }
  let search = native_query_text(query.get("search").unwrap_or("")) catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  try {
    rest_positive(query.get("page").unwrap_or("1"), 4096) |> ignore
    rest_positive(query.get("per_page").unwrap_or("10"), 100) |> ignore
  } catch {
    _ => return rest_error(400, "rest_invalid_param")
  }
  if path_kind(input + "/public") == 0 {
    if !name.is_empty() {
      return rest_error(404, "moonpress_media_missing")
    }
    if rest_page_bounds(0, query) is None {
      return rest_error(400, "rest_post_invalid_page_number")
    }
    return {
      ..rest_ok(([] : Array[Json]).to_json()),
      total: Some(0),
      pages: Some(0),
    }
  }
  let directory = open_authoring_subdirectory(input, "public")
  defer directory_close(directory.fd)
  if native_media_same_site(content.fd, directory.fd) != 1 {
    raise InvalidInput("Media directory changed site")
  }
  directory.lock()
  if !name.is_empty() {
    if directory.kind(name) == 0 {
      return rest_error(404, "moonpress_media_missing")
    }
    let bytes = directory.read(name, max_bytes=8388608)
    return rest_ok(
      native_media_value(name, bytes, base),
      etag=Some(digest_bytes(bytes)),
    )
  }
  let names = directory.names()
  if names.length() > 4096 {
    raise InvalidInput("Media entry limit")
  }
  names.sort()
  let rows : Array[NativeMediaRow] = []
  let mut total = 0
  for name in names {
    require_media_destination(name)
    let bytes = directory.read(name, max_bytes=8388608)
    total += bytes.length()
    if total > 67108864 {
      raise InvalidInput("Media snapshot byte limit")
    }
    let actual = native_media_mime(name, bytes)
    let actual_type = if actual.has_prefix("image/") { "image" } else { "file" }
    if name.to_lower().contains(search) &&
      (mime is None || mime == Some(actual)) &&
      (media_type is None || media_type == Some(actual_type)) {
      rows.push({
        name,
        bytes: bytes.length(),
        value: native_media_value(name, bytes, base),
      })
    }
  }
  rows.sort_by(fn(a, b) {
    let compared = if orderby == "bytes" {
      a.bytes.compare(b.bytes)
    } else {
      a.name.compare(b.name)
    }
    let compared = if compared == 0 { a.name.compare(b.name) } else { compared }
    if order == "asc" {
      compared
    } else {
      0 - compared
    }
  })
  let (start, size, pages) = match rest_page_bounds(rows.length(), query) {
    Some(bounds) => bounds
    None => return rest_error(400, "rest_post_invalid_page_number")
  }
  let selected : Array[Json] = []
  for i = start; i < rows.length() && i < start + size; i = i + 1 {
    selected.push(rows[i].value)
  }
  {
    ..rest_ok(selected.to_json()),
    total: Some(rows.length()),
    pages: Some(pages),
  }
}

///|
fn native_media_mime(name : String, bytes : Bytes) -> String {
  match raster_preview_mime(name) {
    Some(mime) if media_preview_signature(mime, bytes) => mime
    _ => "application/octet-stream"
  }
}
