///|
pub(all) struct WxrCandidate {
  id : String
  title : String
  original_status : String
  source : String?
  error : String?
  warnings : Array[String]
} derive(ToJson)

///|
pub extend WxrCandidate with ToJson::{to_json}

///|
pub(all) struct WxrImportPlan {
  digest : String
  items : Array[WxrCandidate]
} derive(ToJson)

///|
pub extend WxrImportPlan with ToJson::{to_json}

///|
fn wxr_plain_markdown(text : String) -> String {
  let out = StringBuilder()
  for c in text {
    if "\\`*_{}[]()#+-.!>|~=".contains(c.to_string()) {
      out.write_string("\\")
    }
    out.write_char(c)
  }
  out.to_string()
}

///|
fn wxr_html_entities(text : String) -> String raise {
  let out = StringBuilder()
  let mut rest = text[:]
  while rest.split_once("&") is Some((before, after)) {
    out.write_string(before.to_owned())
    match after.split_once(";") {
      Some((entity, next)) if !entity.is_empty() &&
        entity.length() <= 32 &&
        !entity.any(c => c.is_whitespace() || c == '&' || c == '<') => {
        out.write_string(
          if entity == "nbsp" {
            "\u00A0"
          } else {
            wxr_decode("&" + entity.to_owned() + ";")
          },
        )
        rest = next
      }
      _ => {
        out.write_string("&")
        rest = after
      }
    }
  }
  out.write_string(rest.to_owned())
  out.to_string()
}

///|
fn wxr_has_markup(text : String) -> Bool {
  let mut remaining = text[:]
  while remaining.split_once("<") is Some((_, after)) {
    if !after.is_empty() &&
      after[:1].any(c => {
        c.is_ascii_alphabetic() || c == '/' || c == '!' || c == '?'
      }) {
      return true
    }
    remaining = after
  }
  false
}

///|
fn wxr_body(content : String) -> String raise {
  if !wxr_has_markup(content) {
    return wxr_html_entities(content)
      .split("\n")
      .map(line => wxr_plain_markdown(line.trim(chars=" \t\r").to_owned()))
      .to_array()
      .join("\n")
  }
  html_blocks(intake_html(content))
}

