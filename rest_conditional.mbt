///|
fn rest_conditional_match(header : String, digest : String) -> Bool raise {
  if header.length() == 0 || header.length() > 4096 {
    raise InvalidInput("Conditional header length rejected")
  }
  if header.trim() == "*" {
    return true
  }
  let values = header.split(",").to_array()
  if values.length() > 32 {
    raise InvalidInput("Too many conditional tags")
  }
  let mut matches = false
  for value in values {
    let text = value.trim().to_owned()
    let text = if text.has_prefix("W/") { text[2:].to_owned() } else { text }
    if text.length() != 66 || !text.has_prefix("\"") || !text.has_suffix("\"") {
      raise InvalidInput("Conditional tag rejected")
    }
    let tag = text[1:65].to_owned()
    if !valid_digest(tag) {
      raise InvalidInput("Conditional tag rejected")
    }
    if tag == digest {
      matches = true
    }
  }
  matches
}

///|
fn rest_conditional(
  result : RestResponse,
  read : Bool,
  header : String?,
) -> RestResponse {
  // Source-version ETags protect writes and must retain their existing meaning.
  // Revalidate only after dispatch, authentication, visibility and projection.
  if !read || result.code != 200 || result.etag is Some(_) {
    return result
  }
  let digest = digest_text(result.value.stringify() + "\n")
  let matches = match header {
    Some(value) =>
      rest_conditional_match(value, digest) catch {
        _ => return rest_error(400, "moonpress_invalid_conditional")
      }
    None => false
  }
  { ..result, etag: Some(digest), code: if matches { 304 } else { 200 }, }
}
