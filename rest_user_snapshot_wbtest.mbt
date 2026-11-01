///|
test "user snapshot selects active identities without credential fields" {
  let a : AccessPrincipal = {
    id: 2,
    login: "author",
    role: "author",
    active: true,
  }
  let b : AccessPrincipal = {
    id: 1,
    login: "disabled",
    role: "subscriber",
    active: false,
  }
  let rows = rest_active_user_rows([a, b])
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].id, 2)
  match rows[0].to_json() {
    Object(fields) =>
      assert_true(
        !fields.contains("token_digest") && !fields.contains("secret"),
      )
    _ => fail("Expected identity")
  }
}