///|
fn wxr_candidate(item : WxrXml, id : String, title : String) -> WxrCandidate {
  let warnings : Array[String] = [
    "Imported as a private draft. Review links/assets and publication settings before marking ready.",
    "Original authors, URLs, GUIDs, discussion settings, sticky state, ordering and site-level options are not applied. Transient WordPress _edit_lock, _edit_last, _encloseme and _pingme markers are ignored.",
  ]
  let title = if title.trim().is_empty() {
    warnings.push("Empty WordPress title replaced with post ID label.")
    "WordPress post " + id
  } else {
    title
  }
  let mut status = ""
  try {
    status = item.field("wp:status")
    if !["publish", "draft", "pending", "future"].contains(status) {
      raise InvalidInput("Unsupported WordPress visibility/status: " + status)
    }
    let kind = item.field("wp:post_type")
    if kind != "post" && kind != "page" {
      raise InvalidInput("Only post/page types are supported")
    }
    if !item.field("wp:post_password").is_empty() {
      raise InvalidInput("Password-protected content is unsupported")
    }
    let parent = item.field("wp:post_parent")
    if !parent.is_empty() && parent != "0" {
      raise InvalidInput("Hierarchical pages require route/hierarchy migration")
    }
    let content = item.field("content:encoded")
    let tags : Array[String] = []
    let categories : Array[String] = []
    for child in item.children {
      if ![
          "title", "link", "pubDate", "dc:creator", "guid", "description", "content:encoded",
          "excerpt:encoded", "wp:post_id", "wp:post_date", "wp:post_date_gmt", "wp:post_modified",
          "wp:post_modified_gmt", "wp:comment_status", "wp:ping_status", "wp:post_name",
          "wp:status", "wp:post_parent", "wp:menu_order", "wp:post_type", "wp:post_password",
          "wp:is_sticky", "wp:postmeta", "wp:comment", "category",
        ].contains(child.name) {
        raise InvalidInput("Unsupported WXR item field: " + child.name)
      }
      if child.name == "category" {
        if !child.children.is_empty() {
          raise InvalidInput("Nested taxonomy content")
        }
        let target = match child.attributes.get("domain") {
          Some("category") => categories
          Some("post_tag") => tags
          _ => raise InvalidInput("Custom taxonomy is unsupported")
        }
        if !target.contains(child.text) {
          target.push(child.text)
        }
      } else if child.name == "wp:comment" {
        raise InvalidInput("Comments require migration support")
      }
    }
    let meta : Map[String, String] = Map([])
    for child in item.children {
      if child.name == "wp:postmeta" {
        let key = child.field("wp:meta_key")
        if meta.contains(key) {
          raise InvalidInput(
            "Repeated post metadata requires migration support",
          )
        }
        meta[key] = child.field("wp:meta_value")
        if key != "_moonpress_source_v1" &&
          key != "_moonpress_filename_v1" &&
          key != "_edit_lock" &&
          key != "_edit_last" &&
          key != "_encloseme" &&
          key != "_pingme" {
          raise InvalidInput("Unsupported custom field: " + key)
        }
      }
    }
    let mut metadata : Json = Json::empty_object()
    let body = if meta.get("_moonpress_source_v1") is Some(source) {
      let document = parse_document(source, title)
      let native_tags = document.tags.copy()
      native_tags.sort()
      tags.sort()
      let native_categories = document.categories.copy()
      native_categories.sort()
      categories.sort()
      if document.title != title ||
        document.kind != kind ||
        render_markdown(document.body) != content ||
        native_tags != tags ||
        native_categories != categories ||
        document.description != item.field("excerpt:encoded") {
        raise InvalidInput(
          "Native source metadata conflicts with WordPress fields",
        )
      }
      let native_name = meta.get("_moonpress_filename_v1").unwrap_or("")
      require_post_name(native_name)
      let native_stem = native_name[:native_name.length() - 3].to_owned()
      let native_date = match document.publish_at {
        Some(timestamp) =>
          timestamp[:19].to_owned().replace_all(old="T", new=" ")
        None => document.date.unwrap_or("1970-01-01") + " 00:00:00"
      }
      if document.slug.unwrap_or(native_stem) != item.field("wp:post_name") ||
        native_date != item.field("wp:post_date_gmt") {
        raise InvalidInput(
          "Native route/date metadata conflicts with WordPress fields",
        )
      }
      let (original, body) = document_parts(source, title)
      metadata = original
      warnings.push(
        "Native source metadata preserved; publication is forced to draft; slug, native identity and author are cleared for the new site.",
      )
      body
    } else {
      if content.contains("[") {
        raise InvalidInput("Shortcode content requires migration support")
      }
      let excerpt = item.field("excerpt:encoded")
      if excerpt.contains("<") {
        raise InvalidInput("HTML excerpts require migration support")
      }
      metadata = {
        "title": title,
        "kind": kind,
        "description": wxr_html_entities(excerpt).to_json(),
        "tags": tags.to_json(),
        "categories": categories.to_json(),
      }
      let date = item.field("wp:post_date_gmt")
      if !date.is_empty() && date != "0000-00-00 00:00:00" {
        let timestamp = date.replace_all(old=" ", new="T") + "Z"
        publication_timestamp(timestamp) |> ignore
        let fields = match metadata {
          Object(fields) => fields
          _ => raise InvalidInput("Invalid metadata")
        }
        fields["date"] = date[:10].to_owned().to_json()
        if status == "future" {
          fields["publish_at"] = timestamp.to_json()
        }
      } else if status == "future" {
        raise InvalidInput("Scheduled WordPress content needs a UTC date")
      }
      wxr_body(content)
    }
    let fields = match metadata {
      Object(fields) => fields
      _ => raise InvalidInput("Invalid metadata")
    }
    fields["draft"] = true.to_json()
    fields.remove("wp_id")
    fields.remove("author")
    fields.remove("slug")
    let source = "---\n" + metadata.stringify() + "\n---\n" + body
    if @utf8.encode(source).length() > 4194304 {
      raise InvalidInput("Imported source exceeds 4 MiB editor limit")
    }
    parse_document(source, title) |> ignore
    {
      id,
      title,
      original_status: status,
      source: Some(source),
      error: None,
      warnings,
    }
  } catch {
    error =>
      {
        id,
        title,
        original_status: status,
        source: None,
        error: Some(error.to_string()),
        warnings,
      }
  }
}

