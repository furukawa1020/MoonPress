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
  require_input_kind(input, 2)
  require_input_kind(input + "/public", 2)
  let path = input + "/public/" + name
  let lock = lock_output(path, shared=false)
  defer native_unlock_output(lock)
  if path_kind(path) != 0 {
    raise InvalidInput("Media target must not exist: " + path)
  }
  let file = open_file(path, 2)
  write_opened_file(file, path, bytes) catch {
    error => {
      let cleanup = try {
        require_input_kind(path, 1)
        @fs.remove_file(path)
        ""
      } catch {
        cause => "; cleanup incomplete; inspect " + path + ": \{cause}"
      }
      raise InvalidInput("Media import failed: \{error}" + cleanup)
    }
  }
  {
    source: "public/" + name,
    url: url_component(name),
    bytes: bytes.length(),
    digest: digest_bytes(bytes),
    image: image_asset_name(name),
  }
}
