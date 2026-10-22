///|
pub(all) struct WxrExport {
  xml : String
  posts : Int
  warnings : Array[String]
} derive(ToJson)

///|
pub extend WxrExport with ToJson::{to_json}

///|
fn wxr_element(name : String, value : String) -> String raise {
  require_xml_text(value, "WXR " + name)
  "<" +
  name +
  ">" +
  escape_html(value).replace_all(old="\r", new="&#13;") +
  "</" +
  name +
  ">\n"
}

///|
pub fn export_wordpress(input : String, base_url : String) -> WxrExport raise {
  let base_url = normalize_base_url(base_url)
  let directory = open_authoring_subdirectory(input, "content")
  defer directory_close(directory.fd)
  directory.lock()
  let names = post_names(input)
  if names.length() > 4096 {
    raise InvalidInput("WXR export is limited to 4096 source files")
  }
  let instant = authoring_time()
  let warnings : Array[String] = [
    "Private migration data includes drafts and exact source text. Keep it off public hosting.",
    "Themes, plugins, users, comments, attachment files and rewritten permalinks are not migrated.",
  ]
  let out = StringBuilder()
  out.write_string(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<rss version=\"2.0\" xmlns:excerpt=\"http://wordpress.org/export/1.2/excerpt/\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:wp=\"http://wordpress.org/export/1.2/\"><channel>\n",
  )
  out.write_string(wxr_element("title", "MoonPress migration"))
  out.write_string(wxr_element("link", base_url))
  out.write_string(
    wxr_element("description", "Native MoonPress content export"),
  )
  out.write_string(wxr_element("wp:wxr_version", "1.2"))
  out.write_string(wxr_element("wp:base_site_url", base_url))
  out.write_string(wxr_element("wp:base_blog_url", base_url))
  out.write_string(
    "<wp:author><wp:author_id>1</wp:author_id><wp:author_login>moonpress</wp:author_login><wp:author_display_name>MoonPress</wp:author_display_name></wp:author>\n",
  )
  let mut count = 0
  let mut total = 0
  for name in names {
    if !name.has_suffix(".md") {
      continue
    }
    require_post_name(name)
    let bytes = directory.read(name, max_bytes=4194304)
    total += bytes.length()
    if total > 16777216 {
      raise InvalidInput("WXR source total exceeds 16 MiB")
    }
    let source = decode_text(bytes, name)
    let stem = name[:name.length() - 3].to_owned()
    let document = parse_document(source, stem, filename=name)
    let status = if document.draft || !document.listed {
      "draft"
    } else if !publication_due(document.publish_at, instant) {
      "future"
    } else {
      "publish"
    }
    if !document.listed {
      warnings.push(
        name +
        ": unlisted maps to draft; WordPress has no equivalent visibility",
      )
    }
    let date = match document.publish_at {
      Some(timestamp) => timestamp[:19].to_owned().replace_all(old="T", new=" ")
      None => document.date.unwrap_or("1970-01-01") + " 00:00:00"
    }
    count += 1
    out.write_string("<item>\n")
    out.write_string(wxr_element("title", document.title))
    out.write_string(
      wxr_element(
        "link",
        base_url + url_component(document.slug.unwrap_or(stem) + ".html"),
      ),
    )
    out.write_string(wxr_element("dc:creator", "moonpress"))
    out.write_string(wxr_element("guid", "urn:moonpress:" + digest_text(name)))
    out.write_string(
      wxr_element("content:encoded", render_markdown(document.body)),
    )
    out.write_string(wxr_element("excerpt:encoded", document.description))
    out.write_string(wxr_element("wp:post_id", count.to_string()))
    out.write_string(wxr_element("wp:post_date", date))
    out.write_string(wxr_element("wp:post_date_gmt", date))
    out.write_string(wxr_element("wp:post_name", document.slug.unwrap_or(stem)))
    out.write_string(wxr_element("wp:post_type", document.kind))
    out.write_string(wxr_element("wp:status", status))
    out.write_string(
      "<wp:post_parent>0</wp:post_parent><wp:menu_order>0</wp:menu_order><wp:comment_status>closed</wp:comment_status><wp:ping_status>closed</wp:ping_status><wp:is_sticky>0</wp:is_sticky>\n",
    )
    for category in document.categories {
      require_xml_text(category, name + " category")
      out.write_string(
        "<category domain=\"category\" nicename=\"" +
        escape_html("mp-" + digest_text(category)[:16].to_owned()) +
        "\">" +
        escape_html(category) +
        "</category>\n",
      )
    }
    for tag in document.tags {
      require_xml_text(tag, name + " tag")
      out.write_string(
        "<category domain=\"post_tag\" nicename=\"" +
        escape_html("mp-" + digest_text(tag)[:16].to_owned()) +
        "\">" +
        escape_html(tag) +
        "</category>\n",
      )
    }
    out.write_string(
      "<wp:postmeta>" +
      wxr_element("wp:meta_key", "_moonpress_source_v1") +
      wxr_element("wp:meta_value", source) +
      "</wp:postmeta>\n",
    )
    out.write_string(
      "<wp:postmeta>" +
      wxr_element("wp:meta_key", "_moonpress_filename_v1") +
      wxr_element("wp:meta_value", name) +
      "</wp:postmeta>\n</item>\n",
    )
  }
  out.write_string("</channel></rss>\n")
  let xml = out.to_string()
  if @utf8.encode(xml).length() > 67108864 {
    raise InvalidInput("WXR encoded output exceeds 64 MiB")
  }
  { xml, posts: count, warnings, }
}
