///|
fn normalized_categories(text : String) -> Array[String] raise {
  let result : Array[String] = []
  for line in text.replace_all(old="\r\n", new="\n").split("\n") {
    let value = line.trim().to_owned()
    if value.is_empty() {
      continue
    }
    if @utf8.encode(value).length() > 96 {
      raise InvalidInput("Categories are limited to 96 UTF-8 bytes")
    }
    if !result.contains(value) {
      result.push(value)
    }
    if result.length() > 64 {
      raise InvalidInput("At most 64 categories")
    }
  }
  result.sort()
  result
}

///|
pub fn save_post_categories(
  input : String,
  name : String,
  expected : String,
  categories : String,
) -> SavePostReport raise {
  let values = normalized_categories(categories)
  let snapshot = read_post(input, name)
  require_post_version(snapshot, expected)
  let document = parse_document(snapshot.content, name)
  if document.categories == values {
    return save_post(input, name, expected, snapshot.content)
  }
  let (metadata, body) = document_parts(snapshot.content, name)
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput("Frontmatter must be an object")
  }
  fields["categories"] = values.to_json()
  save_post(
    input,
    name,
    expected,
    "---\n" + metadata.stringify() + "\n---\n" + body,
  )
}
