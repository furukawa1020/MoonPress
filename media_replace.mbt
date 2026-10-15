///|
pub(all) struct ReplaceMediaReport {
  item : MediaItem
  previous_digest : String
  changed : Bool
} derive(ToJson)

///|
pub extend ReplaceMediaReport with ToJson::{to_json}

///|
fn require_media_version(item : MediaItem, expected : String) -> Unit raise {
  if !valid_digest(expected) {
    raise InvalidInput(
      "Expected media digest must be a lowercase SHA-256 value",
    )
  }
  if item.digest != expected {
    raise InvalidInput(
      "Media changed since it was read; reload before replacing: " + item.source,
    )
  }
}

///|
pub fn replace_media(
  input : String,
  name : String,
  expected : String,
  bytes : Bytes,
) -> ReplaceMediaReport raise {
  let path = media_path(input, name)
  let lock = lock_output(path, shared=false)
  defer native_unlock_output(lock)
  // Revalidate the path and bytes after acquiring the shared authoring lock.
  let current_bytes = read_bytes(media_path(input, name))
  let current = media_item(name, current_bytes)
  require_media_version(current, expected)
  let stage = input + "/public/.moonpress-media-edit"
  if path_kind(stage) != 0 {
    raise InvalidInput(
      "Media replacement staging path already exists; inspect it before retrying: " +
      stage,
    )
  }
  if bytes == current_bytes {
    return { item: current, previous_digest: current.digest, changed: false, }
  }
  let item = media_item(name, bytes)
  let file = open_file(stage, 2)
  try {
    write_opened_file(file, stage, bytes, mode_source=Some(path))
    require_media_version(read_media(input, name), expected)
    replace_staged_file(stage, path)
  } catch {
    error => {
      let cleanup = try {
        require_input_kind(stage, 1)
        @fs.remove_file(stage)
        ""
      } catch {
        cause => "; cleanup incomplete; inspect " + stage + ": \{cause}"
      }
      raise InvalidInput("Media replacement failed: \{error}" + cleanup)
    }
  }
  { item, previous_digest: current.digest, changed: true, }
}

///|
pub fn replace_media_from_file(
  input : String,
  name : String,
  expected : String,
  replacement : String,
) -> ReplaceMediaReport raise {
  require_input_kind(replacement, 1)
  replace_media(input, name, expected, read_bytes(replacement))
}
