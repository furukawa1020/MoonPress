///|
fn html_plain_text(nodes : Array[IntakeHtml]) -> String raise {
  let text = StringBuilder()
  for node in nodes {
    match node {
      Text(value) => text.write_string(value)
      _ => raise InvalidInput("Expected literal HTML text")
    }
  }
  text.to_string()
}

///|
fn html_pre(
  attrs : Map[String, String],
  children : Array[IntakeHtml],
) -> String raise {
  if !attrs.is_empty() {
    raise InvalidInput("Unsupported preformatted attributes")
  }
  let mut language = ""
  let content = if children.any(node => {
      match node {
        Element(_, _, _) => true
        _ => false
      }
    }) {
    if children.length() != 1 {
      raise InvalidInput("Whitespace siblings inside pre cannot be discarded")
    }
    match html_single_root(children) {
      Element("code", attrs, literal) => {
        for key, value in attrs {
          if key != "class" || !value.has_prefix("language-") {
            raise InvalidInput("Unsupported code attributes")
          }
          language = value[9:].to_owned()
          if fence_language("```" + language, 3) != Some(language) {
            raise InvalidInput("Unsupported code language")
          }
        }
        html_plain_text(literal)
      }
      _ => raise InvalidInput("Preformatted HTML requires literal code")
    }
  } else {
    html_plain_text(children)
  }
  let content = content
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  let content = if content.is_empty() || content.has_suffix("\n") {
    content
  } else {
    content + "\n"
  }
  let mut run = 0
  let mut longest = 2
  for c in content {
    if c == '`' {
      run += 1
      if run > longest {
        longest = run
      }
    } else {
      run = 0
    }
    if longest > 4096 {
      raise InvalidInput("Code fence run exceeds limit")
    }
  }
  let fence = "`".repeat(longest + 1)
  let markdown = fence + language + "\n" + content + fence + "\n"
  let attribute = if language.is_empty() {
    ""
  } else {
    " class=\"language-" + escape_html(language) + "\""
  }
  if render_markdown(markdown) !=
    "<pre><code" + attribute + ">" + escape_html(content) + "</code></pre>\n" {
    raise InvalidInput("Code cannot round-trip")
  }
  markdown
}
