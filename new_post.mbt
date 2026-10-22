///|
pub(all) struct NewPostReport {
  source : String
  output : String
  title : String
  draft : Bool
} derive(ToJson)

///|
pub extend NewPostReport with ToJson::{to_json}

///|
fn draft_source(title : String) -> String raise {
  if title.trim().is_empty() {
    raise InvalidInput("Article title must not be empty")
  }
  let metadata : Json = { "title": title, "draft": true }
  "---\n" + metadata.stringify() + "\n---\n\nWrite your article here.\n"
}

///|
fn create_draft_content(
  input : String,
  slug : String,
  content : String,
  verify : (AuthoringDirectory) -> Unit raise,
) -> NewPostReport raise {
  if !valid_slug(slug) {
    raise InvalidInput(
      "Article slug must be a safe flat output stem (at most 250 UTF-8 bytes)",
    )
  }
  let document = parse_document(content, slug)
  if !document.draft || document.slug is Some(_) {
    raise InvalidInput("New articles must be drafts with filename routes")
  }
  let directory = open_authoring_subdirectory(input, "content")
  defer directory_close(directory.fd)
  directory.lock()
  let source = "content/" + slug + ".md"
  let name = slug + ".md"
  let path = input + "/" + source
  verify(directory)
  if directory.kind(name) != 0 {
    raise InvalidInput("Article target must not exist: " + path)
  }
  directory.write_new(name, @utf8.encode(content))
  { source, output: slug + ".html", title: document.title, draft: true, }
}

///|
pub fn new_post(
  input : String,
  slug : String,
  title : String,
) -> NewPostReport raise {
  create_draft_content(input, slug, draft_source(title), _ => ())
}
