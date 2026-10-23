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
  block? : String? = None,
) -> Array[IntakeHtml] raise {
  if depth > 32 {
    raise InvalidInput("HTML depth limit")
  }
  let nodes : Array[IntakeHtml] = []
  while self.offset < self.source.length() {
    if self.starts("<!--") {
      if self.nodes >= 100000 {
        raise InvalidInput("HTML block node limit")
      }
      self.nodes += 1
      self.offset += 4
      let token = self.through("-->").trim().to_owned()
      if token.has_prefix("/wp:") {
        if block != Some(token[4:].to_owned()) {
          raise InvalidInput("Mismatched WordPress block close")
        }
        return nodes
      }
      if block is Some(_) {
        raise InvalidInput("Nested block wrappers require HTML containment")
      }
      nodes.push(self.html_block(token, parent, depth))
      continue
    }
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
        if self.starts("/>") && ["br", "hr", "img"].contains(name) {
          self.offset += 2
          break
        }
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
      nodes.push(
        Element(
          name,
          attrs,
          if ["br", "hr", "img"].contains(name) {
            []
          } else {
            self.html_children(name, depth + 1)
          },
        ),
      )
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
  if !parent.is_empty() || block is Some(_) {
    raise InvalidInput("Unclosed HTML element/block")
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
        if name == "img" {
          if !children.is_empty() ||
            attrs.keys().any(key => key != "src" && key != "alt") {
            raise InvalidInput("Unsupported image attributes")
          }
          let src = attrs.get("src").unwrap_or("")
          let alt = attrs.get("alt").unwrap_or("")
          if !allowed_src(src) || src.contains("(") || src.contains(")") {
            raise InvalidInput("Unsafe/unrepresentable image URL")
          }
          markdown.write_string(
            "![" + wxr_plain_markdown(alt) + "](" + src + ")",
          )
          html.write_string(
            "<img src=\"" +
            escape_html(src) +
            "\" alt=\"" +
            escape_html(alt) +
            "\">",
          )
        } else if name == "br" {
          if !attrs.is_empty() || !children.is_empty() {
            raise InvalidInput("Unsupported line break attributes")
          }
          markdown.write_string("  \n")
          html.write_string("<br>\n")
        } else if name == "a" || name == "code" {
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
fn html_inline_checked(
  nodes : Array[IntakeHtml],
  paragraph? : Bool = false,
) -> String raise {
  let (markdown, expected) = html_inline(nodes)
  let markdown = markdown.trim(chars=" ").to_owned()
  let expected = expected.trim(chars=" ").to_owned()
  let matches = if paragraph {
    render_markdown(markdown) == "<p>" + expected + "</p>\n"
  } else {
    !markdown.contains("\n") && render_inline(markdown) == expected
  }
  if markdown.is_empty() || !matches {
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
        if name == "img" {
          body.write_string(
            html_inline_checked(
              [Element(name, attrs, children)],
              paragraph=true,
            ) +
            "\n\n",
          )
          continue
        }
        if name == "hr" {
          if !attrs.is_empty() || !children.is_empty() {
            raise InvalidInput("Unsupported rule attributes")
          }
          body.write_string("---\n\n")
          continue
        }
        if name == "pre" {
          body.write_string(html_pre(attrs, children) + "\n")
          continue
        }
        if name == "blockquote" {
          body.write_string(html_quote(attrs, children) + "\n")
          continue
        }
        if name == "ul" || name == "ol" {
          body.write_string(html_list(name, attrs, children) + "\n")
          continue
        }
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
        body.write_string(
          prefix + html_inline_checked(children, paragraph=name == "p") + "\n\n",
        )
      }
    }
  }
  body.to_string()
}

///|
fn html_list(
  name : String,
  attrs : Map[String, String],
  children : Array[IntakeHtml],
) -> String raise {
  if attrs.keys().any(key => key != "start" || name != "ol") {
    raise InvalidInput("Unsupported list attributes")
  }
  let start = rest_positive(attrs.get("start").unwrap_or("1"), 999999999).to_string()
  let marker = if name == "ul" { "- " } else { start + ". " }
  let markdown = StringBuilder()
  let expected = StringBuilder()
  let attribute = if name == "ol" && start != "1" {
    " start=\"" + start + "\""
  } else {
    ""
  }
  expected.write_string("<" + name + attribute + ">\n")
  let mut count = 0
  for child in children {
    match child {
      Text(text) =>
        if !text.trim().is_empty() {
          raise InvalidInput("List text outside item")
        }
      Element("li", attrs, inline) => {
        if !attrs.is_empty() {
          raise InvalidInput("Unsupported list item attributes")
        }
        let text = html_inline_checked(inline)
        markdown.write_string(marker + text + "\n")
        expected.write_string("<li>" + render_inline(text) + "</li>\n")
        count += 1
      }
      _ => raise InvalidInput("Flat lists require inline li children")
    }
  }
  if count == 0 {
    raise InvalidInput("Empty list cannot be represented")
  }
  expected.write_string("</" + name + ">\n")
  let markdown = markdown.to_string()
  if render_markdown(markdown) != expected.to_string() {
    raise InvalidInput("List cannot round-trip")
  }
  markdown
}
