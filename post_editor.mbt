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
fn post_path(input : String, name : String) -> String raise {
  if !safe_output_name(name) ||
    !name.has_suffix(".md") ||
    name.length() <= 3 ||
    name.has_prefix(".") {
    raise InvalidInput("Post name must be a safe flat .md filename")
  }
  require_input_kind(input, 2)
  require_input_kind(input + "/content", 2)
  let path = input + "/content/" + name
  require_input_kind(path, 1)
  path
}

///|
pub fn read_post(input : String, name : String) -> PostSnapshot raise {
  let path = post_path(input, name)
  let content = read_text(path)
  { source: "content/" + name, content, digest: digest_text(content), }
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
  let path = post_path(input, name)
  let lock = lock_output(path, shared=false)
  defer native_unlock_output(lock)
  let current = read_post(input, name)
  require_post_version(current, expected)
  let _ = parse_document(
    content,
    name[:name.length() - 3].to_owned(),
    filename=current.source,
  )
  let digest = digest_text(content)
  if content == current.content {
    return { source: current.source, digest, changed: false, }
  }
  let stage = input + "/content/.moonpress-edit"
  let file = open_file(stage, 2)
  try {
    write_opened_file(
      file,
      stage,
      @utf8.encode(content),
      mode_source=Some(path),
    )
    require_post_version(read_post(input, name), expected)
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
