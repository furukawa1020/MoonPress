///|
fn media_snippet(item : MediaItem) -> String {
  (if item.image { "![Describe image]" } else { "[Download]" }) +
  "(" +
  item.url +
  ")"
}

///|
fn admin_media(input : String, token : String) -> String raise {
  let report = list_media(input)
  let out = StringBuilder()
  out.write_string(
    "<p>Media: \{report.items.length()}. Copy a Markdown snippet into an article and replace the label with a description. Image classification uses filename extensions; files are not inspected or served here.</p>",
  )
  if report.items.is_empty() {
    out.write_string(
      "<p>No public assets yet. Add supported files to the site's public directory.</p>",
    )
  }
  for item in report.items {
    out.write_string(
      "<section><h2>" +
      escape_html(item.source) +
      "</h2><p>\{item.bytes} bytes · SHA-256 <code>" +
      item.digest +
      "</code></p><label>Markdown snippet<textarea readonly rows=\"2\" style=\"min-height:4rem\">\n" +
      escape_html(media_snippet(item)) +
      "</textarea></label></section>",
    )
  }
  admin_page("Media", out.to_string() + admin_import_form(token, "", ""))
}

///|
fn admin_import_form(token : String, source : String, name : String) -> String {
  "<h2>Import a local file</h2><form method=\"post\" action=\"/import\">" +
  admin_hidden("token", token) +
  "<p>The file must be on the same computer as MoonPress. Create a real public directory inside the site first. Existing assets are never overwritten. This copies bytes; it does not upload from your browser or deploy.</p><label>Local source file path<input name=\"source\" required value=\"" +
  escape_html(source) +
  "\"></label><label>Destination filename (for example, photo.png)<input name=\"name\" required value=\"" +
  escape_html(name) +
  "\"></label><button>Import media</button></form>"
}
