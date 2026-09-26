///|
pub(all) struct Document {
  title : String
  description : String
  tags : Array[String]
  body : String
}

///|
pub fn parse_document(
  source : String,
  fallback : String,
  filename? : String = "document",
) -> Document raise {
  let normalized = source.replace_all(old="\r\n", new="\n")
  let mut body = normalized
  let mut metadata : Json = Json::empty_object()
  if normalized.has_prefix("---\n") {
    let remainder = normalized[4:].to_owned()
    let (header, content) = match remainder.split_once("\n---\n") {
      Some((header, content)) => (header.to_owned(), content.to_owned())
      None =>
        if remainder.has_suffix("\n---") {
          (remainder[:remainder.length() - 4].to_owned(), "")
        } else {
          raise InvalidInput(filename + ":1: unclosed JSON frontmatter")
        }
    }
    metadata = @json.parse(header) catch {
      error =>
        raise InvalidInput(
          filename + ": frontmatter starts at line 2: " + error.to_string(),
        )
    }
    body = content
  }
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput(filename + ":2: frontmatter must be a JSON object")
  }
  let mut title = page_title(body, fallback)
  let mut description = ""
  let tags : Array[String] = []
  for key, value in fields {
    match (key, value) {
      ("title", String(text)) => {
        if text.trim().is_empty() {
          raise InvalidInput(filename + ":2: title must not be empty")
        }
        title = text
      }
      ("description", String(text)) => description = text
      ("tags", Array(items)) =>
        for item in items {
          match item {
            String(tag) => {
              let tag = tag.trim().to_owned()
              if tag.is_empty() {
                raise InvalidInput(filename + ":2: tags must not be empty")
              }
              if !tags.contains(tag) {
                tags.push(tag)
              }
            }
            _ =>
              raise InvalidInput(
                filename + ":2: tags must be an array of strings",
              )
          }
        }
      ("title" | "description" | "tags", _) =>
        raise InvalidInput(filename + ":2: wrong type for " + key)
      (_, _) =>
        raise InvalidInput(filename + ":2: unknown metadata key: " + key)
    }
  }
  tags.sort()
  { title, description, tags, body, }
}
