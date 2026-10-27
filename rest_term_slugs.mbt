///|
fn rest_term_slugs(value : String?) -> Array[String] raise {
  let slugs : Array[String] = []
  if value is Some(value) {
    for part in value.split(",") {
      let slug = part.to_owned()
      if slug.is_empty() ||
        @utf8.encode(slug).length() > 200 ||
        slug.any(c => c.is_control()) {
        raise InvalidInput("Invalid term slug")
      }
      if !slugs.contains(slug) {
        slugs.push(slug)
      }
      if slugs.length() > 100 {
        raise InvalidInput("Too many term slugs")
      }
    }
  }
  slugs
}
