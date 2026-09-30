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
}

///|
fn parse_site_config(source : String) -> SiteConfig raise {
  let fields = match @json.parse(source) {
    Object(fields) => fields
    _ => raise InvalidInput("site.json must be an object")
  }
  for key, _ in fields {
    if key != "base_url" && key != "feed" && key != "page_size" {
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
  let page_size = match fields.get("page_size") {
    None => None
    Some(Number(n, ..)) if n >= 1 && n <= 1000 && n.to_int().to_double() == n =>
      Some(n.to_int())
    _ =>
      raise InvalidInput(
        "site.json: page_size must be an integer from 1 to 1000",
      )
  }
  { base_url: Some(base_url), feed, page_size, }
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
    return { base_url: None, feed: None, page_size: None, }
  }
  require_input_kind(path, 1)
  parse_site_config(read_text(path))
}
