///|
fn rest_user_slugs(value : String?) -> Array[String] raise {
  let names : Array[String] = []
  if value is Some(value) {
    for part in value.split(",") {
      let name = part.to_owned().to_lower()
      if name.is_empty() ||
        name.length() > 64 ||
        !name.all(c => {
          c.is_ascii_alphabetic() ||
          c.is_ascii_digit() ||
          c == '_' ||
          c == '-' ||
          c == '.'
        }) {
        raise InvalidInput("Invalid native user slug")
      }
      if !names.contains(name) {
        names.push(name)
      }
      if names.length() > 100 {
        raise InvalidInput("Too many user slugs")
      }
    }
  }
  names
}
