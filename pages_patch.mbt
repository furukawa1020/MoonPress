///|
fn pages_patch_original_body(source : String) -> String {
  if !source.has_prefix("---\n") && !source.has_prefix("---\r\n") {
    return source
  }
  let lines = source.split("\n")
  lines.next() |> ignore
  for line in lines {
    if line == "---" || line == "---\r" {
      return lines.map(line => line.to_owned()).join("\n")
    }
  }
  ""
}

///|
pub fn apply_pages_patch(
  input : String,
  name : String,
  expected : String,
  patch_file : String,
) -> SavePostReport raise {
  require_input_kind(patch_file, 1)
  let patch = match @json.parse(read_text(patch_file)) {
    Object(fields) => fields
    _ => raise InvalidInput("Pages changes must be a JSON object")
  }
  let snapshot = read_post(input, name)
  require_post_version(snapshot, expected)
  let values = compose_values(snapshot, "", name)
  values["intent"] = "save"
  for key, value in patch {
    match (key, value) {
      ("listed", True) => values["listed"] = "yes"
      ("listed", False) => values["listed"] = "no"
      ("draft", True) => values["intent"] = "draft"
      ("draft", False) => values["intent"] = "ready"
      ("title", String(text)) if !text.trim().is_empty() =>
        values["title"] = text
      (
        "description"
        | "date"
        | "tags"
        | "categories"
        | "slug"
        | "layout"
        | "kind"
        | "publish_at",
        String(text),
      ) => values[key] = text
      _ => raise InvalidInput("Invalid Pages change: " + key)
    }
  }
  let source = compose_source(snapshot, name, values)
  if source == snapshot.content {
    return { source: snapshot.source, digest: snapshot.digest, changed: false, }
  }
  let (_, rendered_body) = document_parts(source, name)
  let frontmatter = source[:source.length() - rendered_body.length()].to_owned()
  save_post(
    input,
    name,
    expected,
    frontmatter + pages_patch_original_body(snapshot.content),
  )
}
