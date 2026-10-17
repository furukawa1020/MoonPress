///|
pub(all) struct MediaPreview {
  item : MediaItem
  mime : String
  content : Bytes
}

///|
fn raster_preview_mime(name : String) -> String? {
  let lower = name.to_lower()
  if lower.has_suffix(".png") {
    Some("image/png")
  } else if lower.has_suffix(".jpg") || lower.has_suffix(".jpeg") {
    Some("image/jpeg")
  } else if lower.has_suffix(".gif") {
    Some("image/gif")
  } else if lower.has_suffix(".webp") {
    Some("image/webp")
  } else {
    None
  }
}

///|
fn preview_bytes_at(bytes : Bytes, offset : Int, signature : Bytes) -> Bool {
  if bytes.length() < offset + signature.length() {
    return false
  }
  for i = 0; i < signature.length(); i = i + 1 {
    if bytes[offset + i] != signature[i] {
      return false
    }
  }
  true
}

///|
fn media_preview_signature(mime : String, bytes : Bytes) -> Bool {
  match mime {
    "image/png" => preview_bytes_at(bytes, 0, b"\x89PNG\r\n\x1a\n")
    "image/jpeg" => preview_bytes_at(bytes, 0, b"\xff\xd8\xff")
    "image/gif" =>
      preview_bytes_at(bytes, 0, b"GIF87a") ||
      preview_bytes_at(bytes, 0, b"GIF89a")
    "image/webp" =>
      preview_bytes_at(bytes, 0, b"RIFF") && preview_bytes_at(bytes, 8, b"WEBP")
    _ => false
  }
}

///|
pub fn read_media_preview(
  input : String,
  name : String,
  expected? : String? = None,
) -> MediaPreview raise {
  require_media_destination(name)
  let mime = match raster_preview_mime(name) {
    Some(mime) => mime
    None => raise InvalidInput("Preview supports PNG, JPEG, GIF and WebP only")
  }
  if expected is Some(version) {
    if !valid_digest(version) {
      raise InvalidInput("Expected preview digest must be lowercase SHA-256")
    }
  }
  let directory = open_authoring_subdirectory(input, "public")
  defer directory_close(directory.fd)
  let file = directory_read(directory.fd, authoring_name(name))
  if io_is_null(file) != 0 {
    raise io_failure("media preview open", name)
  }
  let content = read_opened_file(file, name, max_bytes=8388608)
  let item = media_item(name, content)
  if expected is Some(version) {
    require_media_version(item, version)
  }
  if !media_preview_signature(mime, content) {
    raise InvalidInput("Image signature does not match filename")
  }
  { item, mime, content, }
}
