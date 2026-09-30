///|
priv struct FeedConfig {
  title : String
  description : String
}

///|
priv struct SiteConfig {
  base_url : String?
  feed : FeedConfig?
  page_size : Int?
  tag_page_size : Int?
  tag_index : Bool
}

///|
fn parse_site_config(source : String) -> SiteConfig raise {
  let fields = match @json.parse(source) {
    Object(fields) => fields
    _ => raise InvalidInput("site.json must be an object")
  }
  for key, _ in fields {
    if key != "base_url" &&
      key != "feed" &&
      key != "page_size" &&
      key != "tag_page_size" &&
      key != "tag_index" {
      raise InvalidInput("site.json: unknown key " + key)
    }
  }
  let base_url = match fields.get("base_url") {
    Some(String(url)) => normalize_base_url(url)
    _ => raise InvalidInput("site.json: base_url must be a string")
  }
  let feed = match fields.get("feed") {
    None => None
    Some(Object(values)) => {
      for key, _ in values {
        if key != "title" && key != "description" {
          raise InvalidInput("site.json: unknown feed key " + key)
        }
      }
      let title = feed_config_text(values.get("title"), "title")
      let description = feed_config_text(
        values.get("description"),
        "description",
      )
      Some({ title, description, })
    }
    _ => raise InvalidInput("site.json: feed must be an object")
  }
  let page_size = parse_page_size(fields.get("page_size"), "page_size")
  let tag_page_size = parse_page_size(
    fields.get("tag_page_size"),
    "tag_page_size",
  )
  let tag_index = match fields.get("tag_index") {
    None | Some(False) => false
    Some(True) => true
    _ => raise InvalidInput("site.json: tag_index must be a boolean")
  }
  { base_url: Some(base_url), feed, page_size, tag_page_size, tag_index, }
}

///|
fn parse_page_size(value : Json?, field : String) -> Int? raise {
  match value {
    None => None
    Some(Number(n, ..)) if n >= 1 && n <= 1000 && n.to_int().to_double() == n =>
      Some(n.to_int())
    _ =>
      raise InvalidInput(
        "site.json: " + field + " must be an integer from 1 to 1000",
      )
  }
}

///|
fn feed_config_text(value : Json?, field : String) -> String raise {
  match value {
    Some(String(text)) if !text.trim().is_empty() => {
      require_xml_text(text, "site.json: feed." + field)
      text
    }
    _ =>
      raise InvalidInput(
        "site.json: feed." + field + " must be a nonempty string",
      )
  }
}

///|
fn read_site_config(input : String) -> SiteConfig raise {
  let path = input + "/site.json"
  if path_kind(path) == 0 {
    return {
      base_url: None,
      feed: None,
      page_size: None,
      tag_page_size: None,
      tag_index: false,
    }
  }
  require_input_kind(path, 1)
  parse_site_config(read_text(path))
}
