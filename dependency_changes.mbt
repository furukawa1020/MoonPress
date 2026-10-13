///|
pub(all) struct DependencyChange {
  name : String
  action : String
  old_digest : String?
  new_digest : String?
} derive(ToJson)

///|
pub extend DependencyChange with ToJson::{to_json}

///|
fn dependency_index(
  dependencies : Array[Dependency],
  context : String,
) -> Map[String, String] raise {
  let result : Map[String, String] = Map([])
  for dep in dependencies {
    if dep.name.is_empty() || result.contains(dep.name) {
      raise InvalidInput("Empty or duplicate dependency in " + context)
    }
    if !valid_digest(dep.digest) {
      raise InvalidInput(
        "Invalid dependency digest in " + context + " / " + dep.name,
      )
    }
    result[dep.name] = dep.digest
  }
  result
}

///|
pub fn dependency_changes(
  old : Array[Dependency],
  next : Array[Dependency],
) -> Array[DependencyChange] raise {
  let before = dependency_index(old, "old dependencies")
  let after = dependency_index(next, "new dependencies")
  let names = old.map(dep => dep.name)
  for dep in next {
    if !before.contains(dep.name) {
      names.push(dep.name)
    }
  }
  names.sort()
  let result : Array[DependencyChange] = []
  for name in names {
    let previous = before.get(name)
    let current = after.get(name)
    if previous != current {
      result.push({
        name,
        action: if previous is None {
          "added"
        } else if current is None {
          "removed"
        } else {
          "changed"
        },
        old_digest: previous,
        new_digest: current,
      })
    }
  }
  result
}
