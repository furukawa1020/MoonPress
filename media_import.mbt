///|
fn require_media_destination(name : String) -> Unit raise {
  if name.has_prefix(".") ||
    !safe_output_name(name) ||
    !allowed_asset_name(name) ||
    name == "style.css" ||
    name == "sitemap.xml" ||
    name == "rss.xml" {
    raise InvalidInput(
      "Media destination must be a supported flat filename, not a compiler output",
    )
  }
}

///|
pub fn import_media(
  input : String,
  source : String,
  name : String,
) -> MediaItem raise {
  require_media_destination(name)
  require_input_kind(input, 2)
  require_input_kind(input + "/public", 2)
  require_input_kind(source, 1)
  let bytes = read_bytes(source)
  store_media(input, name, bytes)
}

///|
pub fn store_media(
  input : String,
  name : String,
  bytes : Bytes,
) -> MediaItem raise {
  require_media_destination(name)
  let directory = open_authoring_subdirectory(input, "public")
  defer directory_close(directory.fd)
  directory.lock()
  let path = input + "/public/" + name
  if directory.kind(name) != 0 {
    raise InvalidInput("Media target must not exist: " + path)
  }
  directory.write_new(name, bytes)
  media_item(name, bytes)
}
