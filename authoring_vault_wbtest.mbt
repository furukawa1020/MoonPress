///|
test "private vault preparation filesystem probe" {
  guard @env.get_env_var("MOONPRESS_VAULT_FIXTURE") is Some(input) else {
    return
  }
  let reject = @env.get_env_var("MOONPRESS_VAULT_REJECT") is Some(_)
  if reject {
    assert_true(
      try {
        enable_post_history(input) |> ignore
        false
      } catch {
        _ => true
      },
    )
  } else {
    assert_true(enable_post_history(input))
    assert_false(enable_post_history(input))
    let vault = open_authoring_subdirectory(input, ".moonpress-history")
    defer directory_close(vault.fd)
    vault.write_new("sample.backup", b"private", private_mode=true)
    assert_eq(vault.read("sample.backup", max_bytes=16), b"private")
  }
}
