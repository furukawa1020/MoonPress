///|
fn html_table_alignment(
  attrs : Map[String, String],
  tag : String,
) -> String raise {
  for key, _ in attrs {
    if !["style", "class", "data-align"].contains(key) &&
      !(key == "scope" && tag == "th") {
      raise InvalidInput("Unsupported table cell attributes")
    }
  }
  if attrs.contains("scope") && attrs.get("scope") != Some("col") {
    raise InvalidInput("Unsupported table scope")
  }
  let declared : Array[String] = []
  if attrs.get("style") is Some(style) {
    let out = StringBuilder()
    for c in style {
      if !c.is_whitespace() {
        out.write_char(c)
      }
    }
    let style = out.to_string()
    let style = if style.has_suffix(";") {
      style[:style.length() - 1].to_owned()
    } else {
      style
    }
    if !style.has_prefix("text-align:") {
      raise InvalidInput("Unsupported table cell style")
    }
    declared.push(style[11:].to_owned())
  }
  if attrs.get("class") is Some(name) {
    if !name.has_prefix("has-text-align-") {
      raise InvalidInput("Unsupported table cell class")
    }
    declared.push(name[15:].to_owned())
  }
  if attrs.get("data-align") is Some(value) {
    declared.push(value)
  }
  if declared.is_empty() {
    return ""
  }
  if declared.any(value => {
      !["left", "center", "right"].contains(value) || value != declared[0]
    }) {
    raise InvalidInput("Conflicting or unsupported table alignment")
  }
  declared[0]
}
