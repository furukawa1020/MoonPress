///|
fn post_form_text(text : String) -> String {
  text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
}

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
  let body = post_form_text(edit.body)
  let tags = post_form_text(edit.tags)
  if post_form_text(edit.title) == post_form_text(previous.title) &&
    post_form_text(edit.description) == post_form_text(previous.description) &&
    edit.date == previous.date &&
    body == post_form_text(previous.body) &&
    tags == post_form_text(previous.tags) {
    return source
  }
  let (metadata, _) = document_parts(source, name)
  let fields = match metadata {
    Object(fields) => fields
    _ => raise InvalidInput("Frontmatter must be an object")
  }
  for
    (key, value, old) in [
      ("title", edit.title, previous.title),
      ("description", edit.description, previous.description),
      ("date", edit.date, previous.date),
    ] {
    let unchanged = if key == "date" {
      value == old
    } else {
      post_form_text(value) == post_form_text(old)
    }
    if !unchanged {
      if value.is_empty() {
        fields.remove(key)
      } else {
        fields[key] = value.to_json()
      }
    }
  }
  let values : Array[String] = []
  for line in tags.split("\n") {
    let tag = line.trim().to_owned()
    if !tag.is_empty() && !values.contains(tag) {
      values.push(tag)
    }
  }
  if tags != post_form_text(previous.tags) {
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
