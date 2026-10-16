///|
test "site settings snapshot filesystem probe" {
  guard @env.get_env_var("MOONPRESS_SETTINGS_PROBE") is Some(input) else {
    return
  }
  let missing = read_site_settings(input + "/missing")
  assert_false(missing.exists)
  assert_eq(missing.digest, None)
  assert_eq(missing.content, "{}\n")
  let broken = read_site_settings(input + "/broken")
  assert_true(broken.exists)
  assert_eq(broken.content, "{ broken JSON\n")
  assert_eq(broken.digest, Some(digest_text(broken.content)))
  let valid = read_site_settings(input + "/valid")
  assert_eq(valid.content, "{}\n")
  assert_eq(valid.digest, Some(digest_text("{}\n")))
  for name in ["link", "pipe", "directory", "invalid-utf8"] {
    assert_true(
      try {
        read_site_settings(input + "/" + name) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
}
