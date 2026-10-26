///|
fn html_table_block(
  attrs : Map[String, String],
  children : Array[IntakeHtml],
  fields : Map[String, Json],
) -> IntakeHtml raise {
  if attrs.keys().any(key => key != "class") ||
    (attrs.contains("class") && attrs.get("class") != Some("wp-block-table")) {
    raise InvalidInput("Unsupported table figure attributes")
  }
  let fixed = match fields.get("hasFixedLayout") {
    Some(True) | None => true
    Some(False) => false
    _ => raise InvalidInput("Table layout requires boolean")
  }
  match html_single_root(children) {
    Element("table", attributes, rows) => {
      if attributes.get("class") is Some(name) {
        if !fixed || name != "has-fixed-layout" {
          raise InvalidInput("Table layout class disagrees")
        }
        attributes.remove("class")
      }
      if !attributes.is_empty() {
        raise InvalidInput("Unsupported table attributes")
      }
      Element("table", attributes, rows)
    }
    _ => raise InvalidInput("Table block requires one uncaptioned table")
  }
}
