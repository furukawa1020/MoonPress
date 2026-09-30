///|
fn require_xml_text(text : String, source : String) -> Unit raise {
  for c in text {
    let n = c.to_int()
    if !(n == 9 ||
      n == 10 ||
      n == 13 ||
      (n >= 0x20 && n <= 0xD7FF) ||
      (n >= 0xE000 && n <= 0xFFFD) ||
      (n >= 0x10000 && n <= 0x10FFFF)) {
      raise InvalidInput(source + ": invalid XML character")
    }
  }
}

///|
fn validate_feed(base_url : String, pages : Array[Page]) -> Unit raise {
  require_xml_text(base_url, "site.json: base_url")
  for page in pages {
    require_xml_text(page.document.title, page.output + ": title")
    require_xml_text(page.document.description, page.output + ": description")
    for tag in page.document.tags {
      require_xml_text(tag, page.output + ": tag")
    }
  }
}

///|
fn feed_dependencies(
  base_url : String,
  config : FeedConfig,
  pages : Array[Page],
) -> Array[Dependency] {
  let deps : Array[Dependency] = [
    { name: "feed-renderer", digest: digest_text("rss-v1"), },
    {
      name: "site.json/feed",
      digest: digest_text(
        [base_url, config.title, config.description].to_json().stringify(),
      ),
    },
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
fn render_feed(
  base_url : String,
  config : FeedConfig,
  pages : Array[Page],
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<rss version=\"2.0\"><channel>\n",
  )
  out.write_string("<title>" + escape_html(config.title) + "</title>\n")
  out.write_string(
    "<link>" + escape_html(base_url + "articles.html") + "</link>\n",
  )
  out.write_string(
    "<description>" + escape_html(config.description) + "</description>\n",
  )
  for page in chronological_pages(pages) {
    let url = escape_html(base_url + url_component(page.output))
    out.write_string(
      "<item><title>" + escape_html(page.document.title) + "</title>",
    )
    out.write_string(
      "<link>" + url + "</link><guid isPermaLink=\"true\">" + url + "</guid>",
    )
    // RSS item descriptions contain entity-encoded HTML. Escape plain metadata
    // once as HTML, then again for the enclosing XML text node.
    out.write_string(
      "<description>" +
      escape_html(escape_html(page.document.description)) +
      "</description>",
    )
    for tag in page.document.tags {
      out.write_string("<category>" + escape_html(tag) + "</category>")
    }
    out.write_string("</item>\n")
  }
  out.write_string("</channel></rss>\n")
  out.to_string()
}
