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
pub fn new_post(
  input : String,
  slug : String,
  title : String,
) -> NewPostReport raise {
  if !valid_slug(slug) {
    raise InvalidInput(
      "Article slug must be a safe flat output stem (at most 250 UTF-8 bytes)",
    )
  }
  let content = draft_source(title)
  require_input_kind(input, 2)
  require_input_kind(input + "/content", 2)
  let source = "content/" + slug + ".md"
  let path = input + "/" + source
  // Lock content/ for cooperating authoring writers; exclusive open also protects
  // against another creator winning the race after this preflight check.
  let lock = lock_output(path, shared=false)
  defer native_unlock_output(lock)
  if path_kind(path) != 0 {
    raise InvalidInput("Article target must not exist: " + path)
  }
  let file = open_file(path, 2)
  write_opened_file(file, path, @utf8.encode(content)) catch {
    error => {
      let cleanup = try {
        require_input_kind(path, 1)
        @fs.remove_file(path)
        ""
      } catch {
        cause => "; cleanup incomplete; inspect " + path + ": \{cause}"
      }
      raise InvalidInput("Article creation failed: \{error}" + cleanup)
    }
  }
  { source, output: slug + ".html", title, draft: true, }
}
