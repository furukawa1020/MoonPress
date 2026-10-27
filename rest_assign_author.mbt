///|
fn rest_author_number(value : Json) -> Int raise {
  match value {
    Number(n, ..) if n >= 1 && n <= 2147483647 && n.to_int().to_double() == n =>
      n.to_int()
    _ => raise InvalidInput("Author requires a positive integer")
  }
}

///|
fn rest_assign_author(
  users : Array[AccessUser],
  principal : AccessPrincipal,
  kind : String,
  value : Json?,
) -> (Int, Int) raise {
  let id = match value {
    Some(value) => rest_author_number(value)
    None => principal.id
  }
  if !users.any(user => user.id == id && user.active) {
    return (400, id)
  }
  if id != principal.id &&
    !role_capabilities(principal.role).contains(
      "edit_others_" + (if kind == "page" { "pages" } else { "posts" }),
    ) {
    return (403, id)
  }
  (200, id)
}
