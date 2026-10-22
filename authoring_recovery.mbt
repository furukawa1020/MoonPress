///|
pub(all) struct AuthoringStage {
  stage : String
  exists : Bool
  bytes : Int
  digest : String?
} derive(ToJson)

///|
pub extend AuthoringStage with ToJson::{to_json}

///|
pub(all) struct AuthoringRescue {
  stage : String
  backup : String
  bytes : Int
  digest : String
} derive(ToJson)

///|
pub extend AuthoringRescue with ToJson::{to_json}

///|
fn authoring_stage_location(
  input : String,
  kind : String,
) -> (AuthoringDirectory, String) raise {
  match kind {
    "post" => (open_authoring_subdirectory(input, "content"), ".moonpress-edit")
    "media" =>
      (open_authoring_subdirectory(input, "public"), ".moonpress-media-edit")
    "settings" => (open_authoring_directory(input), ".moonpress-settings-edit")
    _ => raise InvalidInput("Authoring kind must be post, media or settings")
  }
}

///|
pub fn inspect_authoring_stage(
  input : String,
  kind : String,
) -> AuthoringStage raise {
  let (directory, name) = authoring_stage_location(input, kind)
  defer directory_close(directory.fd)
  directory.lock()
  let stage = directory.path + "/" + name
  if directory.kind(name) == 0 {
    return { stage, exists: false, bytes: 0, digest: None, }
  }
  let bytes = directory.read(name, max_bytes=8388608)
  {
    stage,
    exists: true,
    bytes: bytes.length(),
    digest: Some(digest_bytes(bytes)),
  }
}

///|
pub fn rescue_authoring_stage(
  input : String,
  kind : String,
  expected : String,
  backup : String,
) -> AuthoringRescue raise {
  if !valid_digest(expected) {
    raise InvalidInput(
      "Expected staging digest must be a lowercase SHA-256 value",
    )
  }
  let parts = backup.split("/").map(part => part.to_owned()).to_array()
  let name = parts[parts.length() - 1]
  if !safe_output_name(name) ||
    name.has_prefix(".") ||
    !name.has_suffix(".backup") {
    raise InvalidInput(
      "Rescue destination must be a new visible .backup filename",
    )
  }
  let parent = if parts.length() == 1 {
    "."
  } else {
    parts.pop() |> ignore
    let path = parts.join("/")
    if path.is_empty() {
      "/"
    } else {
      path
    }
  }
  let (directory, stage_name) = authoring_stage_location(input, kind)
  defer directory_close(directory.fd)
  directory.lock()
  let bytes = directory.read(stage_name, max_bytes=8388608)
  if digest_bytes(bytes) != expected {
    raise InvalidInput("Authoring stage changed; inspect again before rescuing")
  }
  let destination = open_authoring_directory(parent)
  defer directory_close(destination.fd)
  if directory_same(directory.fd, destination.fd) != 1 {
    destination.lock()
  }
  destination.write_new(name, bytes, private_mode=true)
  if directory.read(stage_name, max_bytes=8388608) != bytes {
    raise InvalidInput(
      "Authoring stage changed; backup retained, stage not removed",
    )
  }
  directory.remove(stage_name)
  {
    stage: directory.path + "/" + stage_name,
    backup,
    bytes: bytes.length(),
    digest: expected,
  }
}
