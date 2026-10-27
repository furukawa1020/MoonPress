///|
fn rest_author_ids(value : String?) -> Array[Int] raise {
  let ids : Array[Int] = []
  if value is Some(value) && !value.is_empty() {
    for part in value.split(",") {
      let id = rest_nonnegative(part.trim().to_owned(), 2147483647)
      if !ids.contains(id) {
        ids.push(id)
      }
      if ids.length() > 100 {
        raise InvalidInput("Author filter exceeds 100 entries")
      }
    }
  }
  ids
}
