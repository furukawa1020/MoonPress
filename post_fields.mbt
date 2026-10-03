///|
pub(all) struct PostFields {
  title : String
  description : String
  date : String
  tags : String
  body : String
}

///|
fn post_fields(source : String, name : String) -> PostFields raise {
  let document = parse_document(source, name, filename=name)
  let (metadata, _) = document_parts(source, name)
  let title = match metadata {
    Object(fields) =>
      match fields.get("title") {
        Some(String(title)) => title
        _ => ""
      }
    _ => ""
  }
  {
    title,
    description: document.description,
    date: document.date.unwrap_or(""),
    tags: document.tags.join("\n"),
    body: document.body,
  }
}

///|
fn source_with_fields(
  source : String,
  name : String,
  edit : PostFields,
) -> String raise {
  let previous = post_fields(source, name)
  let body = edit.body.replace_all(old="\r\n", new="\n")
  let tags = edit.tags.replace_all(old="\r\n", new="\n")
  if edit.title == previous.title &&
    edit.description == previous.description &&
    edit.date == previous.date &&
    body == previous.body &&
    tags == previous.tags {
    return source
  }
  let (metadata, _) = document_parts(source, name)
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput("Frontmatter must be an object")
  }
  for
    (key, value) in [
      ("title", edit.title),
      ("description", edit.description),
      ("date", edit.date),
    ] {
    if value.is_empty() {
      fields.remove(key)
    } else {
      fields[key] = value.to_json()
    }
  }
  let values : Array[String] = []
  for line in tags.split("\n") {
    let tag = line.trim().to_owned()
    if !tag.is_empty() && !values.contains(tag) {
      values.push(tag)
    }
  }
  if tags != previous.tags {
    fields["tags"] = values.to_json()
  }
  let result = "---\n" + metadata.stringify() + "\n---\n" + body
  let _ = parse_document(result, name, filename=name)
  result
}

///|
pub fn save_post_fields(
  input : String,
  name : String,
  expected : String,
  edit : PostFields,
) -> SavePostReport raise {
  let snapshot = read_post(input, name)
  require_post_version(snapshot, expected)
  let content = source_with_fields(snapshot.content, name, edit)
  save_post(input, name, expected, content)
}
