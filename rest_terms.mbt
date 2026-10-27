///|
fn rest_named_terms(value : Json) -> Array[String] raise {
  let items = match value {
    Array(items) if items.length() <= 64 => items
    _ => raise InvalidInput("Named terms require at most 64 strings")
  }
  let result : Array[String] = []
  for item in items {
    let text = match item {
      String(text) => text.trim().to_owned()
      _ => raise InvalidInput("Expected a term name")
    }
    if text.is_empty() ||
      @utf8.encode(text).length() > 96 ||
      text.any(c => c.is_control()) {
      raise InvalidInput("Term requires 1-96 UTF-8 bytes without controls")
    }
    if !result.contains(text) {
      result.push(text)
    }
  }
  result.sort()
  result
}

///|
fn rest_write_types(fields : Map[String, Json]) -> Unit raise {
  for key, value in fields {
    let value = if ["title", "content"].contains(key) {
      let normalized = rest_raw_input(value)
      fields[key] = normalized
      normalized
    } else {
      value
    }
    if key == "moonpress_categories" || key == "moonpress_tags" {
      rest_named_terms(value) |> ignore
    } else if !(value is String(_)) {
      raise InvalidInput("Expected string field")
    }
  }
}
