///|
priv struct TagSummary {
  name : String
  count : Int
} derive(ToJson)

///|
fn tag_index_dependencies(
  tags : Array[TagSummary],
  layout_digest : String,
  layout_source? : String = "layout.html",
) -> Array[Dependency] {
  [
    { name: "tag-index-renderer", digest: digest_text("tag-index-v1"), },
    { name: layout_source, digest: layout_digest, },
    { name: "tag-counts", digest: digest_text(tags.to_json().stringify()), },
  ]
}

///|
fn render_tag_index(tags : Array[TagSummary]) -> String {
  let out = StringBuilder()
  out.write_string("<h1>Tags</h1>\n<ul class=\"tag-index\">\n")
  for tag in tags {
    let unit = if tag.count == 1 { "article" } else { "articles" }
    out.write_string(
      "<li><a href=\"" +
      tag_filename(tag.name) +
      "\">" +
      escape_html(tag.name) +
      "</a> <span class=\"tag-count\">(\{tag.count} " +
      unit +
      ")</span></li>\n",
    )
  }
  out.write_string("</ul>\n")
  out.to_string()
}
