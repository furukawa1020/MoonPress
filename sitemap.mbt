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
