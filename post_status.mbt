///|
fn source_with_draft(
  source : String,
  filename : String,
  draft : Bool,
) -> String raise {
  let document = parse_document(source, filename, filename~)
  if document.draft == draft {
    return source
  }
  let (metadata, body) = document_parts(source, filename)
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput("Frontmatter must be an object")
  }
  fields["draft"] = draft.to_json()
  "---\n" + metadata.stringify() + "\n---\n" + body
}

///|
pub fn set_post_draft(
  input : String,
  name : String,
  expected : String,
  draft : Bool,
) -> SavePostReport raise {
  let snapshot = read_post(input, name)
  require_post_version(snapshot, expected)
  let content = source_with_draft(snapshot.content, name, draft)
  // save_post rechecks under the shared authoring lock before committing.
  save_post(input, name, expected, content)
}
