///|
pub(all) struct Page {
  output : String
  document : Document
}

///|
pub fn url_component(text : String) -> String {
  let out = StringBuilder()
  for b in @utf8.encode(text) {
    let c = b.to_int().unsafe_to_char()
    if c.is_ascii_alphabetic() ||
      c.is_ascii_digit() ||
      c == '-' ||
      c == '_' ||
      c == '.' ||
      c == '~' {
      out.write_string(c.to_string())
    } else {
      out.write_string(
        "%" + @crypto.bytes_to_hex_string(Bytes::from_array([b])).to_upper(),
      )
    }
  }
  out.to_string()
}

///|
pub fn tag_filename(tag : String) -> String {
  "tag-" + @crypto.bytes_to_hex_string(@utf8.encode(tag)) + ".html"
}

///|
pub fn metadata_digest(page : Page) -> String {
  digest_text(
    [
      page.output,
      page.document.title,
      page.document.description,
      page.document.tags.to_json().stringify(),
      page.document.date.to_json().stringify(),
    ]
    .to_json()
    .stringify(),
  )
}

///|
fn collection_dependencies(
  pages : Array[Page],
  layout_digest : String,
) -> Array[Dependency] {
  let deps : Array[Dependency] = [
    { name: "collection-renderer", digest: digest_text("collection-v4"), },
    { name: "layout.html", digest: layout_digest, },
    {
      name: "members",
      digest: digest_text(pages.map(p => p.output).to_json().stringify()),
    },
  ]
  for page in pages {
    deps.push({
      name: "metadata/" + page.output,
      digest: metadata_digest(page),
    })
  }
  deps
}

///|
pub fn render_collection(title : String, pages : Array[Page]) -> String {
  let out = StringBuilder()
  out.write_string(
    "<h1>" + escape_html(title) + "</h1>\n<ul class=\"articles\">\n",
  )
  for page in chronological_pages(pages) {
    out.write_string(
      "<li><a href=\"" +
      url_component(page.output) +
      "\">" +
      escape_html(page.document.title) +
      "</a>",
    )
    if page.document.date is Some(date) {
      out.write_string(
        " <time datetime=\"" +
        escape_html(date) +
        "\">" +
        escape_html(date) +
        "</time>",
      )
    }
    if !page.document.description.is_empty() {
      out.write_string("<p>" + escape_html(page.document.description) + "</p>")
    }
    if !page.document.tags.is_empty() {
      out.write_string("<ul class=\"tags\">")
      for tag in page.document.tags {
        out.write_string(
          "<li><a href=\"" +
          tag_filename(tag) +
          "\">" +
          escape_html(tag) +
          "</a></li>",
        )
      }
      out.write_string("</ul>")
    }
    out.write_string("</li>\n")
  }
  out.write_string("</ul>\n")
  out.to_string()
}
