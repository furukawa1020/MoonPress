///|
test "redirect configuration accepts only flat filename mappings" {
  let config = parse_site_config("{\"redirects\":{\"old.html\":\"new.html\"}}")
  assert_eq(config.redirects[0].name, "old.html")
  assert_eq(parse_site_config("{}").redirects.length(), 0)
  for
    bad in ["null", "[]", "{\"a.html\":false}", "{\"../a.html\":\"new.html\"}"] {
    assert_true(
      try {
        let _ = parse_site_config("{\"redirects\":" + bad + "}")
        false
      } catch {
        _ => true
      },
    )
  }
}
