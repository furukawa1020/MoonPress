///|
fn media_snippet(item : MediaItem) -> String {
  (if item.image { "![Describe image]" } else { "[Download]" }) +
  "(" +
  item.url +
  ")"
}

///|
fn admin_media(input : String) -> String raise {
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
  admin_page("Media", out.to_string())
}
