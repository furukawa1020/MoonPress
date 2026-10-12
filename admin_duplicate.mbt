///|
fn admin_duplicate_form(
  token : String,
  name : String,
  version : String,
  slug : String,
  title : String,
) -> String {
  "<h2>Duplicate saved article</h2><form method=\"post\" action=\"/duplicate\">" +
  admin_hidden("token", token) +
  admin_hidden("name", name) +
  admin_hidden("version", version) +
  "<p>Copy the saved source into a new draft; unsaved editor text is excluded. The original stays unchanged. Old URL and date are cleared; links are copied literally. Validate the copy before marking it ready.</p><label>New file stem<input name=\"slug\" required value=\"" +
  escape_html(slug) +
  "\"></label><label>New title<input name=\"title\" required value=\"" +
  escape_html(title) +
  "\"></label><button>Duplicate into new draft</button></form>"
}
