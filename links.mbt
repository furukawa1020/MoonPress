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
      let length = backtick_run(rest, start)
      if close_code_span(rest, start + length, length) is Some(end) {
        let content = rest[start + length:end].to_owned()
        result.push(Code(normalize_code_span(content)))
        rest = rest[end + length:].to_owned()
        continue
      }
      result.push(Text(rest[start:start + length].to_owned()))
      rest = rest[start + length:].to_owned()
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
  if url_scheme(href) is Some(_) {
    let lower = href.to_lower()
    return lower.has_prefix("https://") ||
      lower.has_prefix("http://") ||
      lower.has_prefix("mailto:")
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
  block_references(parse_blocks(source)).0
}

///|
fn block_references(blocks : Array[Block]) -> (Array[String], Array[String]) {
  let links : Array[String] = []
  let images : Array[String] = []
  for block in blocks {
    for line in inline_lines(block) {
      for part in parse_inline(line) {
        match part {
          Link(_, href) => links.push(href)
          Image(_, src) => images.push(src)
          _ => ()
        }
      }
    }
  }
  (links, images)
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
      let hex = part[:2].to_owned().to_upper()
      let digits = "0123456789ABCDEF"
      let high = digits.find(hex[:1].to_owned()).unwrap()
      let low = digits.find(hex[1:2].to_owned()).unwrap()
      let c = (high * 16 + low).unsafe_to_char()
      if c.is_ascii_alphabetic() ||
        c.is_ascii_digit() ||
        c == '-' ||
        c == '_' ||
        c == '.' ||
        c == '~' {
        out.write_char(c)
      } else {
        out.write_string("%" + hex)
      }
      out.write_string(url_component(part[2:].to_owned()))
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
  validate_route_links(links, index_routes(outputs), base_path~, source~)
}

///|
fn index_routes(outputs : Array[String]) -> Map[String, Bool] {
  let routes : Map[String, Bool] = Map([])
  for name in outputs {
    routes[url_component(name)] = true
  }
  routes
}

///|
// None denotes an external URL or a reference to the current document.
fn local_route(
  href : String,
  base_path : String,
  source : String,
) -> String? raise {
  if url_scheme(href) is Some(_) {
    return None
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
    return None
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
  Some(normalized_url_path(path))
}

///|
fn validate_route_links(
  links : Array[String],
  routes : Map[String, Bool],
  base_path? : String = "/",
  source? : String = "document",
  sources? : Bool = false,
) -> Unit raise {
  for href in links {
    if sources && !allowed_src(href) {
      raise InvalidInput(source + ": disallowed source URL: " + href)
    }
    if !allowed_href(href) {
      raise InvalidInput(source + ": disallowed link: " + href)
    }
    if local_route(href, base_path, source) is Some(path) {
      if !routes.contains(path) {
        raise InvalidInput(source + ": broken internal link: " + href)
      }
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
  url_scheme(src) != Some("mailto") &&
  !src.has_prefix("#") &&
  !src.has_prefix("?")
}

///|
pub fn markdown_images(source : String) -> Array[String] {
  block_references(parse_blocks(source)).1
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
  validate_route_links(
    sources,
    index_routes(outputs),
    base_path~,
    source~,
    sources=true,
  )
}

///|
// A colon is a scheme delimiter only before path/query/fragment delimiters.
fn url_scheme(url : String) -> String? {
  let prefix = StringBuilder()
  for c in url {
    if c == '/' || c == '?' || c == '#' {
      return None
    }
    if c == ':' {
      return Some(prefix.to_string().to_lower())
    }
    prefix.write_char(c)
  }
  None
}

///|
fn inline_text(text : String) -> String {
  let out = StringBuilder()
  for part in parse_inline(text) {
    match part {
      Text(text) | Code(text) | Link(text, _) | Image(text, _) =>
        out.write_string(text)
    }
  }
  out.to_string()
}

///|
fn backtick_run(text : String, start : Int) -> Int {
  let mut end = start
  while end < text.length() && text[end:end + 1] == "`" {
    end += 1
  }
  end - start
}

///|
fn close_code_span(text : String, start : Int, length : Int) -> Int? {
  let mut offset = start
  while offset < text.length() {
    match text[offset:].to_owned().find("`") {
      None => return None
      Some(relative) => {
        offset += relative
        let run = backtick_run(text, offset)
        if run == length {
          return Some(offset)
        }
        offset += run
      }
    }
  }
  None
}

///|
fn normalize_code_span(text : String) -> String {
  if text.length() >= 2 &&
    text.has_prefix(" ") &&
    text.has_suffix(" ") &&
    !text.all(c => c == ' ') {
    text[1:text.length() - 1].to_owned()
  } else {
    text
  }
}
