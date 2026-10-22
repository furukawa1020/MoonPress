///|
pub fn save_post_kind(
  input : String,
  name : String,
  expected : String,
  kind : String,
) -> SavePostReport raise {
  if kind != "post" && kind != "page" {
    raise InvalidInput("Kind must be post or page")
  }
  let snapshot = read_post(input, name)
  require_post_version(snapshot, expected)
  let document = parse_document(snapshot.content, name)
  if document.kind == kind {
    return save_post(input, name, expected, snapshot.content)
  }
  let (metadata, body) = document_parts(snapshot.content, name)
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput("Frontmatter must be an object")
  }
  fields["kind"] = kind.to_json()
  save_post(
    input,
    name,
    expected,
    "---\n" + metadata.stringify() + "\n---\n" + body,
  )
}

///|
pub fn filter_post_kind(
  posts : Array[PostSummary],
  kind : String,
) -> Array[PostSummary] raise {
  if kind != "all" && kind != "post" && kind != "page" {
    raise InvalidInput("Kind filter must be all, post or page")
  }
  posts.filter(post => kind == "all" || post.kind == kind)
}
