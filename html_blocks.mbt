///|
fn WxrReader::html_block(
  self : WxrReader,
  token : String,
  parent : String,
  depth : Int,
) -> IntakeHtml raise {
  if !token.has_prefix("wp:") || token.length() > 4096 {
    raise InvalidInput("Unsupported HTML comment/block")
  }
  let (name, json) = match token[3:].split_once(" ") {
    Some((name, json)) => (name.to_owned(), json.trim().to_owned())
    None => (token[3:].to_owned(), "{}")
  }
  let allowed = match name {
    "paragraph"
    | "list-item"
    | "quote"
    | "code"
    | "preformatted"
    | "separator" => []
    "image" => ["id", "sizeSlug", "linkDestination"]
    "table" => ["hasFixedLayout"]
    "heading" => ["level"]
    "list" => ["ordered", "start"]
    _ => raise InvalidInput("Unsupported WordPress block: " + name)
  }
  if name == "list-item" {
    if parent != "ul" && parent != "ol" {
      raise InvalidInput("List-item block requires a list")
    }
  } else if !parent.is_empty() &&
    !(name == "paragraph" && parent == "blockquote") {
    raise InvalidInput("Block requires top-level context")
  }
  let fields = strict_json_object(@json.parse(json), allowed, "WordPress block")
  let level = match fields.get("level") {
    Some(value) => rest_positive(value.stringify(), 6)
    None => 2
  }
  let ordered = match fields.get("ordered") {
    Some(True) => true
    Some(False) | None => false
    _ => raise InvalidInput("List ordered requires boolean")
  }
  let start = match fields.get("start") {
    Some(value) => rest_positive(value.stringify(), 999999999)
    None => 1
  }
  if name == "list" && !ordered && fields.contains("start") {
    raise InvalidInput("Unordered list cannot have start")
  }
  let children = self.html_children("", depth + 1, block=Some(name))
  let mut element : IntakeHtml? = None
  for child in children {
    match child {
      Text(text) if text.trim().is_empty() => ()
      Element(_, _, _) => {
        if element is Some(_) {
          raise InvalidInput("Block requires exactly one root element")
        }
        element = Some(child)
      }
      _ => raise InvalidInput("Block text outside root")
    }
  }
  let expected = match name {
    "paragraph" => "p"
    "heading" => "h" + level.to_string()
    "list-item" => "li"
    "quote" => "blockquote"
    "code" | "preformatted" => "pre"
    "separator" => "hr"
    "image" | "table" => "figure"
    _ => if ordered { "ol" } else { "ul" }
  }
  match element {
    Some(Element(tag, attrs, children)) => {
      if tag != expected {
        raise InvalidInput("WordPress block HTML/attributes disagree")
      }
      if name == "table" {
        return html_table_block(attrs, children, fields)
      }
      if name == "image" {
        return html_image_block(attrs, children, fields)
      }
      if attrs.get("class") is Some(class_name) {
        let known = match name {
          "heading" => "wp-block-heading"
          "list" => "wp-block-list"
          "quote" => "wp-block-quote"
          "code" => "wp-block-code"
          "preformatted" => "wp-block-preformatted"
          "separator" =>
            if class_name == "wp-block-separator has-alpha-channel-opacity" {
              class_name
            } else {
              "wp-block-separator"
            }
          _ => ""
        }
        if known.is_empty() || class_name != known {
          raise InvalidInput("Unsupported block class")
        }
        attrs.remove("class")
      }
      if name == "list" {
        let actual_start = rest_positive(
          attrs.get("start").unwrap_or("1"),
          999999999,
        )
        if actual_start != start || (!ordered && attrs.contains("start")) {
          raise InvalidInput("List block start disagrees")
        }
      }
      Element(tag, attrs, children)
    }
    _ => raise InvalidInput("Missing WordPress block HTML")
  }
}

///|
fn html_image_block(
  attrs : Map[String, String],
  children : Array[IntakeHtml],
  fields : Map[String, Json],
) -> IntakeHtml raise {
  if attrs.keys().any(key => key != "class") {
    raise InvalidInput("Unsupported image figure attributes")
  }
  let id = match fields.get("id") {
    Some(value) => Some(rest_positive(value.stringify(), 2147483647))
    None => None
  }
  let size = match fields.get("sizeSlug") {
    Some(String(size)) if ["thumbnail", "medium", "large", "full"].contains(
        size,
      ) => " size-" + size
    None => ""
    _ => raise InvalidInput("Unsupported image size")
  }
  if fields.get("linkDestination").unwrap_or("none".to_json()) !=
    "none".to_json() {
    raise InvalidInput("Linked image block unsupported")
  }
  if (!size.is_empty() && attrs.get("class") != Some("wp-block-image" + size)) ||
    (attrs.get("class") is Some(value) && value != "wp-block-image" + size) {
    raise InvalidInput("Image figure class disagrees")
  }
  match html_single_root(children) {
    Element("img", image, inline) => {
      if image.get("class") is Some(value) {
        if id is None || value != "wp-image-" + id.unwrap().to_string() {
          raise InvalidInput("Image identity/class disagrees")
        }
        image.remove("class")
      }
      Element("p", Map([]), [Element("img", image, inline)])
    }
    _ => raise InvalidInput("Image block requires one uncaptioned image")
  }
}
