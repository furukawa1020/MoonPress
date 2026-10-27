///|
fn rest_raw_input(value : Json) -> Json raise {
  match value {
    String(_) => value
    Object(_) => {
      let fields = strict_json_object(value, ["raw"], "Raw article input")
      match fields.get("raw") {
        Some(String(text)) => text.to_json()
        _ => raise InvalidInput("Expected raw string")
      }
    }
    _ => raise InvalidInput("Expected string or raw object")
  }
}
