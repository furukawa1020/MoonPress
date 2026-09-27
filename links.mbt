///|
priv enum Inline {
  Text(String)
  Code(String)
  Link(String, String)
  Image(String, String)
}

///|
fn parse_inline(text : String) -> Array[Inline] {
  let result : Array[Inline] = []
  let mut rest = text
  while !rest.is_empty() {
    let code = rest.find("`").unwrap_or(rest.length())
    let link = rest.find("[").unwrap_or(rest.length())
    let is_image = link > 0 && link < code && rest[link - 1:link] == "!"
    let start = if code < link {
      code
    } else if is_image {
      link - 1
    } else {
      link
    }
    if start == rest.length() {
      result.push(Text(rest))
      break
    }
    if start > 0 {
      result.push(Text(rest[:start].to_owned()))
    }
    let tail = rest[start + (if is_image { 2 } else { 1 }):].to_owned()
    if code < link {
      if tail.split_once("`") is Some((content, after)) {
        result.push(Code(content.to_owned()))
        rest = after.to_owned()
        continue
      }
      result.push(Text("`"))
      rest = tail
    } else {
      if tail.split_once("](") is Some((label, destination)) {
        if !label.to_owned().contains("[") &&
          destination.to_owned().split_once(")") is Some((href, after)) {
          result.push(
            if is_image {
              Image(label.to_owned(), href.to_owned())
            } else {
              Link(label.to_owned(), href.to_owned())
            },
          )
          rest = after.to_owned()
          continue
        }
      }
      result.push(Text(if is_image { "![" } else { "[" }))
      rest = tail
    }
  }
  result
}

///|
pub fn allowed_href(href : String) -> Bool {
  if href.is_empty() || href.has_prefix("//") {
    return false
  }
  for c in href {
    if c.is_whitespace() || c.is_control() || c == '\\' {
      return false
    }
  }
  if href.contains(":") {
    return href.has_prefix("https://") ||
      href.has_prefix("http://") ||
      href.has_prefix("mailto:")
  }
  true
}

///|
pub fn render_inline(text : String) -> String {
  let out = StringBuilder()
  for part in parse_inline(text) {
    match part {
      Text(text) => out.write_string(escape_html(text))
      Code(text) => out.write_string("<code>" + escape_html(text) + "</code>")
      Image(alt, src) =>
        if allowed_src(src) {
          out.write_string(
            "<img src=\"" +
            escape_html(src) +
            "\" alt=\"" +
            escape_html(alt) +
            "\">",
          )
        } else {
          out.write_string(escape_html("![" + alt + "](" + src + ")"))
        }
      Link(label, href) =>
        if allowed_href(href) {
          out.write_string(
            "<a href=\"" +
            escape_html(href) +
            "\">" +
            escape_html(label) +
            "</a>",
          )
        } else {
          out.write_string(escape_html("[" + label + "](" + href + ")"))
        }
    }
  }
  out.to_string()
}

///|
pub fn markdown_links(source : String) -> Array[String] {
  let links : Array[String] = []
  for block in parse_blocks(source) {
    for line in inline_lines(block) {
      for part in parse_inline(line) {
        if part is Link(_, href) {
          links.push(href)
        }
      }
    }
  }
  links
}

///|
fn normalized_url_path(path : String) -> String raise {
  let out = StringBuilder()
  let mut first = true
  for part in path.split("%") {
    let part = part.to_owned()
    if first {
      out.write_string(url_component(part))
      first = false
    } else {
      if part.length() < 2 ||
        !part[:2].to_owned().all(c => c.is_ascii_hexdigit()) {
        raise InvalidInput("Invalid percent escape in link: " + path)
      }
      out.write_string(
        "%" +
        part[:2].to_owned().to_upper() +
        url_component(part[2:].to_owned()),
      )
    }
  }
  out.to_string()
}

///|
pub fn validate_links(
  links : Array[String],
  outputs : Array[String],
  base_path? : String = "/",
  source? : String = "document",
) -> Unit raise {
  let routes : Map[String, Bool] = Map([])
  for name in outputs {
    routes[url_component(name)] = true
  }
  for href in links {
    if !allowed_href(href) {
      raise InvalidInput(source + ": disallowed link: " + href)
    }
    if href.contains(":") {
      continue
    }
    let path = href
      .split("#")
      .next()
      .unwrap_or("")
      .to_owned()
      .split("?")
      .next()
      .unwrap_or("")
      .to_owned()
    let mut path = path
    if path.is_empty() {
      continue
    }
    if path.has_prefix("/") {
      if !path.has_prefix(base_path) {
        raise InvalidInput(source + ": link is outside site base path: " + href)
      }
      path = path[base_path.length():].to_owned()
    }
    if path.has_prefix("./") {
      path = path[2:].to_owned()
    }
    if path.is_empty() {
      path = "index.html"
    }
    if !routes.contains(normalized_url_path(path)) {
      raise InvalidInput(source + ": broken internal link: " + href)
    }
  }
}

