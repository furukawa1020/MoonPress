///|
fn native_query_text(value : String) -> String raise {
  if @utf8.encode(value).length() > 256 || value.any(c => c.is_control()) {
    raise InvalidInput(
      "Search must be at most 256 UTF-8 bytes without controls",
    )
  }
  value.trim().to_owned().to_lower()
}
