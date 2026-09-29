///|
pub(all) struct Document {
  title : String
  description : String
  tags : Array[String]
  body : String
  draft : Bool
  layout : String?
  date : String?
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
  let mut explicit_title : String? = None
  let mut description = ""
  let mut layout : String? = None
  let mut date : String? = None
  let mut draft = false
  let tags : Array[String] = []
  for key, value in fields {
    match (key, value) {
      ("title", String(text)) => {
        if text.trim().is_empty() {
          raise InvalidInput(filename + ":2: title must not be empty")
        }
        explicit_title = Some(text)
      }
      ("layout", String(name)) => {
        if !valid_layout_name(name) {
          raise InvalidInput(
            filename + ":2: layout must be a safe .html filename",
          )
        }
        layout = Some(name)
      }
      ("date", String(value)) => {
        if !valid_publication_date(value) {
          raise InvalidInput(
            filename +
            ":2: date must be a valid YYYY-MM-DD calendar date (0001-9999)",
          )
        }
        date = Some(value)
      }
      ("description", String(text)) => description = text
      ("draft", True) => draft = true
      ("draft", False) => draft = false
      ("tags", Array(items)) =>
        for item in items {
          match item {
            String(tag) => {
              let tag = tag.trim().to_owned()
              if tag.is_empty() || @utf8.encode(tag).length() > 96 {
                raise InvalidInput(
                  filename + ":2: tags must contain 1–96 UTF-8 bytes",
                )
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
      ("title" | "description" | "tags" | "draft" | "layout" | "date", _) =>
        raise InvalidInput(filename + ":2: wrong type for " + key)
      (_, _) =>
        raise InvalidInput(filename + ":2: unknown metadata key: " + key)
    }
  }
  tags.sort()
  let title = match explicit_title {
    Some(text) => text
    None => page_title(body, fallback)
  }
  { title, description, tags, body, draft, layout, date, }
}
