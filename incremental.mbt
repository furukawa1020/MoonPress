///|
pub(all) struct Dependency {
  name : String
  digest : String
} derive(Eq, ToJson, FromJson)

///|
pub(all) struct Artifact {
  name : String
  digest : String
  dependencies : Array[Dependency]
} derive(Eq, ToJson, FromJson)

///|
pub(all) struct Manifest {
  schema : Int
  compiler : String
  artifacts : Array[Artifact]
} derive(Eq, ToJson, FromJson)

///|
pub fn digest_bytes(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
pub fn digest_text(text : String) -> String {
  digest_bytes(@utf8.encode(text))
}

///|
pub fn safe_output_name(name : String) -> Bool {
  if name.is_empty() ||
    @utf8.encode(name).length() > 255 ||
    name == "." ||
    name == ".." ||
    name == ".moonpress.json" {
    return false
  }
  for c in name {
    if c == '/' || c == '\\' || c == ':' || c.to_int() < 32 || c.to_int() == 127 {
      return false
    }
  }
  true
}

///|
pub fn parse_manifest(text : String) -> Manifest raise {
  let state : Manifest = @json.from_json(@json.parse(text))
  if state.schema != 1 || state.compiler != "moonpress-0.1" {
    raise InvalidInput("Unsupported MoonPress manifest version")
  }
  let seen : Map[String, Bool] = Map([])
  for artifact in state.artifacts {
    if !safe_output_name(artifact.name) || seen.contains(artifact.name) {
      raise InvalidInput("Invalid or duplicate output path in manifest")
    }
    if !valid_digest(artifact.digest) {
      raise InvalidInput("Invalid output digest in manifest: " + artifact.name)
    }
    let dependencies : Map[String, Bool] = Map([])
    for dep in artifact.dependencies {
      if dep.name.is_empty() || dependencies.contains(dep.name) {
        raise InvalidInput(
          "Empty or duplicate dependency in manifest: " + artifact.name,
        )
      }
      if !valid_digest(dep.digest) {
        raise InvalidInput(
          "Invalid dependency digest in manifest: " +
          artifact.name +
          " / " +
          dep.name,
        )
      }
      dependencies[dep.name] = true
    }
    seen[artifact.name] = true
  }
  state
}

///|
pub fn serialize_manifest(artifacts : Array[Artifact]) -> String {
  let state : Manifest = { schema: 1, compiler: "moonpress-0.1", artifacts, }
  state.to_json().stringify() + "\n"
}

///|
pub fn rebuild_reason(
  old : Artifact?,
  dependencies : Array[Dependency],
) -> String? {
  match old {
    None => Some("new output")
    Some(previous) => {
      let old_deps : Map[String, String] = Map([])
      for dep in previous.dependencies {
        old_deps[dep.name] = dep.digest
      }
      for dep in dependencies {
        if old_deps.get(dep.name) != Some(dep.digest) {
          return Some("changed dependency: " + dep.name)
        }
      }
      if previous.dependencies.length() != dependencies.length() {
        return Some("dependency removed")
      }
      None
    }
  }
}

///|
pub extend Dependency with Eq::{not_equal, equal}

///|
pub extend Dependency with ToJson::{to_json}

///|
pub extend Dependency with @json.FromJson::{from_json}

///|
pub extend Artifact with Eq::{not_equal, equal}

///|
pub extend Artifact with ToJson::{to_json}

///|
pub extend Artifact with @json.FromJson::{from_json}

///|
pub extend Manifest with Eq::{not_equal, equal}

///|
pub extend Manifest with ToJson::{to_json}

///|
pub extend Manifest with @json.FromJson::{from_json}

///|
fn valid_digest(digest : String) -> Bool {
  digest.length() == 64 &&
  digest.all(c => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))
}
