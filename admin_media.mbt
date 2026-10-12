///|
fn media_snippet(item : MediaItem) -> String {
  (if item.image { "![Describe image]" } else { "[Download]" }) +
  "(" +
  item.url +
  ")"
}

///|
fn admin_media(
  input : String,
  token : String,
  fields : Map[String, String],
) -> String raise {
  for key, _ in fields {
    if key != "q" && key != "kind" {
      raise InvalidInput("Unknown media query field: " + key)
    }
  }
  let query = fields.get("q").unwrap_or("")
  let kind = fields.get("kind").unwrap_or("all")
  let _ = filter_media_references([], query, kind)
  let report = inspect_media_references(input)
  let matches = filter_media_references(report.assets, query, kind)
  if path_kind(input + "/public") == 0 {
    return admin_page(
      "Media",
      admin_media_search_form(query, kind) +
      "<p>" +
      escape_html(report.scope) +
      "</p>" +
      admin_post_problems(report.problems) +
      "<p>Media storage has not been prepared for this site.</p><form method=\"post\" action=\"/prepare-media\">" +
      admin_hidden("token", token) +
      "<p>Create an empty public directory for images and attachments. Existing files are never replaced.</p><button>Prepare media storage</button></form>",
    )
  }
  let out = StringBuilder()
  out.write_string(admin_media_search_form(query, kind))
  out.write_string(
    "<p>Showing \{matches.length()} of \{report.assets.length()} media assets.</p>",
  )
  out.write_string(
    "<p>Media: \{report.assets.length()}. Copy a Markdown snippet into an article and replace the label with a description. Image classification uses filename extensions; files are not inspected or served here.</p>",
  )
  if matches.is_empty() {
    out.write_string(
      "<p>No matching media assets. Clear filters or upload a supported file.</p>",
    )
  }
  out.write_string(
    "<p>" +
    escape_html(report.scope) +
    "</p>" +
    admin_post_problems(report.problems),
  )
  for asset in matches {
    let item = asset.item
    out.write_string(
      "<section><h2>" +
      escape_html(item.source) +
      "</h2><p>\{item.bytes} bytes · SHA-256 <code>" +
      item.digest +
      "</code></p><label>Markdown snippet<textarea readonly rows=\"2\" style=\"min-height:4rem\">\n" +
      escape_html(media_snippet(item)) +
      "</textarea></label>" +
      admin_media_posts(asset.posts) +
      "</section>",
    )
  }
  admin_page(
    "Media",
    out.to_string() +
    admin_upload_form(token, "") +
    admin_import_form(token, "", ""),
  )
}

///|
fn admin_import_form(token : String, source : String, name : String) -> String {
  "<h2>Import a local file</h2><form method=\"post\" action=\"/import\">" +
  admin_hidden("token", token) +
  "<p>The file must be on the same computer as MoonPress. Use Prepare media storage on the Media screen if needed. Existing assets are never overwritten. This copies bytes; it does not upload from your browser or deploy.</p><label>Local source file path<input name=\"source\" required value=\"" +
  escape_html(source) +
  "\"></label><label>Destination filename (for example, photo.png)<input name=\"name\" required value=\"" +
  escape_html(name) +
  "\"></label><button>Import media</button></form>"
}

///|
fn admin_media_posts(posts : Array[PostSummary]) -> String {
  if posts.is_empty() {
    return "<p>No references found in scanned article Markdown.</p>"
  }
  let out = StringBuilder()
  out.write_string("<h3>Referring articles</h3><ul>")
  for post in posts {
    out.write_string(
      "<li><a href=\"/edit?name=" +
      url_component(post.source[8:].to_owned()) +
      "\">" +
      escape_html(post.title) +
      "</a> · " +
      escape_html(post.source) +
      " · " +
      (if post.draft { "Draft" } else { "Ready" }) +
      (if post.listed { "" } else { " · unlisted" }) +
      "</li>",
    )
  }
  out.write_string("</ul>")
  out.to_string()
}

///|
fn admin_media_search_form(query : String, kind : String) -> String {
  let out = StringBuilder()
  out.write_string(
    "<form method=\"get\" action=\"/media\"><label>Search asset filenames<input name=\"q\" value=\"" +
    escape_html(query) +
    "\"></label><label>Type<select name=\"kind\">",
  )
  for
    (value, label) in [
      ("all", "All media"),
      ("images", "Images"),
      ("attachments", "Attachments"),
    ] {
    out.write_string(
      "<option value=\"" +
      value +
      "\"" +
      (if value == kind { " selected" } else { "" }) +
      ">" +
      label +
      "</option>",
    )
  }
  out.write_string(
    "</select></label><button>Search media</button> <a href=\"/media\">Clear filters</a></form>",
  )
  out.to_string()
}
