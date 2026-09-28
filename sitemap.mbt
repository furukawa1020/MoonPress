///|
pub fn normalize_base_url(url : String) -> String raise {
  if !url.has_prefix("https://") && !url.has_prefix("http://") {
    raise InvalidInput("site.json: base_url must use http:// or https://")
  }
  for c in url {
    if c.is_whitespace() ||
      c.is_control() ||
      c == '\\' ||
      c == '<' ||
      c == '>' ||
      c == '"' ||
      c == '\'' ||
      c == '?' ||
      c == '#' ||
      c == '@' {
      raise InvalidInput("site.json: unsupported character in base_url")
    }
  }
  let remainder = url.split_once("://").unwrap().1.to_owned()
  let host = remainder.split("/").next().unwrap_or("").to_owned()
  if host.is_empty() {
    raise InvalidInput("site.json: base_url needs a host")
  }
  for part in remainder.split("/") {
    if part == "." || part == ".." {
      raise InvalidInput("site.json: dot path segments are not allowed")
    }
  }
  url.trim_end(chars="/").to_owned() + "/"
}

///|
pub fn site_base_path(base_url : String) -> String {
  let remainder = base_url.split_once("://").unwrap().1.to_owned()
  match remainder.split_once("/") {
    Some((_, path)) => "/" + path.to_owned()
    None => "/"
  }
}

///|
fn read_base_url(input : String) -> String? raise {
  let path = input + "/site.json"
  if path_kind(path) == 0 {
    return None
  }
  require_input_kind(path, 1)
  let fields = match @json.parse(@fs.read_file_to_string(path)) {
    Object(fields) => fields
    _ => raise InvalidInput("site.json must be an object")
  }
  for key, _ in fields {
    if key != "base_url" {
      raise InvalidInput("site.json: unknown key " + key)
    }
  }
  match fields.get("base_url") {
    Some(String(url)) => Some(normalize_base_url(url))
    _ => raise InvalidInput("site.json: base_url must be a string")
  }
}

///|
pub fn render_sitemap(base_url : String, outputs : Array[String]) -> String {
  let out = StringBuilder()
  out.write_string(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n",
  )
  for name in outputs {
    if name.has_suffix(".html") {
      out.write_string(
        "<url><loc>" +
        escape_html(base_url + url_component(name)) +
        "</loc></url>\n",
      )
    }
  }
  out.write_string("</urlset>\n")
  out.to_string()
}
