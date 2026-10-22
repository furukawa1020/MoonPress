///|
pub(all) struct PostSnapshot {
  source : String
  content : String
  digest : String
} derive(ToJson)

///|
pub extend PostSnapshot with ToJson::{to_json}

///|
pub(all) struct SavePostReport {
  source : String
  digest : String
  changed : Bool
} derive(ToJson)

///|
pub extend SavePostReport with ToJson::{to_json}

///|
fn require_post_name(name : String) -> Unit raise {
  if !safe_output_name(name) ||
    !name.has_suffix(".md") ||
    name.length() <= 3 ||
    name.has_prefix(".") {
    raise InvalidInput("Post name must be a safe flat .md filename")
  }
}

///|
pub fn read_post(input : String, name : String) -> PostSnapshot raise {
  require_post_name(name)
  let directory = open_authoring_subdirectory(input, "content")
  defer directory_close(directory.fd)
  read_post_at(directory, name)
}

///|
fn read_post_at(
  directory : AuthoringDirectory,
  name : String,
) -> PostSnapshot raise {
  let content = decode_text(directory.read(name), directory.path + "/" + name)
  { source: "content/" + name, content, digest: digest_text(content), }
}

///|
fn verify_post_stage(
  directory : AuthoringDirectory,
  bytes : Bytes,
) -> Unit raise {
  if directory.read(".moonpress-edit") != bytes {
    raise InvalidInput("Staged post differs from requested content")
  }
}

///|
fn require_post_version(
  snapshot : PostSnapshot,
  expected : String,
) -> Unit raise {
  if !valid_digest(expected) {
    raise InvalidInput("Expected post digest must be a lowercase SHA-256 value")
  }
  if snapshot.digest != expected {
    raise InvalidInput(
      "Post changed since it was read; reload before saving: " + snapshot.source,
    )
  }
}

///|
pub fn save_post(
  input : String,
  name : String,
  expected : String,
  content : String,
) -> SavePostReport raise {
  require_post_name(name)
  let directory = open_authoring_subdirectory(input, "content")
  defer directory_close(directory.fd)
  directory.lock()
  let current = read_post_at(directory, name)
  require_post_version(current, expected)
  let _ = parse_document(
    content,
    name[:name.length() - 3].to_owned(),
    filename=current.source,
  )
  let stage = input + "/content/.moonpress-edit"
  if directory.kind(".moonpress-edit") != 0 {
    raise InvalidInput(
      "Post staging path already exists; inspect before retrying: " + stage,
    )
  }
  let digest = digest_text(content)
  if content == current.content {
    directory.sync()
    return { source: current.source, digest, changed: false, }
  }
  if path_kind(input + "/.moonpress-history") != 0 {
    let vault = open_authoring_subdirectory(input, ".moonpress-history")
    defer directory_close(vault.fd)
    vault.lock()
    store_authoring_record(vault, name, current.content) |> ignore
  }
  let bytes = @utf8.encode(content)
  let file = directory.create(".moonpress-edit")
  let mut prepared = false
  let mut verified = false
  let mut committed = false
  try {
    directory.write(file, ".moonpress-edit", bytes, Some(name))
    prepared = true
    verify_post_stage(directory, bytes)
    verified = true
    require_post_version(read_post_at(directory, name), expected)
    directory.publish(".moonpress-edit", name, false)
    committed = true
    directory.sync()
  } catch {
    error => {
      if committed {
        raise InvalidInput(
          "Post replacement is visible, but durability is unconfirmed; reload before retrying: \{error}",
        )
      }
      let cleanup = if prepared && !verified {
        "; unverified staging retained: " + stage
      } else {
        try {
          if prepared {
            verify_post_stage(directory, bytes)
          } else {
            directory.require_file(".moonpress-edit")
          }
          directory.remove(".moonpress-edit")
          ""
        } catch {
          cause => "; cleanup incomplete; inspect " + stage + ": \{cause}"
        }
      }
      raise InvalidInput("Post save failed: \{error}" + cleanup)
    }
  }
  { source: current.source, digest, changed: true, }
}

///|
pub fn save_post_from_file(
  input : String,
  name : String,
  expected : String,
  replacement : String,
) -> SavePostReport raise {
  require_input_kind(replacement, 1)
  save_post(input, name, expected, read_text(replacement))
}
