///|
fn html_single_root(nodes : Array[IntakeHtml]) -> IntakeHtml raise {
  let mut root : IntakeHtml? = None
  for node in nodes {
    match node {
      Text(text) if text.trim().is_empty() => ()
      Element(_, _, _) => {
        if root is Some(_) {
          raise InvalidInput("Expected one HTML root")
        }
        root = Some(node)
      }
      _ => raise InvalidInput("Text outside HTML root")
    }
  }
  match root {
    Some(root) => root
    None => raise InvalidInput("Missing HTML root")
  }
}

///|
fn html_quote(
  attrs : Map[String, String],
  children : Array[IntakeHtml],
) -> String raise {
  if !attrs.is_empty() {
    raise InvalidInput("Unsupported quote attributes")
  }
  let text = match html_single_root(children) {
    Element("p", attrs, inline) if attrs.is_empty() =>
      html_inline_checked(inline, paragraph=true)
    _ => raise InvalidInput("Quote requires a single paragraph")
  }
  let markdown = text
    .split("\n")
    .map(line => "> " + line.to_owned())
    .to_array()
    .join("\n") +
    "\n"
  if render_markdown(markdown) !=
    "<blockquote>\n" + render_markdown(text) + "</blockquote>\n" {
    raise InvalidInput("Quote cannot round-trip")
  }
  markdown
}