///|
fn template_urls(layout : String, attribute : String) -> Array[String] raise {
  let links : Array[String] = []
  let mut offset = 0
  while offset < layout.length() {
    let remainder = layout[offset:].to_owned()
    let opening = match remainder.find("<") {
      None => break
      Some(index) => index
    }
    offset += opening + 1
    if layout[offset:].has_prefix("!--") {
      match layout[offset + 3:].to_owned().find("-->") {
        None => raise InvalidInput("layout.html: unclosed comment")
        Some(end) => {
          offset += 3 + end + 3
          continue
        }
      }
    }
    // Consume the tag name, then tokenize attributes while respecting quotes.
    while offset < layout.length() &&
          !html_space(layout, offset) &&
          layout[offset:offset + 1] != ">" {
      offset += 1
    }
    while offset < layout.length() {
      while offset < layout.length() && html_space(layout, offset) {
        offset += 1
      }
      if offset >= layout.length() {
        break
      }
      if layout[offset:offset + 1] == ">" {
        offset += 1
        break
      }
      if layout[offset:offset + 1] == "/" {
        offset += 1
        continue
      }
      let start = offset
      while offset < layout.length() &&
            !html_space(layout, offset) &&
            layout[offset:offset + 1] != "=" &&
            layout[offset:offset + 1] != ">" {
        offset += 1
      }
      let name = layout[start:offset].to_owned().to_lower()
      while offset < layout.length() && html_space(layout, offset) {
        offset += 1
      }
      if offset >= layout.length() || layout[offset:offset + 1] != "=" {
        continue
      }
      offset += 1
      while offset < layout.length() && html_space(layout, offset) {
        offset += 1
      }
      if offset >= layout.length() {
        raise InvalidInput("layout.html: missing attribute value")
      }
      let quote = layout[offset:offset + 1].to_owned()
      let quoted = quote == "\"" || quote == "'"
      if quoted {
        offset += 1
      }
      let start = offset
      while offset < layout.length() {
        if quoted {
          if layout[offset:offset + 1] == quote {
            break
          }
        } else if html_space(layout, offset) || layout[offset:offset + 1] == ">" {
          break
        }
        offset += 1
      }
      let value = layout[start:offset].to_owned()
      if quoted {
        if offset == layout.length() {
          raise InvalidInput("layout.html: unclosed attribute")
        }
        offset += 1
      }
      if name == attribute {
        if !quoted {
          raise InvalidInput(
            "layout.html: " + attribute + " values must be quoted",
          )
        }
        if value.contains("{{") {
          raise InvalidInput(
            "layout.html: dynamic " +
            attribute +
            " placeholders are not supported",
          )
        }
        links.push(value.replace_all(old="&amp;", new="&"))
      }
    }
  }
  links
}

///|
fn html_space(text : String, index : Int) -> Bool {
  let c = text[index].to_int()
  c == 32 || c == 9 || c == 10 || c == 13 || c == 12
}

///|
fn allowed_src(src : String) -> Bool {
  allowed_href(src) &&
  !src.has_prefix("mailto:") &&
  !src.has_prefix("#") &&
  !src.has_prefix("?")
}

///|
pub fn markdown_images(source : String) -> Array[String] {
  let images : Array[String] = []
  for block in parse_blocks(source) {
    for line in inline_lines(block) {
      for part in parse_inline(line) {
        if part is Image(_, src) {
          images.push(src)
        }
      }
    }
  }
  images
}

///|
pub fn template_links(layout : String) -> Array[String] raise {
  template_urls(layout, "href")
}

///|
pub fn template_sources(layout : String) -> Array[String] raise {
  template_urls(layout, "src")
}

///|
pub fn validate_sources(
  sources : Array[String],
  outputs : Array[String],
  base_path? : String = "/",
  source? : String = "document",
) -> Unit raise {
  for src in sources {
    if !allowed_src(src) {
      raise InvalidInput(source + ": disallowed source URL: " + src)
    }
  }
  validate_links(sources, outputs, base_path~, source~)
}
