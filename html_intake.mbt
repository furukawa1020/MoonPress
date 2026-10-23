///|
priv enum IntakeHtml {
  Text(String)
  Element(String, Map[String, String], Array[IntakeHtml])
}

///|
fn WxrReader::html_children(
  self : WxrReader,
  parent : String,
  depth : Int,
) -> Array[IntakeHtml] raise {
  if depth > 32 {
    raise InvalidInput("HTML depth limit")
  }
  let nodes : Array[IntakeHtml] = []
  while self.offset < self.source.length() {
    if self.starts("</") {
      self.offset += 2
      if parent.is_empty() || self.name() != parent {
        raise InvalidInput("Mismatched HTML close")
      }
      self.space()
      if !self.starts(">") {
        raise InvalidInput("Invalid HTML close")
      }
      self.offset += 1
      return nodes
    }
    if self.nodes >= 100000 {
      raise InvalidInput("HTML node limit")
    }
    self.nodes += 1
    if self.starts("<!") || self.starts("<?") {
      raise InvalidInput("HTML declarations/comments unsupported")
    }
    if self.starts("<") {
      self.offset += 1
      let name = self.name()
      let attrs : Map[String, String] = Map([])
      while true {
        let before = self.offset
        self.space()
        if self.starts(">") {
          self.offset += 1
          break
        }
        if self.offset == before || attrs.length() >= 64 {
          raise InvalidInput("Invalid HTML attributes")
        }
        let key = self.name()
        self.space()
        if !self.starts("=") {
          raise InvalidInput("Expected HTML assignment")
        }
        self.offset += 1
        self.space()
        if !self.starts("\"") && !self.starts("'") {
          raise InvalidInput("Expected quoted HTML attribute")
        }
        let quote = self.source[self.offset:self.offset + 1].to_owned()
        self.offset += 1
        let value = self.through(quote)
        if value.contains("<") || attrs.contains(key) {
          raise InvalidInput("Invalid/duplicate HTML attribute")
        }
        attrs[key] = wxr_html_entities(value)
      }
      nodes.push(Element(name, attrs, self.html_children(name, depth + 1)))
    } else {
      let tail = self.source[self.offset:]
      let text = match tail.split_once("<") {
        Some((before, _)) => before.to_owned()
        None => tail.to_owned()
      }
      self.offset += text.length()
      nodes.push(Text(wxr_html_entities(text)))
    }
  }
  if !parent.is_empty() {
    raise InvalidInput("Unclosed HTML element")
  }
  nodes
}

///|
fn intake_html(source : String) -> Array[IntakeHtml] raise {
  if @utf8.encode(source).length() > 16777216 {
    raise InvalidInput("HTML byte limit")
  }
  require_xml_text(source, "HTML intake")
  let reader : WxrReader = { source, offset: 0, nodes: 0, }
  reader.html_children("", 0)
}

///|
fn html_text_space(text : String) -> String {
  let out = StringBuilder()
  let mut space = false
  for c in text {
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      if !space {
        out.write_string(" ")
      }
      space = true
    } else {
      out.write_char(c)
      space = false
    }
  }
  out.to_string()
}

///|
fn html_inline(nodes : Array[IntakeHtml]) -> (String, String) raise {
  let markdown = StringBuilder()
  let html = StringBuilder()
  for node in nodes {
    match node {
      Text(text) => {
        let text = html_text_space(text)
        markdown.write_string(wxr_plain_markdown(text))
        html.write_string(escape_html(text))
      }
      Element(name, attrs, children) =>
        if name == "a" || name == "code" {
          let plain = StringBuilder()
          for child in children {
            match child {
              Text(text) => plain.write_string(html_text_space(text))
              _ => raise InvalidInput("Formatted link/code text unsupported")
            }
          }
          let text = plain.to_string()
          if name == "a" {
            let href = attrs.get("href").unwrap_or("")
            if attrs.length() != 1 ||
              !allowed_href(href) ||
              href.contains(")") ||
              href.contains("(") {
              raise InvalidInput("Unsafe/unrepresentable HTML link")
            }
            markdown.write_string(
              "[" + wxr_plain_markdown(text) + "](" + href + ")",
            )
            html.write_string(
              "<a href=\"" +
              escape_html(href) +
              "\">" +
              escape_html(text) +
              "</a>",
            )
          } else {
            if !attrs.is_empty() || text.is_empty() {
              raise InvalidInput("Unsupported HTML code")
            }
            let mut delimiter = "`"
            while text.contains(delimiter) {
              if delimiter.length() >= 64 {
                raise InvalidInput("HTML code delimiter limit")
              }
              delimiter += "`"
            }
            let pad = if text.has_prefix("`") ||
              text.has_suffix("`") ||
              (text.has_prefix(" ") && text.has_suffix(" ")) {
              " "
            } else {
              ""
            }
            markdown.write_string(delimiter + pad + text + pad + delimiter)
            html.write_string("<code>" + escape_html(text) + "</code>")
          }
        } else {
          if !attrs.is_empty() {
            raise InvalidInput("Unsupported HTML inline attributes")
          }
          let (marker, tag) = match name {
            "strong" | "b" => ("**", "strong")
            "em" | "i" => ("*", "em")
            _ => raise InvalidInput("Unsupported inline HTML: " + name)
          }
          let (child_markdown, child_html) = html_inline(children)
          markdown.write_string(marker + child_markdown + marker)
          html.write_string("<" + tag + ">" + child_html + "</" + tag + ">")
        }
    }
  }
  (markdown.to_string(), html.to_string())
}

///|
fn html_inline_checked(nodes : Array[IntakeHtml]) -> String raise {
  let (markdown, expected) = html_inline(nodes)
  let markdown = markdown.trim(chars=" ").to_owned()
  if markdown.is_empty() ||
    render_inline(markdown) != expected.trim(chars=" ").to_owned() {
    raise InvalidInput(
      "HTML inline structure cannot round-trip through native Markdown",
    )
  }
  markdown
}

///|
fn html_blocks(nodes : Array[IntakeHtml]) -> String raise {
  let body = StringBuilder()
  for node in nodes {
    match node {
      Text(text) =>
        if !text.trim().is_empty() {
          raise InvalidInput("Mixed top-level HTML text")
        }
      Element(name, attrs, children) => {
        if !attrs.is_empty() {
          raise InvalidInput("Unsupported HTML block attributes")
        }
        let prefix = match name {
          "p" => ""
          "h1" => "# "
          "h2" => "## "
          "h3" => "### "
          "h4" => "#### "
          "h5" => "##### "
          "h6" => "###### "
          _ => raise InvalidInput("Unsupported HTML block: " + name)
        }
        body.write_string(prefix + html_inline_checked(children) + "\n\n")
      }
    }
  }
  body.to_string()
}
