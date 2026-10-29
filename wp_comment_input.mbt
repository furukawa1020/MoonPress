///|
fn wp_comment_plain(
  nodes : Array[IntakeHtml],
  inline_only : Bool,
) -> String raise {
  let out = StringBuilder()
  for node in nodes {
    match node {
      Text(text) => out.write_string(text)
      Element("br", attrs, children) => {
        if !attrs.is_empty() || !children.is_empty() {
          raise InvalidInput("Invalid comment break")
        }
        out.write_string("\n")
      }
      Element("p", attrs, children) => {
        if inline_only || !attrs.is_empty() {
          raise InvalidInput("Invalid comment paragraph")
        }
        out.write_string(wp_comment_plain(children, true) + "\n\n")
      }
      _ => raise InvalidInput("Unsupported comment HTML")
    }
  }
  out.to_string()
}

///|
fn wp_comment_input(value : Json) -> String raise {
  let text : String = @json.from_json(rest_raw_input(value))
  comment_text(text, 8192)
  if text.contains("<") {
    wp_comment_plain(intake_html(text), false).trim().to_owned()
  } else {
    text.trim().to_owned()
  }
}