///|
pub fn inspect_wordpress(source : String) -> WxrImportPlan raise {
  let root = parse_wxr_xml(source)
  wxr_namespace_scope(root, true)
  if root.attributes.get("xmlns").unwrap_or("") != "" ||
    root.name != "rss" ||
    root.attributes.get("version") != Some("2.0") ||
    ![
      Some("http://wordpress.org/export/1.2/"),
      Some("https://wordpress.org/export/1.2/"),
    ].contains(root.attributes.get("xmlns:wp")) ||
    root.attributes.get("xmlns:content") !=
    Some("http://purl.org/rss/1.0/modules/content/") {
    raise InvalidInput(
      "Expected WXR 1.2 with canonical wp/content namespace prefixes",
    )
  }
  let channels = root.children.filter(child => child.name == "channel")
  if channels.length() != 1 {
    raise InvalidInput("Expected one WXR channel")
  }
  let channel = channels[0]
  if channel.field("wp:wxr_version") != "1.2" {
    raise InvalidInput("Expected WXR 1.2")
  }
  let items : Array[WxrCandidate] = []
  let ids : Map[String, Bool] = Map([])
  for child in channel.children {
    if child.name == "item" {
      if items.length() >= 4096 {
        raise InvalidInput("WXR item limit exceeded")
      }
      let id = child.field("wp:post_id")
      if id.is_empty() ||
        id.length() > 20 ||
        !id.all(c => c.is_ascii_digit()) ||
        ids.contains(id) {
        raise InvalidInput("Invalid/duplicate WXR post ID")
      }
      ids[id] = true
      items.push(wxr_candidate(child, id, child.field("title")))
    } else if ["wp:category", "wp:tag", "wp:term"].contains(child.name) {
      // Item terms carry flat membership. Refuse hierarchy/custom taxonomy data.
      if child.name == "wp:term" ||
        !["", "0"].contains(child.field("wp:category_parent")) {
        raise InvalidInput(
          "Global taxonomy/hierarchy requires migration support",
        )
      }
    }
  }
  { digest: digest_text(source), items, }
}

///|
pub fn import_wordpress_item(
  input : String,
  source : String,
  expected : String,
  id : String,
  stem : String,
) -> NewPostReport raise {
  if digest_text(source) != expected {
    raise InvalidInput("WXR source changed since inspection")
  }
  let plan = inspect_wordpress(source)
  for item in plan.items {
    if item.id == id {
      let content = match item.source {
        Some(content) => content
        None => raise InvalidInput(item.error.unwrap_or("Unsupported WXR item"))
      }
      return create_draft_content(
        input,
        stem,
        content,
        _ => (),
        private_mode=true,
      )
    }
  }
  raise InvalidInput("WXR item not found")
}

///|
pub fn inspect_wordpress_file(path : String) -> WxrImportPlan raise {
  inspect_wordpress(read_wxr_file(path))
}

///|
pub fn import_wordpress_file(
  input : String,
  path : String,
  expected : String,
  id : String,
  stem : String,
) -> NewPostReport raise {
  import_wordpress_item(input, read_wxr_file(path), expected, id, stem)
}

///|
fn read_wxr_file(path : String) -> String raise {
  decode_text(
    read_opened_file(open_file(path, 0), path, max_bytes=16777216),
    path,
  )
}

///|
fn wxr_namespace_scope(node : WxrXml, root : Bool) -> Unit raise {
  for key, _ in node.attributes {
    if !root && (key == "xmlns" || key.has_prefix("xmlns:")) {
      raise InvalidInput("Nested namespace declarations are not supported")
    }
  }
  for child in node.children {
    wxr_namespace_scope(child, false)
  }
}
