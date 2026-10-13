///|
fn strict_json_object(
  value : Json,
  allowed : Array[String],
  context : String,
) -> Map[String, Json] raise {
  let fields = match value {
    Object(fields) => fields
    _ => raise InvalidInput(context + ": expected an object")
  }
  for key, _ in fields {
    if !allowed.contains(key) {
      raise InvalidInput(
        context + ": unknown field " + key.to_json().stringify(),
      )
    }
  }
  fields
}

///|
fn check_manifest_fields(value : Json) -> Unit raise {
  let fields = strict_json_object(
    value,
    ["schema", "compiler", "artifacts"],
    "manifest",
  )
  let artifacts = match fields.get("artifacts") {
    Some(Array(items)) => items
    _ => raise InvalidInput("manifest: artifacts must be an array")
  }
  for artifact in artifacts {
    let fields = strict_json_object(
      artifact,
      ["name", "digest", "dependencies"],
      "manifest artifact",
    )
    let dependencies = match fields.get("dependencies") {
      Some(Array(items)) => items
      _ =>
        raise InvalidInput("manifest artifact: dependencies must be an array")
    }
    for dependency in dependencies {
      let _ = strict_json_object(
        dependency,
        ["name", "digest"],
        "manifest dependency",
      )
    }
  }
}
