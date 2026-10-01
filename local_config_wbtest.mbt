///|
test "local site configuration does not require a deployment URL" {
  assert_eq(parse_site_config("{}").base_url, None)
  let config = parse_site_config(
    "{\"tag_index\":true,\"page_size\":2,\"tag_page_size\":3,\"collection_layout\":\"list.html\"}",
  )
  assert_eq(config.base_url, None)
  assert_eq(config.page_size, Some(2))
  assert_eq(config.tag_page_size, Some(3))
  assert_true(config.tag_index)
  assert_eq(config.collection_layout, Some("list.html"))
}

///|
test "RSS requires a URL and explicit invalid URLs never become local defaults" {
  for
    source in [
      "{\"feed\":{\"title\":\"Feed\",\"description\":\"News\"}}", "{\"base_url\":null}",
      "{\"base_url\":true}", "{\"base_url\":\"\"}", "{\"base_url\":\"relative/\"}",
    ] {
    try parse_site_config(source) catch {
      _ => ()
    } noraise {
      _ => fail("expected invalid config: " + source)
    }
  }
}
