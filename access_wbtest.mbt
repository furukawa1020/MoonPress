///|
test "native implemented capabilities respect ownership and published state" {
  assert_false(role_can_edit("contributor", 2, 2, "post", true))
  assert_true(role_can_edit("contributor", 2, 2, "post", false))
  assert_false(role_can_edit("author", 2, 3, "post", false))
  assert_true(role_can_edit("author", 2, 2, "post", true))
  assert_false(role_can_edit("author", 2, 2, "page", false))
  assert_true(role_can_edit("editor", 2, 3, "page", true))
  assert_true(role_can_edit("administrator", 1, 0, "post", true))
  assert_false(role_can_edit("subscriber", 2, 2, "post", false))
  assert_true(access_equal(digest_text("secret"), digest_text("secret")))
  assert_false(access_equal(digest_text("secret"), digest_text("other")))
}

///|
test "native access authentication reads current revocation state" {
  if @env.get_env_var("MOONPRESS_ACCESS_SITE") is Some(site) {
    let secret = @env.get_env_var("MOONPRESS_ACCESS_SECRET").unwrap_or("")
    let expected = @env.get_env_var("MOONPRESS_ACCESS_EXPECTED").unwrap_or("")
    let user = authenticate_access(site, "alice", secret)
    if expected == "active" {
      assert_eq(user.map(user => user.login), Some("alice"))
    } else {
      assert_eq(user.map(user => user.login), None)
    }
    assert_eq(
      authenticate_access(site, "alice", "0".repeat(64)).map(user => user.id),
      None,
    )
  }
}
