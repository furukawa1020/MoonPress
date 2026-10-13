///|
pub(all) struct ManifestDifference {
  name : String
  action : String
  content_changed : Bool
  old_digest : String?
  new_digest : String?
  dependencies : Array[DependencyChange]
} derive(ToJson)

///|
pub extend ManifestDifference with ToJson::{to_json}

///|
pub(all) struct ManifestDiff {
  added : Int
  removed : Int
  changed : Int
  unchanged : Int
  outputs : Array[ManifestDifference]
} derive(ToJson)

///|
pub extend ManifestDiff with ToJson::{to_json}

///|
pub fn compare_manifests(old : String, next : String) -> ManifestDiff raise {
  let before = artifact_map(parse_manifest(old).artifacts)
  let after = artifact_map(parse_manifest(next).artifacts)
  let names : Array[String] = []
  for name, _ in before {
    names.push(name)
  }
  for name, _ in after {
    if !before.contains(name) {
      names.push(name)
    }
  }
  names.sort()
  let outputs : Array[ManifestDifference] = []
  let mut added = 0
  let mut removed = 0
  let mut changed = 0
  let mut unchanged = 0
  for name in names {
    let previous = before.get(name)
    let current = after.get(name)
    let old_digest = previous.map(artifact => artifact.digest)
    let new_digest = current.map(artifact => artifact.digest)
    let dependencies = dependency_changes(
      match previous {
        None => []
        Some(artifact) => artifact.dependencies
      },
      match current {
        None => []
        Some(artifact) => artifact.dependencies
      },
    )
    let content_changed = old_digest != new_digest
    let action = match (previous, current) {
      (None, Some(_)) => {
        added += 1
        "added"
      }
      (Some(_), None) => {
        removed += 1
        "removed"
      }
      _ =>
        if content_changed || !dependencies.is_empty() {
          changed += 1
          "changed"
        } else {
          unchanged += 1
          "unchanged"
        }
    }
    outputs.push({
      name,
      action,
      content_changed,
      old_digest,
      new_digest,
      dependencies,
    })
  }
  { added, removed, changed, unchanged, outputs, }
}
