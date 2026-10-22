///|
fn admin_kind_form(source : String, name : String, hidden : String) -> String {
  try {
    let document = parse_document(source, name)
    "<form method=\"post\" action=\"/kind\">" +
    hidden +
    "<p>Save other edits before changing type. Pages stay public but leave article, tag and RSS lists.</p><label>Type<select name=\"kind\"><option value=\"post\"" +
    (if document.kind == "post" { " selected" } else { "" }) +
    ">Post</option><option value=\"page\"" +
    (if document.kind == "page" { " selected" } else { "" }) +
    ">Fixed page</option></select></label><button>Save type</button></form>"
  } catch {
    _ => ""
  }
}

///|
fn admin_categories_form(
  source : String,
  name : String,
  hidden : String,
) -> String {
  try {
    let document = parse_document(source, name)
    "<form method=\"post\" action=\"/categories\">" +
    hidden +
    "<p>Save other edits before changing categories. One name per line; tags are separate. Fixed pages, unlisted articles and drafts do not enter public category archives.</p><label>Categories<textarea name=\"categories\" rows=\"4\">\n" +
    escape_html(document.categories.join("\n")) +
    "</textarea></label><button>Save categories</button></form>"
  } catch {
    _ => ""
  }
}
