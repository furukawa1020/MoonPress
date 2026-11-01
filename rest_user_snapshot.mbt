///|
fn rest_active_user_rows(
  users : Array[AccessPrincipal],
) -> Array[AccessPrincipal] {
  let active = users.filter(user => user.active)
  active.sort_by(fn(a, b) { a.id.compare(b.id) })
  active
}

///|
fn rest_active_users(input : String) -> Array[AccessPrincipal] raise {
  rest_active_user_rows(inspect_access(input).users)
}
