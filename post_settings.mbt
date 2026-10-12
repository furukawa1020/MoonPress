///|
pub(all) struct PostSettings {
  slug : String
  listed : Bool
  layout : String
} derive(ToJson)

///|
pub extend PostSettings with ToJson::{to_json}

///|
pub fn post_settings(
  source : String,
  filename? : String = "document",
) -> PostSettings raise {
  let doc = parse_document(source, filename, filename~)
  {
    slug: doc.slug.unwrap_or(""),
    listed: doc.listed,
    layout: doc.layout.unwrap_or(""),
  }
}

///|
fn source_with_settings(
  source : String,
  name : String,
  edit : PostSettings,
) -> String raise {
  let previous = post_settings(source, filename=name)
  if edit.slug == previous.slug &&
    edit.listed == previous.listed &&
    edit.layout == previous.layout {
    return source
  }
  let (metadata, body) = document_parts(source, name)
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput("Frontmatter must be an object")
  }
  for
    (key, value, old) in [
      ("slug", edit.slug, previous.slug),
      ("layout", edit.layout, previous.layout),
    ] {
    if value != old {
      if value.is_empty() {
        fields.remove(key)
      } else {
        fields[key] = value.to_json()
      }
    }
  }
  if edit.listed != previous.listed {
    fields["listed"] = edit.listed.to_json()
  }
  let result = "---\n" + metadata.stringify() + "\n---\n" + body
  let _ = parse_document(result, name, filename=name)
  result
}

///|
pub fn save_post_settings(
  input : String,
  name : String,
  expected : String,
  edit : PostSettings,
) -> SavePostReport raise {
  let snapshot = read_post(input, name)
  require_post_version(snapshot, expected)
  save_post(
    input,
    name,
    expected,
    source_with_settings(snapshot.content, name, edit),
  )
}
