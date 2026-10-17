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
  require_media_destination(name)
  let directory = open_authoring_directory(input + "/public")
  defer directory_close(directory.fd)
  directory.lock()
  let current_bytes = directory.read(name)
  let current = media_item(name, current_bytes)
  require_media_version(current, expected)
  let stage = input + "/public/.moonpress-media-edit"
  if directory.kind(".moonpress-media-edit") != 0 {
    raise InvalidInput(
      "Media replacement staging path already exists; inspect it before retrying: " +
      stage,
    )
  }
  if bytes == current_bytes {
    return { item: current, previous_digest: current.digest, changed: false, }
  }
  let item = media_item(name, bytes)
  let file = directory.create(".moonpress-media-edit")
  let mut prepared = false
  let mut verified = false
  try {
    directory.write(file, ".moonpress-media-edit", bytes, Some(name))
    prepared = true
    verify_media_stage(directory, bytes)
    verified = true
    require_media_version(media_item(name, directory.read(name)), expected)
    directory.publish(".moonpress-media-edit", name, false)
  } catch {
    error => {
      let cleanup = if prepared && !verified {
        "; unverified staging path retained for inspection: " + stage
      } else {
        try {
          if prepared {
            verify_media_stage(directory, bytes)
          } else {
            directory.require_file(".moonpress-media-edit")
          }
          directory.remove(".moonpress-media-edit")
          ""
        } catch {
          cause => "; cleanup incomplete; inspect " + stage + ": \{cause}"
        }
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

///|
fn verify_media_stage(
  directory : AuthoringDirectory,
  expected : Bytes,
) -> Unit raise {
  let stage = directory.path + "/.moonpress-media-edit"
  try {
    directory.require_file(".moonpress-media-edit")
    if directory.read(".moonpress-media-edit") != expected {
      raise InvalidInput("Staged bytes differ from the requested replacement")
    }
  } catch {
    error =>
      raise InvalidInput(
        "Media staging could not be verified; inspect before retrying: " +
        stage +
        ": \{error}",
      )
  }
}
