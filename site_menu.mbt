///|
priv struct SiteMenuItem {
  label : String
  url : String
}

///|
fn site_menu_external(url : String) -> Bool {
  url.has_prefix("https://")
}

///|
fn site_menu_url(url : String) -> Bool {
  if url.is_empty() || @utf8.encode(url).length() > 512 {
    return false
  }
  if url.any(c => c.is_control() || c == '\\' || c == '{' || c == '}') {
    return false
  }
  if site_menu_external(url) {
    let host = url[8:]
      .to_owned()
      .replace_all(old="?", new="/")
      .replace_all(old="#", new="/")
      .split("/")
      .next()
      .unwrap_or("")
      .to_owned()
    !host.is_empty() &&
    host.all(c => {
      c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '-' || c == '.'
    }) &&
    host
    .split(".")
    .all(part => {
      !part.is_empty() && !part.has_prefix("-") && !part.has_suffix("-")
    }) &&
    !url.any(c => {
      c.is_whitespace() || c == '"' || c == '\'' || c == '<' || c == '>'
    })
  } else {
    safe_output_name(url) &&
    url.has_suffix(".html") &&
    url.length() > 5 &&
    !url.has_prefix(".") &&
    !url.contains("?") &&
    !url.contains("#") &&
    !url.contains("%")
  }
}

///|
fn parse_site_menu(value : Json?) -> Array[SiteMenuItem] raise {
  guard value is Some(value) else { return [] }
  guard value is Array(items) && items.length() <= 12 else {
    raise InvalidInput("site.json: menu must contain at most 12 items")
  }
  let result : Array[SiteMenuItem] = []
  let seen : Map[String, Bool] = Map([])
  for item in items {
    guard item is Object(fields) &&
      fields.length() == 2 &&
      fields.get("label") is Some(String(label)) &&
      fields.get("url") is Some(String(url)) &&
      !label.trim().is_empty() &&
      @utf8.encode(label).length() <= 96 &&
      !label.any(c => c.is_control()) &&
      site_menu_url(url) else {
      raise InvalidInput(
        "site.json: menu items need a label and a flat HTML filename or HTTPS URL",
      )
    }
    if seen.contains(url) {
      raise InvalidInput("site.json: duplicate menu link")
    }
    seen[url] = true
    result.push({ label, url, })
  }
  result
}

///|
fn site_menu_href(url : String) -> String {
  if site_menu_external(url) {
    url
  } else {
    url_component(url)
  }
}

///|
fn render_site_menu(items : Array[SiteMenuItem]) -> String {
  if items.is_empty() {
    return ""
  }
  let out = StringBuilder()
  out.write_string("<nav aria-label=\"メインメニュー\">")
  for item in items {
    // Menu HTML is incorporated before the template renderer. Keep literal
    // braces in text from becoming template tokens.
    let label = escape_html(item.label).replace_all(old="{", new="&#123;")
    out.write_string(
      "<a href=\"" +
      escape_html(site_menu_href(item.url)) +
      "\">" +
      label +
      "</a>",
    )
  }
  out.write_string("</nav>")
  out.to_string()
}
