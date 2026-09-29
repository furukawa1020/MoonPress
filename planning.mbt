///|
priv struct Pending {
  artifact : Artifact
  content : Bytes?
}

///|
fn plan_artifact(
  name : String,
  dependencies : Array[Dependency],
  previous : Map[String, Artifact],
  output : String?,
  render : () -> Bytes,
  log : BuildLog,
) -> Pending raise {
  if !safe_output_name(name) {
    raise InvalidInput("Invalid output name: " + name)
  }
  let old = previous.get(name)
  let reason = match rebuild_reason(old, dependencies) {
    Some(reason) => Some(reason)
    None =>
      match output {
        Some(directory) =>
          if path_kind(directory + "/" + name) == 0 {
            Some("output missing")
          } else {
            None
          }
        None => Some("validation only")
      }
  }
  if reason is None && old is Some(artifact) {
    record_event(log, "keep", name, "dependencies unchanged")
    return { artifact, content: None, }
  }
  let content = render()
  let artifact : Artifact = {
    name,
    digest: digest_bytes(content),
    dependencies,
  }
  record_event(log, "write", name, reason.unwrap_or("dependency changed"))
  { artifact, content: Some(content), }
}

///|
priv struct BuildPlan {
  pending : Array[Pending]
  removed : Array[String]
  manifest : String
  report : BuildReport
}

///|
priv struct BuildLog {
  events : Array[String]
  changes : Array[BuildEvent]
}

///|
fn record_event(
  log : BuildLog,
  action : String,
  path : String,
  reason : String,
) -> Unit {
  log.changes.push({ action, path, reason, })
  log.events.push(action.to_upper() + " " + path + " — " + reason)
}
