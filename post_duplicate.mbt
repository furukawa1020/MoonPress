///|
fn duplicate_source(
  source : String,
  name : String,
  title : String,
) -> String raise {
  let _ = parse_document(source, name, filename=name)
  if title.trim().is_empty() {
    raise InvalidInput("Article title must not be empty")
  }
  let (metadata, body) = document_parts(source, name)
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput("Frontmatter must be an object")
  }
  fields["title"] = title.to_json()
  fields["draft"] = true.to_json()
  fields.remove("slug")
  fields.remove("date")
  "---\n" + metadata.stringify() + "\n---\n" + body
}

///|
pub fn duplicate_post(
  input : String,
  name : String,
  expected : String,
  slug : String,
  title : String,
) -> NewPostReport raise {
  let snapshot = read_post(input, name)
  require_post_version(snapshot, expected)
  let content = duplicate_source(snapshot.content, name, title)
  create_draft_content(input, slug, content, directory => {
    require_post_version(read_post_at(directory, name), expected)
  })
}
